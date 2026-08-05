<template>
  <div class="ph-wrap">
    <el-card class="ph-card" shadow="hover">
      <div class="ph-left">
        <div class="ph-icon-box" :style="{ background: bg }">
          <el-icon :size="56" color="#fff"><component :is="iconName" /></el-icon>
        </div>
      </div>
      <div class="ph-body">
        <el-tag :type="statusType" effect="dark" round size="large" class="status-tag">{{ statusText }}</el-tag>
        <h1 class="ph-title">{{ title }}</h1>
        <p class="ph-desc">{{ description }}</p>

        <div class="ph-features">
          <div class="feat" v-for="(f, i) in features" :key="i">
            <el-icon color="#10b981"><CircleCheckFilled /></el-icon>
            <span>{{ f }}</span>
          </div>
        </div>

        <div class="ph-actions">
          <el-button type="primary" size="large" :icon="Back" @click="goBack">返回上一页</el-button>
          <el-button size="large" :icon="Monitor" @click="goDash">返回仪表盘</el-button>
          <el-button type="success" size="large" plain :icon="Service" @click="goBuy">
            {{ title.includes('充值') ? '联系客服充值' : '联系客服' }}
          </el-button>
        </div>

        <div class="ph-roadmap" v-if="roadmap && roadmap.length">
          <div class="rm-title muted small">功能迭代路线图：</div>
          <el-steps :active="1" finish-status="success" simple size="small">
            <el-step v-for="(s, i) in roadmap" :key="i" :title="s" />
          </el-steps>
        </div>
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  Lock, Tickets, Wallet, List, CreditCard, RefreshRight,
  Present, UserFilled, Key, Notebook, Avatar, Reading, Share,
  Back, Monitor, Service, CircleCheckFilled
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()

const title = computed(() => route.meta?.title || '功能模块')
const iconName = computed(() => {
  const iconMap = {
    'Lock': Lock, 'Tickets': Tickets, 'Wallet': Wallet, 'List': List,
    'CreditCard': CreditCard, 'RefreshRight': RefreshRight, 'Present': Present,
    'UserFilled': UserFilled, 'Key': Key, 'Notebook': Notebook,
    'Avatar': Avatar, 'Reading': Reading, 'Share': Share
  }
  return iconMap[route.meta?.icon] || Reading
})
const statusType = computed(() => {
  const group = route.meta?.group || ''
  if (group === '系统管理') return 'warning'
  if (route.meta?.icon === 'Avatar') return 'success'
  return 'primary'
})
const statusText = computed(() => {
  const name = route.name?.toString() || ''
  if (['Recharge', 'Recharges', 'Verify'].includes(name)) return '即将上线'
  return '模块开发中'
})
const bg = computed(() => {
  const gr = route.meta?.group || ''
  if (gr === '系统管理') return 'linear-gradient(135deg,#fa8c16,#ff7a45)'
  if (gr === '账户中心') return 'linear-gradient(135deg,#10b981,#07c160)'
  if (gr === '产品中心') return 'linear-gradient(135deg,#409eff,#597ef7)'
  return 'linear-gradient(135deg,#722ed1,#9254de)'
})
const description = computed(() => {
  const map = {
    '安全策略': '账户安全策略模块：两步验证、登录设备管理、API 白名单、操作密码保护。',
    '充值订单': '充值订单查询：微信/支付宝/USDT/PayPal 充值流水、充值状态、到账时间。',
    '费用明细': '每小时/每日消费明细：按服务器、带宽、流量、附加服务拆分账单。',
    '充值中心': '支持余额充值：微信、支付宝、PayPal、USDT TRC20，充值享限时加赠 22%。',
    '自动续订': '管理云服务器的自动续订开关、续费优惠提醒、到期前自动扣费。',
    '优惠券': '查看可用优惠券、历史使用记录，输入兑换码领取新人/节日优惠券。',
    '子账号管理': '支持多角色子账号：财务、运营、开发，权限细粒度控制，操作日志审计。',
    '激活兑换码': '输入活动兑换码 / 礼品卡，领取余额、服务器时长、带宽包等奖励。',
    '敏感操作日志': '登录、修改密码、删除资源、退款、改权限等敏感操作全链路留痕。',
    '实名认证': '个人/企业实名认证，审核后解锁更多购买额度、双倍活动奖励通道。',
    '资源中心': '产品文档、SDK 下载、API 示例、最佳实践教程、视频培训课程。',
    '推荐分销中心': '邀请好友注册购买，享阶梯返佣 2.7% 起，实时提现到微信/支付宝。',
  }
  return map[title.value] || `${title.value} 模块正在紧张开发中，敬请期待。`
})
const features = computed(() => {
  const list = {
    '充值中心': [
      '限时活动：充值 1000 加赠 220 (限时 7 月 31 日前)',
      '最低 50 元起充，首次充 ≥500 再送 30 天入门型服务器',
      '支持微信 / 支付宝 / PayPal / USDT TRC20 / 对公转账'
    ],
    '实名认证': [
      '个人实名：身份证 + 人脸识别，约 3 秒极速审核',
      '企业实名：营业执照 + 法人授权，享合同与增值税专票',
      '成功后解锁：双倍活动奖励 / 购买额度提升至 100 台 / 免费基础 DDoS'
    ],
    '自动续订': [
      '到期前 7 天 / 1 天短信 + 邮件提醒',
      '开启自动续订享 95 折，提前 3 小时自动扣余额',
      '余额不足跳过，不影响其他实例正常运行'
    ],
    '推荐分销中心': [
      '注册即送专属邀请链接 + 海报 + 邀请二维码',
      '好友首充 返 5%，复购 返 2.7%，VIP 分销员返佣最高 8%',
      '佣金自动入账，满 100 元 T+1 提现到微信 / 支付宝'
    ]
  }
  return list[title.value] || [
    '功能架构设计已完成，前端 UI 已接入菜单',
    '后端接口开发中，预计 1~2 个工作日内上线',
    '如需优先启用，可联系客服申请白名单提前体验'
  ]
})
const roadmap = computed(() => {
  if (route.path === '/recharge') return ['微信/支付宝对接', 'PayPal/USDT 对接', '自动充值到账 + 充值流水']
  if (route.path === '/verify') return ['个人身份证实名', '企业营业执照认证', '额度/奖励自动解锁']
  if (route.path === '/autorenew') return ['续费开关', '提醒通知（短信/邮件）', '自动扣费 + 失败重试']
  if (route.path === '/affiliate') return ['邀请链接生成', '返佣统计', '佣金结算 + 提现']
  return ['产品需求评审', 'UI/UX 定稿', '后端开发', '测试上线']
})

function goBack() { router.back() }
function goDash() { router.push('/dashboard') }
function goBuy() { router.push('/servers/buy') }
</script>
<style scoped>
.ph-wrap { padding: 20px; }
.ph-card { border-radius: 16px; overflow: hidden; background: #fff; }
.ph-card :deep(.el-card__body) { padding: 36px; display: flex; gap: 32px; }
.ph-left { flex-shrink: 0; }
.ph-icon-box {
  width: 140px; height: 140px; border-radius: 28px;
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 18px 40px rgba(0,0,0,0.12);
}
.ph-body { flex: 1; min-width: 0; }
.status-tag { margin-bottom: 16px; font-weight: 600; }
.ph-title {
  font-size: 28px; font-weight: 700; color: #111827;
  margin: 0 0 10px; letter-spacing: -0.5px;
}
.ph-desc { color: #4b5563; font-size: 14px; line-height: 1.75; margin: 0 0 20px; }
.ph-features { display: flex; flex-direction: column; gap: 10px; margin: 0 0 28px; }
.feat { display: flex; align-items: center; gap: 10px; color: #1f2937; font-size: 14px; }
.ph-actions { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 28px; }
.rm-title { margin: 0 0 10px; }
.muted { color: #6b7280; } .small { font-size: 12px; }
@media (max-width: 860px) {
  .ph-card :deep(.el-card__body) { flex-direction: column; padding: 24px; }
  .ph-icon-box { width: 96px; height: 96px; border-radius: 20px; }
  .ph-icon-box :deep(.el-icon) { transform: scale(0.7); }
}
</style>
