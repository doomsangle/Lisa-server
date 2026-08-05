import { createRouter, createWebHashHistory } from 'vue-router'
import { useUserStore } from '@/stores/user'
import AdminLayout from '@/layout/AdminLayout.vue'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { public: true, title: '登录' }
  },
  {
    path: '/',
    component: AdminLayout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/Dashboard.vue'),
        meta: { group: null, title: '控制台', icon: 'DataAnalysis', permission: 'dashboard:view' }
      },
      {
        path: 'servers/buy',
        name: 'ServerBuy',
        component: () => import('@/views/proxies/BuyPage.vue'),
        meta: { group: '产品中心', title: '全球云服务器购买', icon: 'Cpu', permission: 'orders:create' }
      },
      {
        path: 'affiliate',
        name: 'Affiliate',
        component: () => import('@/views/Affiliate.vue'),
        meta: { group: '产品中心', title: '推荐分销中心', icon: 'Share', permission: 'dashboard:view' }
      },
      {
        path: 'policy',
        name: 'Policy',
        component: () => import('@/views/SecurityPolicy.vue'),
        meta: { group: '系统管理', title: '安全策略', icon: 'Lock', permission: 'dashboard:view' }
      },
      {
        path: 'orders',
        name: 'OrdersList',
        component: () => import('@/views/OrdersList.vue'),
        meta: { group: '系统管理', title: '历史订单', icon: 'Tickets', permission: 'orders:view' }
      },
      {
        path: 'orders/:orderNo',
        name: 'OrderDetail',
        component: () => import('@/views/OrderDetail.vue'),
        meta: { group: '系统管理', title: '订单详情', hidden: true, permission: 'orders:view' }
      },
      {
        path: 'recharges',
        name: 'Recharges',
        component: () => import('@/views/RechargeOrders.vue'),
        meta: { group: '系统管理', title: '充值订单', icon: 'Wallet', permission: 'dashboard:view' }
      },
      {
        path: 'billing',
        name: 'Billing',
        component: () => import('@/views/BillingDetail.vue'),
        meta: { group: '系统管理', title: '费用明细', icon: 'List', permission: 'dashboard:view' }
      },
      {
        path: 'recharge',
        name: 'Recharge',
        component: () => import('@/views/RechargeCenter.vue'),
        meta: { group: '系统管理', title: '充值中心', icon: 'CreditCard', permission: 'dashboard:view' }
      },
      {
        path: 'autorenew',
        name: 'AutoRenew',
        component: () => import('@/views/AutoRenew.vue'),
        meta: { group: '系统管理', title: '自动续订', icon: 'RefreshRight', permission: 'dashboard:view' }
      },
      {
        path: 'coupons',
        name: 'Coupons',
        component: () => import('@/views/Coupons.vue'),
        meta: { group: '系统管理', title: '优惠券', icon: 'Present', permission: 'dashboard:view' }
      },
      {
        path: 'subaccounts',
        name: 'SubAccounts',
        component: () => import('@/views/SubAccounts.vue'),
        meta: { group: '系统管理', title: '子账号管理', icon: 'UserFilled', permission: 'dashboard:view' }
      },
      {
        path: 'redeem',
        name: 'Redeem',
        component: () => import('@/views/Redeem.vue'),
        meta: { group: '系统管理', title: '激活兑换码', icon: 'Key', permission: 'dashboard:view' }
      },
      {
        path: 'audit',
        name: 'Audit',
        component: () => import('@/views/AuditLog.vue'),
        meta: { group: '系统管理', title: '敏感操作日志', icon: 'Notebook', permission: 'dashboard:view' }
      },
      {
        path: 'verify',
        name: 'Verify',
        component: () => import('@/views/Verify.vue'),
        meta: { group: '账户中心', title: '实名认证', icon: 'Avatar', permission: 'dashboard:view' }
      },
      {
        path: 'profile',
        name: 'Profile',
        alias: ['settings', 'user/profile'],
        component: () => import('@/views/Profile.vue'),
        meta: { group: '账户中心', title: '个人中心', icon: 'User', hidden: true }
      },
      {
        path: 'resources',
        name: 'Resources',
        component: () => import('@/views/Resources.vue'),
        meta: { group: '工具支持', title: '资源中心', icon: 'Reading', permission: 'dashboard:view' }
      },
      {
        path: 'servers',
        name: 'ServersList',
        component: () => import('@/views/ServersList.vue'),
        meta: { group: '业务管理', title: '我的云服务器', icon: 'Monitor', permission: 'servers:view' }
      },
      {
        path: 'system/users',
        name: 'UserManage',
        component: () => import('@/views/system/Users.vue'),
        meta: { group: '系统设置', title: '用户管理', icon: 'User', permission: 'dashboard:view' }
      },
      {
        path: 'system/roles',
        name: 'RoleManage',
        component: () => import('@/views/system/Roles.vue'),
        meta: { group: '系统设置', title: '角色权限', icon: 'Lock', roles: ['super_admin','admin'], permission: 'system:roles:view' }
      },
      {
        path: 'system/configs',
        name: 'SystemConfigs',
        component: () => import('@/views/system/Configs.vue'),
        meta: { group: '系统设置', title: '全局配置', icon: 'Setting', roles: ['super_admin'], permission: 'config:view' }
      },
      {
        path: 'wallet/transfer',
        name: 'FundTransfer',
        component: () => import('@/views/wallet/FundTransfer.vue'),
        meta: { group: '系统管理', title: '资金划转', icon: 'Wallet', permission: 'dashboard:view' }
      },
      {
        path: 'wallet/funds',
        name: 'FundFlow',
        component: () => import('@/views/wallet/FundFlow.vue'),
        meta: { group: '系统管理', title: '资金流向', icon: 'DataLine', permission: 'dashboard:view' }
      },
      {
        path: 'check',
        name: 'CheckCenter',
        component: () => import('@/views/CheckCenter.vue'),
        meta: { group: '工具支持', title: '网络检测中心', icon: 'ZoomIn', permission: 'check:run' }
      },
      {
        path: 'developer',
        name: 'Developer',
        component: () => import('@/views/Developer.vue'),
        meta: { group: '工具支持', title: '开发者 API', icon: 'MagicStick', permission: 'developer:view' }
      },
      {
        path: 'feedback',
        name: 'Feedback',
        component: () => import('@/views/Feedback.vue'),
        meta: { group: '工具支持', title: '反馈建议', icon: 'ChatLineSquare', permission: 'feedback:create' }
      },
      {
        path: 'notifications',
        name: 'Notifications',
        component: () => import('@/views/Notifications.vue'),
        meta: { group: '工具支持', title: '通知中心', icon: 'Bell', permission: 'notifications:view' }
      },
      {
        path: 'nodes/:any(.*)',
        redirect: '/servers/buy',
        meta: { hidden: true }
      }
    ]
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard', meta: { _catch: true } }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior: () => ({ left: 0, top: 0 })
})

router.onError((err, to, from) => {
  if (typeof err === 'object' && (
    String(err.message || '').includes('Failed to fetch dynamically imported module') ||
    String(err.message || '').includes('Loading chunk') ||
    String(err.message || '').includes('Cannot find')
  )) {
    console.warn('[Router] 组件加载失败，跳转到控制台：', err?.message, to?.fullPath)
  } else {
    console.warn('[Router] 路由异常，跳转到控制台：', err, to?.fullPath)
  }
  try {
    const userStore = useUserStore()
    if (!userStore.isLoggedIn) { router.replace('/login'); return }
    router.replace('/dashboard').catch(() => {})
  } catch {
    router.replace('/login').catch(() => {})
  }
})

router.beforeEach(async (to, from, next) => {
  const userStore = useUserStore()

  if (to.meta?.public) {
    if (to.path === '/login' && userStore.isLoggedIn) return next('/dashboard')
    return next()
  }

  if (!userStore.isLoggedIn) return next({ path: '/login', query: { redirect: to.fullPath } })

  try {
    if (!userStore.roles || userStore.roles.length === 0) {
      try { await userStore.fetchProfile() }
      catch (e) { return next('/login') }
    }

    if (to.meta?._catch && from.path === to.path) {
      return next(false)
    }
    const last = to.matched && to.matched.length ? to.matched[to.matched.length - 1] : null
    if (last && last.meta?._catch) {
      if (to.path !== '/dashboard') return next('/dashboard')
    }

    if (to.meta?.roles && to.meta.roles.length) {
      const has = to.meta.roles.some(r => userStore.roles.includes(r))
      if (!has) {
        console.warn('[Router] 无角色权限，跳回控制台：', to.path, userStore.roles)
        return next('/dashboard')
      }
    }
    if (to.meta?.permission && !userStore.hasPermission(to.meta.permission)) {
      console.warn('[Router] 无功能权限，跳回控制台：', to.path, to.meta?.permission)
      return next('/dashboard')
    }

    next()
  } catch (err) {
    console.warn('[Router] 导航异常，跳回控制台：', err)
    next('/dashboard')
  }
})

export default router
