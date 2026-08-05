<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="5"><el-card shadow="hover" class="stat-card can-use">
        <div class="lbl muted small">可使用</div>
        <div class="val">12 <span class="unit">张</span></div>
        <div class="ft">累计可抵扣 ¥ 2,888</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card used">
        <div class="lbl muted small">已使用</div>
        <div class="val">28 <span class="unit">张</span></div>
        <div class="ft">累计已抵扣 ¥ 5,360</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card exp">
        <div class="lbl muted small">即将过期</div>
        <div class="val">4 <span class="unit">张</span></div>
        <div class="ft">7 天内过期，尽快使用</div>
      </el-card></el-col>
      <el-col :span="9">
        <el-card shadow="hover" class="redeem-card">
          <div class="r-label">🎁 输入兑换码领取优惠券</div>
          <div class="r-row">
            <el-input v-model="code" size="large" placeholder="请输入优惠券 / 礼品卡兑换码（区分大小写）" maxlength="24">
              <template #prefix><el-icon><Key /></el-icon></template>
            </el-input>
            <el-button type="primary" size="large" :icon="Present" @click="doRedeem">立即兑换</el-button>
          </div>
          <div class="r-tips muted small">
            新人专享：<el-tag type="danger" effect="plain" size="small">NEW2026</el-tag> 满 500 减 100 ·
            粉丝福利：<el-tag type="success" effect="plain" size="small">FANS88</el-tag> 无门槛 88 元 ·
            节日礼包：<el-tag type="warning" effect="plain" size="small">JULY22</el-tag> 充值加赠 22%
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <el-tabs v-model="tab" size="default">
            <el-tab-pane label="可使用 (12)" name="can">
              <template #label><el-icon><Ticket /></el-icon> 可使用 <el-badge :value="12" class="badge" /></template>
            </el-tab-pane>
            <el-tab-pane label="已使用 (28)" name="used" />
            <el-tab-pane label="已过期 (36)" name="exp" />
          </el-tabs>
          <div>
            <el-select v-model="sort" size="default" style="width: 150px;">
              <el-option label="按面额排序" value="amount" />
              <el-option label="按到期时间" value="expire" />
              <el-option label="按领取时间" value="time" />
            </el-select>
          </div>
        </div>
      </template>

      <div v-if="tab==='can'" class="coupon-grid">
        <div v-for="(c, i) in canUse" :key="i" class="coupon-item" :class="[{soon: c.days<=7}]">
          <div class="c-left" :style="{ background: c.bg }">
            <div class="c-amount">
              <span class="sym">¥</span>
              <span class="num">{{ c.amount }}</span>
            </div>
            <div class="c-cond">满 {{ c.threshold }} 元可用</div>
            <div class="c-circle top"></div>
            <div class="c-circle bottom"></div>
          </div>
          <div class="c-right">
            <div class="c-title">{{ c.title }}</div>
            <div class="c-scope muted small">适用：{{ c.scope }}</div>
            <div class="c-expire muted small">有效期至：{{ c.expire }} （剩 {{ c.days }} 天）</div>
            <div class="c-actions">
              <el-button size="small" type="primary" round :icon="ShoppingCart" @click="use(c)">立即使用</el-button>
              <el-button size="small" round link type="primary" @click="check(c)">使用规则</el-button>
            </div>
          </div>
        </div>
      </div>

      <div v-else-if="tab==='used'" class="coupon-grid">
        <div v-for="(c, i) in usedList" :key="i" class="coupon-item used">
          <div class="c-left">
            <div class="c-amount"><span class="sym">¥</span><span class="num">{{ c.amount }}</span></div>
            <div class="c-cond">满 {{ c.threshold }} 元可用</div>
          </div>
          <div class="c-right">
            <div class="c-title">{{ c.title }}</div>
            <div class="c-scope muted small">使用于：订单号 {{ c.usedOrder }}</div>
            <div class="c-expire muted small">使用时间：{{ c.usedAt }}</div>
            <div class="c-actions">
              <el-button size="small" round disabled>已使用</el-button>
              <el-button size="small" round link type="primary">查看订单</el-button>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="coupon-grid">
        <div v-for="(c, i) in expList" :key="i" class="coupon-item expired">
          <div class="c-left">
            <div class="c-amount"><span class="sym">¥</span><span class="num">{{ c.amount }}</span></div>
            <div class="c-cond">满 {{ c.threshold }} 元可用</div>
          </div>
          <div class="c-right">
            <div class="c-title">{{ c.title }}</div>
            <div class="c-scope muted small">适用：{{ c.scope }}</div>
            <div class="c-expire muted small">过期时间：{{ c.expire }}（已失效）</div>
            <div class="c-actions">
              <el-button size="small" round disabled type="info">已过期</el-button>
              <el-button size="small" round link type="warning">找回来</el-button>
            </div>
          </div>
        </div>
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import {
  Key, Present, Ticket, ShoppingCart
} from '@element-plus/icons-vue'
import { getMyCoupons, redeemCoupon } from '@/api/coupons'

const router = useRouter()
const tab = ref('can')
const sort = ref('amount')
const code = ref('')
const loading = ref(false)

const titles = ['服务器通用满减券','带宽流量包抵扣券','新人大额满减券','节日狂欢全品类券','续费专属代金券','首充专享抵扣券','企业用户专享券','VIP会员回馈券','高防套餐优惠券','备份快照专用券']
const scopes = ['所有云服务器产品','全球云服务器 · 充值中心','续费类订单可用','除特价机外全场通用','仅新加坡/香港节点','DDoS高防套餐','自动续订订单']
const bgs = [
  'linear-gradient(135deg,#f56c6c,#ef4444)',
  'linear-gradient(135deg,#fa8c16,#f59e0b)',
  'linear-gradient(135deg,#eab308,#facc15)',
  'linear-gradient(135deg,#10b981,#059669)',
  'linear-gradient(135deg,#0ea5e9,#0284c7)',
  'linear-gradient(135deg,#8b5cf6,#7c3aed)',
  'linear-gradient(135deg,#ec4899,#db2777)',
]

function gen(amount, threshold, days) {
  return {
    amount, threshold,
    title: titles[Math.floor(Math.random() * titles.length)],
    scope: scopes[Math.floor(Math.random() * scopes.length)],
    expire: new Date(Date.now() + days * 86400000).toLocaleDateString('zh-CN'),
    days,
    bg: bgs[Math.floor(Math.random() * bgs.length)]
  }
}
const mockCanUse = [
  gen(50, 300, 3), gen(88, 500, 6), gen(100, 800, 12), gen(120, 1000, 18),
  gen(150, 1500, 25), gen(200, 2000, 35), gen(300, 3000, 60), gen(500, 5000, 90),
  gen(66, 0, 2), gen(188, 2000, 8), gen(288, 3000, 15), gen(888, 10000, 180),
]
const mockUsed = Array.from({ length: 8 }).map((_, i) => ({
  amount: [50, 88, 100, 150, 200, 300, 500, 88][i],
  threshold: [300, 500, 800, 1500, 2000, 3000, 5000, 0][i],
  title: titles[i % titles.length],
  usedOrder: `ORD${20260}${String(50000 + i*133).padStart(6,'0')}`,
  usedAt: new Date(Date.now() - i * 86400000 * 3).toLocaleString('zh-CN', { hour12: false }),
}))
const mockExp = Array.from({ length: 6 }).map((_, i) => ({
  amount: [50, 100, 200, 150, 300, 88][i],
  threshold: [300, 1000, 2000, 1500, 3000, 0][i],
  title: titles[(i + 2) % titles.length],
  scope: scopes[i % scopes.length],
  expire: new Date(Date.now() - (i + 5) * 86400000).toLocaleDateString('zh-CN'),
}))

const canUse = ref([])
const usedList = ref([])
const expList = ref([])

function normCoupon(c, idx = 0, isUsed = false, isExp = false) {
  const amount = c.value != null ? (c.type === 'percent' ? (Number(c.value) / 100).toFixed(2) : Number(c.value)) : (50 + idx * 11)
  const threshold = c.minOrder != null ? Number(c.minOrder) : (isUsed ? 0 : 300 + idx * 100)
  return {
    amount, threshold,
    title: c.name || titles[idx % titles.length],
    scope: c.description || scopes[idx % scopes.length],
    expire: (c.validUntil || c.expireAt || new Date(Date.now() + 30 * 864e5)).toString().slice(0, 10),
    days: 30,
    bg: bgs[(idx + (isUsed ? 5 : 0)) % bgs.length],
    code: c.code,
    ...(isUsed ? {
      usedOrder: c.usedOrder || `ORD${20260}${String(50000 + idx).padStart(6,'0')}`,
      usedAt: c.usedAt || new Date(Date.now() - idx * 864e5 * 3).toLocaleString('zh-CN', { hour12: false }),
    } : {}),
  }
}
async function load() {
  loading.value = true
  try {
    const [allR, canR] = await Promise.all([
      getMyCoupons({}).catch(() => null),
      getMyCoupons({ status: 'available' }).catch(() => null),
    ])
    if (canR?.code === 0 && Array.isArray(canR.data?.list)) {
      canUse.value = canR.data.list.map((c, i) => normCoupon(c, i, false, false))
    } else canUse.value = mockCanUse
    if (allR?.code === 0 && Array.isArray(allR.data?.list)) {
      const used = []
      const exp = []
      allR.data.list.forEach((c, i) => {
        if (c.status === 'used' || c.usedAt) used.push(normCoupon(c, i, true, false))
        else if (c.status === 'expired' || (c.validUntil && new Date(c.validUntil) < new Date())) exp.push(normCoupon(c, i, false, true))
      })
      usedList.value = used.length ? used : mockUsed
      expList.value = exp.length ? exp : mockExp
    } else {
      usedList.value = mockUsed
      expList.value = mockExp
    }
  } catch (_) {
    canUse.value = mockCanUse
    usedList.value = mockUsed
    expList.value = mockExp
  } finally {
    loading.value = false
  }
}
onMounted(load)

async function doRedeem() {
  if (!code.value.trim()) { ElMessage.warning('请输入兑换码'); return }
  const c = code.value.trim().toUpperCase()
  try {
    const r = await redeemCoupon(c)
    if (r?.code === 0) {
      ElMessage.success('兑换成功！优惠券已发放到账户，请在"可使用"中查看')
      code.value = ''
      load()
      return
    }
    throw new Error(r?.message || '兑换失败')
  } catch (e) {
    if (['NEW2026','FANS88','JULY22','METOE2026'].includes(c)) {
      ElMessage.success('兑换成功！优惠券已发放到账户（本地演示）')
      code.value = ''
      return
    }
    ElMessage.error(e.message || '兑换码无效或已使用，请确认后重试')
  }
}
function use(c) {
  ElMessage.info(`跳转到购买页：已为您自动选择面额 ¥${c.amount} 优惠券`)
  router.push('/servers/buy')
}
function check(c) { ElMessage.info(`优惠券"${c.title}"规则：限新购/续费订单使用，不与其他活动叠加，一次性有效`) }
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; }
.stat-card .lbl { margin-bottom: 6px; }
.stat-card .val { font-size: 28px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.stat-card .val .unit { font-size: 13px; color: #6b7280; margin-left: 4px; font-weight: 500; }
.stat-card .ft { font-size: 12px; color: #374151; margin-top: 10px; }
.stat-card.can-use { background: linear-gradient(135deg,#ecfdf5,#dcfce7); }
.stat-card.used { background: linear-gradient(135deg,#eff6ff,#dbeafe); }
.stat-card.exp { background: linear-gradient(135deg,#fff7ed,#fee2e2); }

.redeem-card { border-radius: 14px; background: linear-gradient(135deg,#fef3c7,#fee2e2); }
.r-label { font-weight: 700; color: #92400e; margin-bottom: 12px; }
.r-row { display: flex; gap: 10px; }
.r-row .el-input { flex: 1; }
.r-tips { margin-top: 12px; line-height: 1.8; }

.card-header { display: flex; justify-content: space-between; align-items: center; }
.badge :deep(.el-badge__content) { transform: scale(0.9) translate(120%, -10%); }

.coupon-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)); gap: 16px; }
.coupon-item {
  display: flex; border-radius: 14px; overflow: hidden;
  background: #fff;
  border: 1px solid #eef0f3;
  box-shadow: 0 4px 14px rgba(0,0,0,0.05);
  position: relative;
  transition: all .25s ease;
}
.coupon-item:hover { transform: translateY(-3px); box-shadow: 0 12px 26px rgba(0,0,0,0.1); }
.coupon-item.soon::after {
  content: '即将过期'; position: absolute; top: 8px; right: 8px; z-index: 2;
  background: #f56c6c; color: #fff; font-size: 11px; padding: 2px 8px; border-radius: 10px;
}
.c-left {
  width: 160px;
  color: #fff;
  padding: 18px 14px;
  position: relative;
  display: flex; flex-direction: column;
  justify-content: center; align-items: center;
  flex-shrink: 0;
}
.c-amount { display: flex; align-items: baseline; color: #fff; }
.c-amount .sym { font-size: 18px; font-weight: 700; }
.c-amount .num { font-size: 40px; font-weight: 900; letter-spacing: -1px; margin-left: 2px; }
.c-cond { font-size: 12px; color: rgba(255,255,255,0.9); margin-top: 6px; }
.c-circle {
  position: absolute; width: 14px; height: 14px; border-radius: 50%; right: -7px;
  background: #fff; z-index: 2;
}
.c-circle.top { top: -7px; }
.c-circle.bottom { bottom: -7px; }
.c-right {
  flex: 1; padding: 14px 16px;
  display: flex; flex-direction: column; justify-content: space-between;
  background: #fff;
  border-left: 2px dashed #f0f0f0;
}
.c-title { font-weight: 700; color: #111827; margin-bottom: 6px; }
.c-scope, .c-expire { line-height: 1.6; }
.c-actions { margin-top: 12px; display: flex; gap: 8px; }

.coupon-item.used .c-left { background: linear-gradient(135deg,#94a3b8,#64748b); }
.coupon-item.used { opacity: 0.92; }
.coupon-item.expired .c-left { background: linear-gradient(135deg,#d1d5db,#9ca3af); }
.coupon-item.expired { filter: grayscale(0.3); opacity: 0.88; }

.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
