"""
MetoE 全球云服务器管理平台 - Python FastAPI 后端
技术栈：FastAPI + Uvicorn + Pydantic + SQLite(标准库) + PyJWT + bcrypt(passlib)
特性：
  1. SQLite 零原生编译，Python 标准库即可运行（跨平台 Windows/Linux/Mac）
  2. JWT 认证 + RBAC 角色权限（super_admin / admin / finance / support / user）
  3. 完整 API：认证、云服务器、订单、用户管理、角色权限、IP 检测、反馈工单
  4. core/shell_runner.py 提供执行 .sh 脚本的统一封装（初始化脚本 / IP 检测 等）
  5. FastAPI 自动生成 Swagger UI -> http://localhost:3000/docs

启动命令：
    pip install -r requirements.txt
    python app.py          (开发模式: 热重载可用 uvicorn app:app --reload --port 3000)
"""
from __future__ import annotations
import time, os
from datetime import datetime

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from core.config import get_settings
from core.init_db import init_all
from core.database import get_conn
from core.security import get_current_user

settings = get_settings()

limiter = Limiter(key_func=get_remote_address)
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    description="MetoE 全球云服务器管理平台 - 多区域多规格云服务器/远程主机/接入面板 统一管理",
    docs_url="/docs",
    redoc_url="/redoc",
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Total-Count"],
)

START_TS = time.time()


@app.middleware("http")
async def add_headers(request: Request, call_next):
    try:
        response = await call_next(request)
    except HTTPException:
        raise
    except Exception as exc:  # noqa
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=500, content={"code": 500, "message": str(exc), "data": None})
    response.headers["X-Powered-By"] = f"MetoE/{settings.VERSION} (FastAPI)"
    return response


@app.on_event("startup")
def startup():
    init_all()
    _kyc_migrate()
    try:
        from core.scheduler import start_scheduler
        start_scheduler()
    except Exception as _e:
        print(f"[Scheduler] 启动失败（继续启动 Web 服务）: {_e}", flush=True)


@app.on_event("shutdown")
def shutdown():
    try:
        from core.scheduler import stop_scheduler
        stop_scheduler()
    except Exception:
        pass


def _kyc_migrate():
    """升级现有DB：建表 + 补齐3个权限 + 给角色绑定权限。全是 IF NOT EXISTS，可安全重入。"""
    with get_conn() as conn:
        conn.executescript("""
CREATE TABLE IF NOT EXISTS kyc_verifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'person',
  status TEXT NOT NULL DEFAULT 'pending',
  reject_reason TEXT,
  name TEXT, idcard TEXT, phone TEXT,
  id_front_url TEXT, id_back_url TEXT, face_url TEXT,
  company TEXT, uscc TEXT, legal_name TEXT, legal_idcard TEXT,
  bank_account TEXT, contact_email TEXT, license_url TEXT,
  extra_json TEXT, reviewed_by INTEGER, reviewed_at TEXT,
  submitted_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_kyc_user ON kyc_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON kyc_verifications(status);
        """)
        conn.executemany(
            "INSERT OR IGNORE INTO permissions (code, name, group_name) VALUES (?,?,?)",
            [
                ("kyc:submit", "提交实名认证", "实名认证"),
                ("kyc:view",   "查看实名状态", "实名认证"),
                ("kyc:audit",  "审核实名认证", "实名认证"),
            ],
        )
        def _bind(role, codes):
            conn.executemany(
                "INSERT OR IGNORE INTO role_permissions (role_code, permission_code) VALUES (?,?)",
                [(role, c) for c in codes],
            )
        _bind("user",    ["kyc:submit", "kyc:view"])
        _bind("support", ["kyc:submit", "kyc:view"])
        _bind("admin",   ["kyc:submit", "kyc:view", "kyc:audit"])
        _bind("finance", ["kyc:view"])


@app.get("/", tags=["根路径"])
@limiter.limit(f"{settings.RATE_LIMIT_PER_MINUTE}/minute")
def index(request: Request):
    return {
        "name": settings.APP_NAME,
        "version": settings.VERSION,
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "docs": "/docs (Swagger UI)",
        "health": "ok",
        "notes": [
            "登录账号：admin / 123456 (超级管理员)   demo / 123456 (普通用户)",
            "前端 metoe 访问后端：Vite 已配置代理 '/api' -> http://localhost:3000",
        ],
    }


@app.get("/health", tags=["根路径"])
@limiter.limit("60/minute")
def health(request: Request):
    try:
        with get_conn() as conn:
            ok = conn.execute("SELECT 1").fetchone() is not None
    except Exception as exc:
        return {"code": 500, "message": "db_error", "data": {"db": False, "err": str(exc)}}
    return {
        "code": 0,
        "message": "ok",
        "data": {
            "status": "ok",
            "uptime_s": round(time.time() - START_TS, 1),
            "db": ok,
            "db_path": os.path.abspath(settings.DB_PATH),
        },
    }


def _stats_summary_impl(user):
    with get_conn() as conn:
        base_sql = ""
        params = []
        is_sa = user.get("is_super_admin")
        if not is_sa:
            base_sql = " WHERE user_id=? "
            params.append(user["id"])
        users_all = conn.execute("SELECT COUNT(*) c FROM users").fetchone()["c"] if is_sa else None
        proxies = conn.execute(f"SELECT COUNT(*) c FROM proxies {base_sql}", params).fetchone()["c"]
        orders = conn.execute(f"SELECT COUNT(*) c FROM orders {base_sql}", params).fetchone()["c"]
        servers = conn.execute(f"SELECT COUNT(*) c FROM vps_servers {base_sql}", params).fetchone()["c"]
        deploys = conn.execute(f"SELECT COUNT(*) c FROM deploy_tasks {base_sql}", params).fetchone()["c"]
        payments = conn.execute(f"SELECT COUNT(*) c FROM payments {base_sql}", params).fetchone()["c"]
        active_proxies = conn.execute(
            f"SELECT COUNT(*) c FROM proxies {base_sql + ('AND ' if base_sql else ' WHERE ')}status='active'",
            params,
        ).fetchone()["c"]
        success_deploy = conn.execute(
            f"SELECT COUNT(*) c FROM deploy_tasks {base_sql + ('AND ' if base_sql else ' WHERE ')}status='success'",
            params,
        ).fetchone()["c"]
        running_deploy = conn.execute(
            f"SELECT COUNT(*) c FROM deploy_tasks {base_sql + ('AND ' if base_sql else ' WHERE ')}status IN ('running','pending')",
            params,
        ).fetchone()["c"]
        paid_orders = conn.execute(
            f"SELECT COUNT(*) c FROM orders {base_sql + ('AND ' if base_sql else ' WHERE ')}status='paid'",
            params,
        ).fetchone()["c"]
        total_amount = conn.execute(
            f"SELECT COALESCE(SUM(total),0) s FROM orders {base_sql + ('AND ' if base_sql else ' WHERE ')}status='paid'",
            params,
        ).fetchone()["s"]
        bal = None
        if not is_sa:
            bal = float(user.get("balance") or 0)
        counts_country = []
        if is_sa:
            counts_country = [dict(r) for r in conn.execute(
                "SELECT country_code code, country_name name, country_flag flag, COUNT(*) count FROM proxies GROUP BY country_code ORDER BY count DESC LIMIT 10"
            ).fetchall()]
        else:
            counts_country = [dict(r) for r in conn.execute(
                "SELECT country_code code, country_name name, country_flag flag, COUNT(*) count FROM proxies WHERE user_id=? GROUP BY country_code ORDER BY count DESC LIMIT 10",
                [user["id"]],
            ).fetchall()]
    data = {
        "users": users_all,
        "proxies": proxies,
        "active_proxies": active_proxies,
        "orders": orders,
        "paid_orders": paid_orders,
        "servers": servers,
        "deploys": deploys,
        "success_deploy": success_deploy,
        "running_deploy": running_deploy,
        "payments": payments,
        "total_paid_amount": round(float(total_amount), 2),
        "balance": bal,
        "country_counts": counts_country,
    }
    return {"code": 0, "message": "ok", "data": data}


@app.get("/stats/summary", tags=["统计"])
def summary(user=Depends(get_current_user)):
    return _stats_summary_impl(user)


from fastapi import APIRouter
stats_router = APIRouter(tags=["统计"])
@stats_router.get("/stats/summary")
def stats_prefix_summary(user=Depends(get_current_user)):
    return _stats_summary_impl(user)


from routers.auth import router as auth_router
from routers.proxies import router as proxies_router
from routers.orders import router as orders_router
from routers.system import router as system_router
from routers.check import router as check_router
from routers.feedbacks import router as feedbacks_router
from routers.config import router as config_router
from routers.payments import router as payments_router
from routers.servers import router as servers_router
from routers.deploy import router as deploy_router
from routers.providers_mock import router as providers_mock_router
from routers.verify import router as verify_router
from routers.audit import router as audit_router
from routers.transactions import router as transactions_router
from routers.wallet import router as wallet_router
from routers.subaccounts import router as subaccounts_router
from routers.coupons import router as coupons_router
from routers.notifications import router as notifications_router
from routers.reputation import router as reputation_router

app.include_router(auth_router)
app.include_router(proxies_router)
app.include_router(proxies_router, prefix='/access', tags=['接入实例 (访问入口列表)'])
app.include_router(orders_router)
app.include_router(system_router)
app.include_router(check_router)
app.include_router(feedbacks_router)
app.include_router(config_router)
app.include_router(payments_router)
app.include_router(servers_router)
app.include_router(deploy_router)
app.include_router(providers_mock_router)
app.include_router(stats_router)
app.include_router(verify_router)
app.include_router(audit_router)
app.include_router(transactions_router)
app.include_router(wallet_router)
app.include_router(subaccounts_router)
app.include_router(coupons_router)
app.include_router(notifications_router)
app.include_router(reputation_router)

for pf in ['/api', '/v1']:
    app.include_router(auth_router, prefix=pf)
    app.include_router(proxies_router, prefix=pf)
    app.include_router(proxies_router, prefix=pf + '/access', tags=['接入实例 (访问入口列表)'])
    app.include_router(orders_router, prefix=pf)
    app.include_router(system_router, prefix=pf)
    app.include_router(check_router, prefix=pf)
    app.include_router(feedbacks_router, prefix=pf)
    app.include_router(config_router, prefix=pf)
    app.include_router(payments_router, prefix=pf)
    app.include_router(servers_router, prefix=pf)
    app.include_router(deploy_router, prefix=pf)
    app.include_router(stats_router, prefix=pf)
    app.include_router(verify_router, prefix=pf)
    app.include_router(audit_router, prefix=pf)
    app.include_router(transactions_router, prefix=pf)
    app.include_router(wallet_router, prefix=pf)
    app.include_router(subaccounts_router, prefix=pf)
    app.include_router(coupons_router, prefix=pf)
    app.include_router(notifications_router, prefix=pf)
    app.include_router(reputation_router, prefix=pf)


@app.exception_handler(404)
def not_found(req, exc):
    from fastapi.responses import JSONResponse
    return JSONResponse(status_code=404, content={"code": 404, "message": "接口不存在", "data": None})


if __name__ == "__main__":
    import uvicorn
    banner = r"""
  __  __        _          _____
 |  \/  | ___  | |_ ___   | ____|
 | |\/| |/ _ \ | __/ _ \  |  _|
 | |  | | (_) || ||  __/  | |___
 |_|  |_|\___/  \__\___|  |_____|   Cloud Servers Management Platform
"""
    print(banner)
    print(f"  服务启动中...")
    print(f"  本地访问: http://localhost:{settings.PORT}")
    print(f"  API 文档: http://localhost:{settings.PORT}/docs")
    print(f"  数据库:   {os.path.abspath(settings.DB_PATH)}")
    print(f"  账号:     admin / 123456 (超级管理员)")
    print(f"            demo  / 123456 (普通用户)")
    print("-" * 68)
    uvicorn.run(
        "app:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info",
    )
