"""
MetoE 定时任务调度器（零额外依赖版，基于 threading.Timer）
============================================================
功能：
  - 每日 00:00 执行按天扣费（按月订单/服务器换算日费用）
  - 每日 01:00 清理 180 天前过期审计日志
  - 每 2 小时关闭超过 7 天无更新的 replied 状态工单
  - 每 10 秒 KYC 自动审核（检测 pending 状态，3秒内通过）
  - 每 3 分钟占位 USDT 订单状态检查（mock 自动到账）

设计要点：
  - 所有任务函数可单独 run（便于单元测试）
  - 任务执行 try/except，失败只打印日志不影响其他任务
  - 任务记录写入 scheduler_jobs 表（下次启动可追溯）
  - 启动/停止由 start_scheduler / stop_scheduler 控制
"""
from __future__ import annotations

import threading
import time
import traceback
from datetime import datetime, timedelta
from typing import Callable, Dict, Optional

from core.database import get_conn


# ============ 任务函数 ============
def _log(msg: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[Scheduler {ts}] {msg}", flush=True)


def job_daily_billing():
    """每日扣费：按天分摊服务器月度费用（mock 版本）。"""
    _log("▶ 任务[daily_billing] 开始")
    try:
        with get_conn() as conn:
            # 选 active 状态且 expire_at > 今天的服务器
            rows = conn.execute("""
                SELECT s.id, s.user_id, s.price_month, s.expire_at, u.username, u.balance
                  FROM vps_servers s
                  JOIN users u ON u.id = s.user_id
                 WHERE s.status = 'active'
                   AND (s.expire_at IS NULL OR s.expire_at >= DATE('now','localtime'))
            """).fetchall()
            processed, fee_total = 0, 0.0
            for r in rows:
                price_month = float(r["price_month"] or 0)
                if price_month <= 0:
                    continue
                daily_fee = round(price_month / 30.0, 2)
                if daily_fee <= 0:
                    continue
                uid = r["user_id"]
                # 扣费并写交易流水
                cur_bal = float(conn.execute("SELECT balance FROM users WHERE id=?", (uid,)).fetchone()["balance"] or 0)
                if cur_bal < daily_fee:
                    # 余额不足：降级记录，不硬扣
                    continue
                bal_after = round(cur_bal - daily_fee, 2)
                conn.execute("UPDATE users SET balance=?, updated_at=datetime('now','localtime') WHERE id=?", (bal_after, uid))
                conn.execute(
                    """INSERT INTO transactions
                       (user_id, type, amount, balance_before, balance_after, remark)
                       VALUES (?,?,?,?,?,?)""",
                    (uid, "daily_fee", -daily_fee, cur_bal, bal_after,
                     f"服务器 #{r['id']} 日租扣费（月度 {price_month:.2f}/30）"),
                )
                processed += 1
                fee_total += daily_fee
            # 记录任务结果
            conn.execute(
                """INSERT INTO scheduler_jobs
                   (job_id, name, func, trigger, trigger_args, next_run_time, status, last_run_at, last_result)
                   VALUES (?,?,?,?,?,datetime('now','+24 hours','localtime'),'active',datetime('now','localtime'),?)
                   ON CONFLICT(job_id) DO UPDATE SET
                     last_run_at = excluded.last_run_at,
                     last_result = excluded.last_result,
                     next_run_time = excluded.next_run_time,
                     status = 'active',
                     updated_at = datetime('now','localtime')""",
                ("daily_billing_00", "每日按天扣费", "scheduler:job_daily_billing",
                 "cron", '{"hour":0,"minute":0}',
                 f"成功处理 {processed} 台服务器，合计扣费 ¥{fee_total:.2f}"),
            )
            _log(f"✔ 任务[daily_billing] 扣费 {processed} 台，合计 ¥{fee_total:.2f}")
    except Exception as e:
        _log(f"✘ 任务[daily_billing] 异常: {e}\n{traceback.format_exc()}")


def job_audit_cleanup():
    """清理 180 天前审计日志（合规要求：保留 180 天）。"""
    _log("▶ 任务[audit_cleanup] 开始")
    try:
        with get_conn() as conn:
            cur = conn.execute(
                """DELETE FROM audit_logs
                    WHERE created_at < datetime('now','localtime','-180 days')"""
            )
            deleted = cur.rowcount or 0
            conn.execute(
                """INSERT INTO scheduler_jobs
                   (job_id, name, func, trigger, trigger_args, next_run_time, status, last_run_at, last_result)
                   VALUES (?,?,?,?,?,datetime('now','+24 hours','localtime'),'active',datetime('now','localtime'),?)
                   ON CONFLICT(job_id) DO UPDATE SET
                     last_run_at = excluded.last_run_at,
                     last_result = excluded.last_result,
                     next_run_time = excluded.next_run_time,
                     status = 'active',
                     updated_at = datetime('now','localtime')""",
                ("audit_cleanup_01", "审计日志过期清理", "scheduler:job_audit_cleanup",
                 "cron", '{"hour":1,"minute":0}',
                 f"删除 {deleted} 条 >180天 过期审计日志"),
            )
            _log(f"✔ 任务[audit_cleanup] 删除过期日志 {deleted} 条")
    except Exception as e:
        _log(f"✘ 任务[audit_cleanup] 异常: {e}\n{traceback.format_exc()}")


def job_feedback_autoclose():
    """每 2 小时：将 7 天未更新的 replied 工单自动关闭。"""
    _log("▶ 任务[feedback_autoclose] 开始")
    try:
        with get_conn() as conn:
            cur = conn.execute(
                """UPDATE feedbacks
                      SET status = 'closed', updated_at = datetime('now','localtime')
                    WHERE status = 'replied'
                      AND updated_at < datetime('now','localtime','-7 days')"""
            )
            closed = cur.rowcount or 0
            if closed:
                # 给用户发通知
                rows = conn.execute(
                    """SELECT id, user_id, title FROM feedbacks
                        WHERE status='closed' AND updated_at >= datetime('now','localtime','-5 minutes')"""
                ).fetchall()
                for r in rows:
                    conn.execute(
                        """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                           VALUES (?, 'feedback', ?, ?, 'info', 'feedback', ?)""",
                        (r["user_id"], f"工单 #{r['id']} 已自动关闭",
                         f"工单【{r['title'][:20]}】因7天未继续跟进，系统已自动关闭。有新问题请重新提交",
                         str(r["id"])),
                    )
            conn.execute(
                """INSERT INTO scheduler_jobs
                   (job_id, name, func, trigger, trigger_args, next_run_time, status, last_run_at, last_result)
                   VALUES (?,?,?,?,?,datetime('now','+2 hours','localtime'),'active',datetime('now','localtime'),?)
                   ON CONFLICT(job_id) DO UPDATE SET
                     last_run_at = excluded.last_run_at,
                     last_result = excluded.last_result,
                     next_run_time = excluded.next_run_time,
                     status = 'active',
                     updated_at = datetime('now','localtime')""",
                ("feedback_autoclose_2h", "工单自动关闭", "scheduler:job_feedback_autoclose",
                 "interval", '{"hours":2}',
                 f"自动关闭 {closed} 条超时工单"),
            )
            _log(f"✔ 任务[feedback_autoclose] 关闭 {closed} 条超时工单")
    except Exception as e:
        _log(f"✘ 任务[feedback_autoclose] 异常: {e}\n{traceback.format_exc()}")


def job_kyc_autoapprove():
    """每 10 秒：模拟 KYC 自动审核流水线（3秒自动通过 pending）。
    真实生产应对接公安/工商实名接口或人工审核。这里 demo 环境下 3秒自动过。"""
    _log("▶ 任务[kyc_autoapprove] 轮询 pending...")
    try:
        with get_conn() as conn:
            rows = conn.execute(
                """SELECT * FROM kyc_verifications
                    WHERE status = 'pending'
                      AND submitted_at <= datetime('now','localtime','-3 seconds')
                 ORDER BY id ASC LIMIT 20"""
            ).fetchall()
            approved, rejected = 0, 0
            for r in rows:
                # 超简 demo：数据齐全即通过；预留真实校验点
                ok_ = bool(r["name"] and (r["idcard"] or r["uscc"]))
                if ok_:
                    conn.execute(
                        """UPDATE kyc_verifications
                              SET status='approved', reviewed_by=NULL,
                                  reviewed_at=datetime('now','localtime'),
                                  updated_at=datetime('now','localtime')
                            WHERE id=?""",
                        (r["id"],),
                    )
                    conn.execute(
                        """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                           VALUES (?, 'system', ?, ?, 'success', 'kyc', ?)""",
                        (r["user_id"], "实名认证审核通过",
                         f"您的【{'个人' if r['type']=='person' else '企业'}】实名认证已通过，可以购买合规服务了！",
                         str(r["id"])),
                    )
                    approved += 1
                else:
                    conn.execute(
                        """UPDATE kyc_verifications
                              SET status='rejected', reject_reason='资料不完整，请补充姓名与证件信息',
                                  reviewed_at=datetime('now','localtime'),
                                  updated_at=datetime('now','localtime')
                            WHERE id=?""",
                        (r["id"],),
                    )
                    conn.execute(
                        """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                           VALUES (?, 'system', ?, ?, 'warning', 'kyc', ?)""",
                        (r["user_id"], "实名认证未通过",
                         f"原因：资料不完整。请重新提交完整的姓名与证件照片。",
                         str(r["id"])),
                    )
                    rejected += 1
            if approved or rejected:
                conn.execute(
                    """INSERT INTO scheduler_jobs
                       (job_id, name, func, trigger, trigger_args, next_run_time, status, last_run_at, last_result)
                       VALUES (?,?,?,?,?,datetime('now','+10 seconds','localtime'),'active',datetime('now','localtime'),?)
                       ON CONFLICT(job_id) DO UPDATE SET
                         last_run_at = excluded.last_run_at,
                         last_result = excluded.last_result,
                         next_run_time = excluded.next_run_time,
                         status = 'active',
                         updated_at = datetime('now','localtime')""",
                    ("kyc_autoapprove_10s", "KYC 3秒自动审核", "scheduler:job_kyc_autoapprove",
                     "interval", '{"seconds":10}',
                     f"本轮通过 {approved} 条，驳回 {rejected} 条"),
                )
                _log(f"✔ 任务[kyc_autoapprove] 通过 {approved} / 驳回 {rejected}")
    except Exception as e:
        _log(f"✘ 任务[kyc_autoapprove] 异常: {e}\n{traceback.format_exc()}")


def job_usdt_placeholder():
    """每 3 分钟：将 pending 且超过 2 分钟的 USDT 订单 mock 标记为 paid（模拟链上到账）。"""
    _log("▶ 任务[usdt_placeholder] 开始")
    try:
        with get_conn() as conn:
            rows = conn.execute(
                """SELECT p.*, o.user_id, o.total order_total
                     FROM payments p
                     JOIN orders o ON o.id = p.order_id
                    WHERE p.channel IN ('usdt','mock_usdt','alipay','wechat','paypal')
                      AND p.status = 'pending'
                      AND p.created_at < datetime('now','localtime','-2 minutes')
                 ORDER BY p.id ASC LIMIT 50"""
            ).fetchall()
            finished = 0
            for r in rows:
                pay_id = r["id"]
                order_id = r["order_id"]
                uid = r["user_id"]
                amt = float(r["amount"] or 0)
                # 先加余额（因为充值类订单是充钱包）
                u = conn.execute("SELECT balance FROM users WHERE id=?", (uid,)).fetchone()
                bal_before = float(u["balance"] or 0)
                # 判断是否充值单
                o = conn.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone()
                is_recharge = (o and o.get("category") == "recharge") or (o and "充值" in (o.get("product") or ""))
                bal_after = bal_before
                txn_remark = ""
                if is_recharge:
                    bal_after = round(bal_before + amt, 2)
                    txn_remark = f"充值到账 {amt:.2f} 元（{r['channel']} 渠道，模拟）"
                    conn.execute("UPDATE users SET balance=?, updated_at=datetime('now','localtime') WHERE id=?", (bal_after, uid))
                    conn.execute(
                        """INSERT INTO transactions
                           (user_id, type, amount, balance_before, balance_after, order_id, payment_id, remark)
                           VALUES (?,?,?,?,?,?,?,?)""",
                        (uid, "recharge", amt, bal_before, bal_after, order_id, pay_id, txn_remark),
                    )
                # 订单和支付都标完成
                conn.execute(
                    "UPDATE payments SET status='paid', paid_at=datetime('now','localtime'), channel_txn_id=? WHERE id=?",
                    (f"MOCK_{r['pay_no']}_{int(time.time())}", pay_id),
                )
                conn.execute(
                    "UPDATE orders SET status='paid', paid_at=datetime('now','localtime'), deploy_status=CASE WHEN deploy_status='pending' THEN 'ready' ELSE deploy_status END, updated_at=datetime('now','localtime') WHERE id=?",
                    (order_id,),
                )
                # 通知
                conn.execute(
                    """INSERT INTO notifications (user_id, type, title, content, level, resource_type, resource_id)
                       VALUES (?, 'wallet', ?, ?, 'success', 'order', ?)""",
                    (uid, f"订单 #{order_id} 支付成功",
                     f"您的订单 {o['order_no'] if o else order_id} 已确认收款 ¥{amt:.2f}" +
                     (f"，钱包余额 +¥{amt:.2f}" if is_recharge else "") +
                     "，部署将自动开始（若为云服务器订单）。",
                     str(order_id)),
                )
                finished += 1
            if finished:
                conn.execute(
                    """INSERT INTO scheduler_jobs
                       (job_id, name, func, trigger, trigger_args, next_run_time, status, last_run_at, last_result)
                       VALUES (?,?,?,?,?,datetime('now','+3 minutes','localtime'),'active',datetime('now','localtime'),?)
                       ON CONFLICT(job_id) DO UPDATE SET
                         last_run_at = excluded.last_run_at,
                         last_result = excluded.last_result,
                         next_run_time = excluded.next_run_time,
                         status = 'active',
                         updated_at = datetime('now','localtime')""",
                    ("usdt_placeholder_3m", "USDT 到账占位（mock）", "scheduler:job_usdt_placeholder",
                     "interval", '{"minutes":3}',
                     f"本轮 mock 到账 {finished} 笔订单"),
                )
                _log(f"✔ 任务[usdt_placeholder] 到账 {finished} 笔支付订单")
    except Exception as e:
        _log(f"✘ 任务[usdt_placeholder] 异常: {e}\n{traceback.format_exc()}")


# ============ 轻量调度器（threading.Timer，替代 APScheduler，零依赖） ============
class LightScheduler:
    def __init__(self):
        self._jobs: Dict[str, Dict] = {}
        self._timers: Dict[str, threading.Timer] = {}
        self._lock = threading.RLock()
        self._running = False

    def register(self, job_id: str, func: Callable, interval_sec: int, run_at_start: bool = False):
        with self._lock:
            self._jobs[job_id] = {"func": func, "interval": interval_sec, "run_at_start": run_at_start}
            _log(f"📝 注册任务: {job_id} (间隔 {interval_sec}s，启动即跑={run_at_start})")

    def _schedule(self, job_id: str):
        if not self._running or job_id not in self._jobs:
            return
        cfg = self._jobs[job_id]

        def _run_then_schedule():
            try:
                cfg["func"]()
            except Exception as e:
                _log(f"✘ 任务[{job_id}] 顶层捕获异常: {e}")
            finally:
                if self._running:
                    with self._lock:
                        if self._running and job_id in self._jobs:
                            t = threading.Timer(cfg["interval"], _run_then_schedule)
                            t.daemon = True
                            self._timers[job_id] = t
                            t.start()
        t = threading.Timer(0 if cfg.get("run_at_start") else cfg["interval"], _run_then_schedule)
        t.daemon = True
        with self._lock:
            self._timers[job_id] = t
        t.start()

    def start(self):
        with self._lock:
            if self._running:
                return
            self._running = True
            for jid in list(self._jobs.keys()):
                self._schedule(jid)
        _log(f"===== LightScheduler 启动完成，共 {len(self._jobs)} 个任务 =====")

    def stop(self):
        with self._lock:
            self._running = False
            for t in list(self._timers.values()):
                try:
                    t.cancel()
                except Exception:
                    pass
            self._timers.clear()
        _log("===== LightScheduler 已停止 =====")


_scheduler: Optional[LightScheduler] = None


def start_scheduler():
    """启动全部 5 个 P0 定时任务（app startup 事件中调用一次）。"""
    global _scheduler
    if _scheduler and _scheduler._running:
        return _scheduler
    s = LightScheduler()

    # P0-1. 每日扣费：计算到明天 00:00 的秒数，再按 86400 循环
    def _calc_seconds_to_tomorrow_hour(h: int) -> int:
        now = datetime.now()
        target = now.replace(hour=h, minute=5, second=0, microsecond=0)
        if target <= now:
            target += timedelta(days=1)
        return int((target - now).total_seconds())

    first_daily_billing = _calc_seconds_to_tomorrow_hour(0)
    first_audit = _calc_seconds_to_tomorrow_hour(1)

    def _daily_billing_wrap():
        # 第一次用 offset，之后改成 24h 间隔（通过 Timer 里动态计算更精准，此处简化固定 86400）
        job_daily_billing()
        # 重置为 24h
        with s._lock:
            if "daily_billing_00" in s._jobs:
                s._jobs["daily_billing_00"]["interval"] = 86400

    def _daily_audit_wrap():
        job_audit_cleanup()
        with s._lock:
            if "audit_cleanup_01" in s._jobs:
                s._jobs["audit_cleanup_01"]["interval"] = 86400

    s.register("daily_billing_00", _daily_billing_wrap, first_daily_billing, run_at_start=False)
    s.register("audit_cleanup_01", _daily_audit_wrap, first_audit, run_at_start=False)

    # P0-3. 工单自动关闭：每 2h
    s.register("feedback_autoclose_2h", job_feedback_autoclose, 2 * 3600, run_at_start=True)
    # P0-4. KYC 自动审核：每 10s
    s.register("kyc_autoapprove_10s", job_kyc_autoapprove, 10, run_at_start=True)
    # P0-5. USDT 到账占位：每 3min
    s.register("usdt_placeholder_3m", job_usdt_placeholder, 180, run_at_start=True)

    s.start()
    _scheduler = s
    return s


def stop_scheduler():
    global _scheduler
    if _scheduler:
        _scheduler.stop()
        _scheduler = None
