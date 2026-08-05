<template>
  <el-container class="layout-root">
    <el-aside width="240px" class="aside">
      <div class="logo">
        <div class="brand-logo">
          <el-icon :size="30" color="#10b981"><Connection /></el-icon>
        </div>
        <div class="brand-text">
          <div class="brand-name">MetoE</div>
          <div class="brand-sub">全球云服务器平台</div>
        </div>
      </div>

      <el-scrollbar class="menu-scroll">
        <el-menu
          :default-active="$route.path"
          :collapse="false"
          :default-openeds="['sys-menu']"
          router
          background-color="#0B1220"
          text-color="#9fb0c8"
          active-text-color="#ffffff"
          class="menu"
        >
          <el-menu-item index="/dashboard" class="item-dashboard">
            <el-icon :size="18"><DataAnalysis /></el-icon>
            <span class="menu-text">仪表盘</span>
          </el-menu-item>

          <el-menu-item index="/servers/buy" class="item-product has-tag">
            <el-icon :size="18"><Cpu /></el-icon>
            <span class="menu-text">全球云服务器</span>
            <span class="promo-tag promo-hot">HOT</span>
          </el-menu-item>

          <el-menu-item index="/affiliate" class="item-affiliate has-tag">
            <el-icon :size="18"><Share /></el-icon>
            <span class="menu-text">推荐分销中心</span>
            <span class="promo-tag promo-purple">2.7折起</span>
          </el-menu-item>

          <el-sub-menu index="sys-menu" class="submenu-system">
            <template #title>
              <el-icon :size="18"><Setting /></el-icon>
              <span class="menu-text">系统管理</span>
              <span class="promo-tag promo-purple inline">充值加赠22%</span>
            </template>
            <el-menu-item index="/policy"><el-icon><Lock /></el-icon>安全策略</el-menu-item>
            <el-menu-item index="/orders"><el-icon><Tickets /></el-icon>历史订单</el-menu-item>
            <el-menu-item index="/recharges"><el-icon><Wallet /></el-icon>充值订单</el-menu-item>
            <el-menu-item index="/billing"><el-icon><List /></el-icon>费用明细</el-menu-item>
            <el-menu-item index="/recharge" class="has-tag-inner">
              <el-icon><CreditCard /></el-icon>充值中心
              <span class="promo-tag promo-purple inner">充值加赠22%</span>
            </el-menu-item>
            <el-menu-item index="/autorenew"><el-icon><RefreshRight /></el-icon>自动续订</el-menu-item>
            <el-menu-item index="/coupons"><el-icon><Present /></el-icon>优惠券</el-menu-item>
            <el-menu-item index="/subaccounts"><el-icon><UserFilled /></el-icon>子账号管理</el-menu-item>
            <el-menu-item index="/redeem"><el-icon><Key /></el-icon>激活兑换码</el-menu-item>
            <el-menu-item index="/audit"><el-icon><Notebook /></el-icon>敏感操作日志</el-menu-item>
          </el-sub-menu>

          <el-menu-item index="/verify" class="has-tag">
            <el-icon :size="18"><Avatar /></el-icon>
            <span class="menu-text">实名认证</span>
            <span class="promo-tag promo-blue">双倍奖励</span>
          </el-menu-item>

          <el-menu-item index="/resources">
            <el-icon :size="18"><Reading /></el-icon>
            <span class="menu-text">资源中心</span>
          </el-menu-item>

          <el-divider class="menu-divider" />

          <el-menu-item index="/check">
            <el-icon :size="18"><ZoomIn /></el-icon>
            <span class="menu-text">网络检测中心</span>
          </el-menu-item>
          <el-menu-item index="/developer">
            <el-icon :size="18"><MagicStick /></el-icon>
            <span class="menu-text">开发者 API</span>
          </el-menu-item>
          <el-menu-item index="/feedback">
            <el-icon :size="18"><ChatLineSquare /></el-icon>
            <span class="menu-text">反馈建议</span>
          </el-menu-item>
        </el-menu>
      </el-scrollbar>

      <div class="aside-footer">
        <el-tooltip content="联系客服 7×24" placement="top">
          <el-button type="success" plain size="small" class="footer-btn" @click="csVisible = true">
            <el-icon><Service /></el-icon> 客服中心
          </el-button>
        </el-tooltip>
        <el-button type="primary" plain size="small" class="footer-btn" @click="handleCommand('recharge')">
          <el-icon><Wallet /></el-icon> 立即充值
        </el-button>
      </div>
    </el-aside>

    <el-container>
      <el-header class="header">
        <div class="crumbs">
          <el-breadcrumb separator="/">
            <el-breadcrumb-item :to="{ path: '/dashboard' }">首页</el-breadcrumb-item>
            <el-breadcrumb-item v-if="$route.meta.group">{{ $route.meta.group }}</el-breadcrumb-item>
            <el-breadcrumb-item v-if="$route.meta.title">{{ $route.meta.title }}</el-breadcrumb-item>
          </el-breadcrumb>
        </div>

        <div class="promo-banner">
          <el-icon color="#ffd04b"><BellFilled /></el-icon>
          <span class="promo-title">7月限时活动</span>
          <el-tag type="danger" effect="dark" round size="small">充值加赠 22%</el-tag>
          <el-tag type="warning" effect="light" round size="small">实名认证双倍奖励</el-tag>
          <span class="countdown">
            活动倒计时：
            <span class="cd-box">{{ promoCountdown.d }}</span>天
            <span class="cd-box">{{ promoCountdown.h }}</span>时
            <span class="cd-box">{{ promoCountdown.m }}</span>分
            <span class="cd-box">{{ promoCountdown.s }}</span>秒
          </span>
        </div>

        <div class="user-area">
          <el-tag class="balance-tag" type="warning" effect="dark" round @click="handleCommand('recharge')">
            <el-icon><Coin /></el-icon>
            &nbsp;账户余额 <b>¥{{ userStore.userInfo?.balance || '0.00' }}</b>
            <el-button link size="small" type="success" @click.stop="handleCommand('recharge')">充值</el-button>
          </el-tag>
          <el-tooltip content="简体中文">
            <el-button link size="small" class="icon-btn">
              <el-icon><Grid /></el-icon>&nbsp;CN
            </el-button>
          </el-tooltip>
          <el-tooltip content="帮助文档">
            <el-button link size="small" class="icon-btn"><el-icon><QuestionFilled /></el-icon></el-button>
          </el-tooltip>
          <el-tooltip :content="`消息通知 (${notifyUnread})`">
            <el-badge :value="notifyUnread" :max="99" class="notification-badge" :hidden="notifyUnread <= 0">
              <el-button link size="small" class="icon-btn" @click="router.push('/notifications')">
                <el-icon><Bell /></el-icon>
              </el-button>
            </el-badge>
          </el-tooltip>
          <el-dropdown trigger="click" @command="handleCommand">
            <span class="user-dropdown">
              <el-avatar :size="32" style="background:linear-gradient(135deg,#409eff,#10b981)">
                {{ (userStore.userInfo?.username || 'U').charAt(0).toUpperCase() }}
              </el-avatar>
              <div class="user-meta">
                <div class="uname">{{ userStore.userInfo?.username || '访客' }}</div>
                <div class="urole muted small">{{ (userStore.roles||[])[0] || '普通用户' }}</div>
              </div>
              <el-icon><CaretBottom /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile"><el-icon><User /></el-icon> 个人中心</el-dropdown-item>
                <el-dropdown-item command="recharge"><el-icon><Wallet /></el-icon> 充值余额</el-dropdown-item>
                <el-dropdown-item command="orders"><el-icon><Tickets /></el-icon> 我的订单</el-dropdown-item>
                <el-dropdown-item command="verify"><el-icon><Avatar /></el-icon> 实名认证</el-dropdown-item>
                <el-dropdown-item command="api"><el-icon><MagicStick /></el-icon> API 密钥</el-dropdown-item>
                <el-dropdown-item divided command="logout"><el-icon><SwitchButton /></el-icon> 退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main class="main">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
      <el-footer height="42" class="footer">
        <span class="muted small">© {{ year }} MetoE 全球云服务器管理平台 · Powered by Lisa 主机</span>
        <span class="footer-links muted small">
          客服支持：
          <el-button link size="small" type="success" @click="csVisible = true">微信 / QQ</el-button>
          ·
          <a class="link" :href="`mailto:${cs.email}`">{{ cs.email }}</a>
          ·
          服务热线：{{ cs.phone }}（{{ cs.work_time }}）
        </span>
      </el-footer>
    </el-container>

    <el-drawer v-model="csVisible" title="客服支持 · 7×24 小时在线" direction="rtl" size="400px">
      <div class="cs-panel">
        <el-alert type="success" :closable="false" show-icon
          title="购买前或使用中有任何问题，欢迎随时联系我们的专业客服团队" />

        <div class="cs-item">
          <div class="cs-icon-box wechat"><el-icon :size="34"><ChatDotRound /></el-icon></div>
          <div class="cs-info">
            <div class="cs-label">微信号</div>
            <div class="cs-value mono">{{ cs.wechat }}
              <el-button link size="small" type="primary" @click="copy(cs.wechat, '微信号已复制')">复制</el-button>
            </div>
            <div class="cs-desc muted small">扫码或搜索微信号添加，工作日响应 ≤ 5 分钟</div>
          </div>
        </div>

        <div class="cs-item">
          <div class="cs-icon-box qq"><el-icon :size="34"><Phone /></el-icon></div>
          <div class="cs-info">
            <div class="cs-label">QQ 客服</div>
            <div class="cs-value mono">{{ cs.qq }}
              <el-button link size="small" type="primary" @click="copy(cs.qq, 'QQ号已复制')">复制</el-button>
            </div>
            <div class="cs-desc muted small">点击链接直接发起对话：<a :href="`tencent://message/?uin=${cs.qq}`" class="link">立即聊天</a></div>
          </div>
        </div>

        <div class="cs-item">
          <div class="cs-icon-box phone"><el-icon :size="34"><PhoneFilled /></el-icon></div>
          <div class="cs-info">
            <div class="cs-label">服务热线</div>
            <div class="cs-value mono">{{ cs.phone }}</div>
            <div class="cs-desc muted small">工作时间：{{ cs.work_time }}</div>
          </div>
        </div>

        <div class="cs-item">
          <div class="cs-icon-box email"><el-icon :size="34"><Message /></el-icon></div>
          <div class="cs-info">
            <div class="cs-label">邮箱</div>
            <div class="cs-value mono"><a :href="`mailto:${cs.email}`" class="link">{{ cs.email }}</a></div>
            <div class="cs-desc muted small">商务合作 / 工单 / 售后咨询</div>
          </div>
        </div>

        <el-divider />
        <div class="cs-tips muted small">
          <div><b>💡 常见问题解答：</b></div>
          <div>• 付款后多久开通？支付完成约 30~90 秒分配服务器，约 1~3 分钟完成初始化配置。</div>
          <div>• 支持哪些远程登录方式？支持 SSH 远程登录、RDP 桌面连接、Web 控制台。</div>
          <div>• 不满意可退款吗？7 天无理由退款（当月使用量 ≤10%）。</div>
        </div>
      </div>
    </el-drawer>
  </el-container>
</template>
<script setup>
import { onMounted, onBeforeUnmount, reactive, ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getCustomerService } from '@/api/config'
import { getNotificationUnreadCount } from '@/api/notifications'

const userStore = useUserStore()
const router = useRouter()

const year = new Date().getFullYear()
const csVisible = ref(false)
const notifyUnread = ref(0)
let notifyPollTimer = null
const promoCountdown = reactive({ d: '02', h: '03', m: '15', s: '56' })

async function loadNotifyUnread() {
  try {
    if (!userStore.isLoggedIn) { notifyUnread.value = 0; return }
    const r = await getNotificationUnreadCount()
    notifyUnread.value = Number(r?.data?.total) || 0
  } catch { notifyUnread.value = 0 }
}
let cdTimer = null
function startCD() {
  const endAt = Date.now() + (2 * 86400 + 3 * 3600 + 15 * 60 + 56) * 1000
  cdTimer = setInterval(() => {
    let diff = Math.max(0, Math.floor((endAt - Date.now()) / 1000))
    const d = String(Math.floor(diff / 86400)).padStart(2, '0'); diff %= 86400
    const h = String(Math.floor(diff / 3600)).padStart(2, '0'); diff %= 3600
    const m = String(Math.floor(diff / 60)).padStart(2, '0'); diff %= 60
    const s = String(diff).padStart(2, '0')
    Object.assign(promoCountdown, { d, h, m, s })
  }, 1000)
}

const cs = reactive({
  wechat: 'metoe_support_01',
  qq: '800888666',
  email: 'support@metoe.io',
  phone: '400-888-6666',
  work_time: '周一至周日 09:00 - 23:00',
  site_name: 'MetoE 全球云服务器',
})

async function loadCS() {
  try {
    const data = await getCustomerService()
    if (data?.data) Object.assign(cs, data.data)
  } catch (e) {}
}

const CMD_ROUTE_MAP = {
  profile: '/profile',
  recharge: '/recharge',
  orders: '/orders',
  verify: '/verify',
  api: '/developer',
}

function handleCommand(cmd) {
  if (!userStore.isLoggedIn) {
    ElMessage.warning('登录状态已失效，正在返回登录页')
    router.push('/login').catch(() => {})
    return
  }
  if (cmd === 'logout') {
    ElMessageBox.confirm('确定要退出登录吗？', '提示', { type: 'warning' })
      .then(() => { userStore.logout(); router.push('/login').catch(() => {}) })
      .catch(() => {})
    return
  }
  const target = CMD_ROUTE_MAP[cmd]
  if (!target) {
    console.warn('[AdminLayout] 未知下拉命令:', cmd)
    return
  }
  console.debug(`[AdminLayout] 下拉跳转 cmd=${cmd} → path=${target}`)
  router.push(target)
    .catch(err => {
      console.warn('[AdminLayout] 跳转失败:', cmd, target, err?.message || err)
      ElMessage.error(`页面跳转失败：${target}`)
    })
}

function copy(text, okMsg = '已复制') {
  navigator.clipboard.writeText(text)
  ElMessage.success(okMsg)
}

onMounted(async () => { loadCS(); startCD(); loadNotifyUnread(); notifyPollTimer = setInterval(loadNotifyUnread, 30 * 1000) })
onBeforeUnmount(() => { if (cdTimer) clearInterval(cdTimer); if (notifyPollTimer) clearInterval(notifyPollTimer) })
</script>
<style scoped>
.layout-root { height: 100%; }
.aside {
  background: #0B1220;
  color: #fff;
  display: flex; flex-direction: column;
  overflow: hidden;
  box-shadow: 2px 0 12px rgba(0,0,0,0.08);
}
.logo {
  height: 68px;
  display: flex; align-items: center; gap: 12px;
  padding: 0 20px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}
.brand-logo {
  width: 42px; height: 42px;
  border-radius: 12px;
  background: linear-gradient(135deg, rgba(16,185,129,0.18), rgba(64,158,255,0.18));
  display: flex; align-items: center; justify-content: center;
  border: 1px solid rgba(16,185,129,0.3);
}
.brand-name { font-size: 20px; font-weight: 700; letter-spacing: 0.5px; color: #fff; }
.brand-sub { font-size: 11px; color: #7c8ba1; margin-top: 2px; }

.menu-scroll { flex: 1; overflow: hidden; }
.menu-scroll :deep(.el-scrollbar__wrap) { overflow-x: hidden; }
.menu {
  border-right: 0;
  padding: 8px 10px 20px;
  background: #0B1220 !important;
}
.menu :deep(.el-menu-item),
.menu :deep(.el-sub-menu__title) {
  height: 44px; line-height: 44px;
  border-radius: 8px;
  margin: 2px 0;
  position: relative;
}
.menu :deep(.el-menu-item:hover),
.menu :deep(.el-sub-menu__title:hover) {
  background-color: rgba(64,158,255,0.10) !important;
  color: #fff !important;
}
.menu :deep(.el-menu-item.is-active) {
  background: linear-gradient(135deg, #409eff, #10b981) !important;
  color: #fff !important;
  box-shadow: 0 4px 14px rgba(64,158,255,0.28);
}
.menu-text { margin-left: 6px; }
.item-dashboard { color: #d9e3f1 !important; }
.item-dashboard :deep(.el-icon) { color: #10b981; }

.promo-tag {
  position: absolute; right: 10px; top: 50%; transform: translateY(-50%);
  font-size: 10px; font-weight: 700; padding: 1px 7px; border-radius: 8px;
  letter-spacing: 0.3px; line-height: 1.5;
}
.promo-tag.inline { position: static; transform: none; margin-left: 6px; }
.promo-tag.inner { position: static; transform: none; margin-left: auto; }
.promo-hot {
  background: linear-gradient(135deg, #ff4d4f, #ff7a45);
  color: #fff;
}
.promo-purple {
  background: linear-gradient(135deg, #8b5cf6, #d946ef);
  color: #fff;
}
.promo-blue {
  background: linear-gradient(135deg, #3b82f6, #0ea5e9);
  color: #fff;
}
.has-tag-inner :deep(.el-menu-item) { justify-content: space-between; }

.menu-divider {
  border-color: rgba(255,255,255,0.06);
  margin: 14px 10px 10px;
}

.menu :deep(.el-sub-menu .el-menu-item) {
  padding-left: 46px !important;
  font-size: 13px;
  color: #8a97ae;
}
.menu :deep(.el-sub-menu .el-menu-item.is-active) {
  background: rgba(64,158,255,0.16) !important;
  color: #fff !important;
  box-shadow: none;
}

.aside-footer {
  padding: 10px 12px 14px;
  border-top: 1px solid rgba(255,255,255,0.06);
  display: grid; grid-template-columns: 1fr 1fr; gap: 8px;
}
.footer-btn { width: 100%; }

/* Header */
.header {
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
  display: flex; justify-content: space-between; align-items: center;
  padding: 0 20px; height: 64px; gap: 16px;
}
.crumbs { min-width: 220px; }
.promo-banner {
  flex: 1; max-width: 720px;
  display: flex; align-items: center; gap: 10px;
  padding: 6px 16px;
  background: linear-gradient(90deg, rgba(255,238,192,0.55), rgba(255,208,75,0.18));
  border: 1px solid #ffd04b;
  border-radius: 10px;
  font-size: 13px; color: #5b4a11;
  white-space: nowrap; overflow: hidden;
}
.promo-title { font-weight: 600; color: #8a6d00; }
.countdown { margin-left: auto; color: #5b4a11; display: flex; align-items: center; gap: 2px; }
.cd-box {
  background: #111827; color: #ffd04b;
  padding: 1px 6px; border-radius: 4px;
  font-family: Consolas, monospace; font-weight: 700; font-size: 12px;
  min-width: 22px; text-align: center; display: inline-block;
}

.user-area { display: flex; align-items: center; gap: 14px; }
.balance-tag {
  padding: 4px 10px !important;
  background: linear-gradient(135deg, #ff7a45, #f56c6c) !important;
  border: none !important;
  cursor: pointer;
  transition: transform .18s ease, box-shadow .18s ease, filter .18s ease;
}
.balance-tag:hover {
  transform: translateY(-1px);
  filter: brightness(1.06);
  box-shadow: 0 6px 16px rgba(245,108,108,.28);
}
.balance-tag .el-icon { color: #fff; }
.balance-tag b { color: #fff; font-size: 14px; margin: 0 2px; }
.icon-btn { color: #6b7280 !important; padding: 4px; }
.notification-badge :deep(.el-badge__content) { transform: scale(0.85) translate(80%, -50%); }

.user-dropdown {
  display: flex; align-items: center; gap: 10px; cursor: pointer;
  padding: 4px 10px; border-radius: 10px;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
}
.user-dropdown:hover { background: #f3f4f6; }
.user-meta { display: flex; flex-direction: column; line-height: 1.2; }
.uname { font-weight: 600; color: #111827; font-size: 13px; }
.urole { color: #6b7280; }

.main { padding: 18px 18px 0; background: #f3f4f6; overflow: auto; }
.fade-enter-active, .fade-leave-active { transition: opacity .2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

.footer {
  height: 42px; line-height: 42px; background: #fff; border-top: 1px solid #e5e7eb;
  padding: 0 20px; display: flex; justify-content: space-between; align-items: center;
}
.footer-links { display: flex; align-items: center; gap: 4px; }
.footer-links .link { color: #409eff; }
.muted { color: #6b7280; } .small { font-size: 12px; } .link { color: #409eff; }

/* CS drawer */
.cs-panel { padding: 0; }
.cs-item {
  display: flex; align-items: center; gap: 14px; padding: 16px 4px;
  border-bottom: 1px dashed #f0f0f0;
}
.cs-item:last-of-type { border-bottom: none; }
.cs-icon-box {
  width: 58px; height: 58px; border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
  color: #fff; flex-shrink: 0;
}
.cs-icon-box.wechat { background: linear-gradient(135deg, #07c160, #10b981); }
.cs-icon-box.qq { background: linear-gradient(135deg, #12b7f5, #2080f0); }
.cs-icon-box.phone { background: linear-gradient(135deg, #ff7a45, #fa8c16); }
.cs-icon-box.email { background: linear-gradient(135deg, #722ed1, #597ef7); }
.cs-info { flex: 1; min-width: 0; }
.cs-label { color: #6b7280; font-size: 12px; margin-bottom: 4px; }
.cs-value { font-size: 16px; font-weight: 600; color: #111827; }
.cs-desc { margin-top: 4px; line-height: 1.5; }
.mono { font-family: Consolas, Monaco, monospace; }
.cs-tips { line-height: 1.9; background: #fafbfc; padding: 12px 14px; border-radius: 8px; }
</style>
