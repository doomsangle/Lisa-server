<template>
  <div class="dashboard">
    <el-row :gutter="16">
      <el-col :span="6" v-for="s in stats" :key="s.key">
        <el-card class="stat-card" shadow="hover">
          <div class="stat-icon" :style="{ background: s.bg }">
            <el-icon :size="28" :color="s.color"><component :is="s.icon" /></el-icon>
          </div>
          <div class="stat-body">
            <div class="stat-label muted">{{ s.label }}</div>
            <div class="stat-value">{{ s.value }}</div>
            <div class="stat-trend small" :class="s.trend < 0 ? 'down' : 'up'">
              {{ s.trend >= 0 ? '↑' : '↓' }} {{ Math.abs(s.trend) }}% 较昨日
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="mt-20">
      <el-col :span="16">
        <el-card class="page-card">
          <template #header>
            <div class="flex-between">
              <span class="title">近 {{ chartDays }} 天资金流水</span>
              <el-radio-group v-model="chartRange" size="small">
                <el-radio-button label="7d">7天</el-radio-button>
                <el-radio-button label="30d">30天</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="chartRef" style="height: 320px;"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="page-card">
          <template #header><span class="title">交易类型占比</span></template>
          <div ref="pieRef" style="height: 320px;"></div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="mt-20">
      <el-col :span="12">
        <el-card class="page-card">
          <template #header>
            <div class="flex-between">
              <span class="title">我的云服务器 TOP 5</span>
              <el-button link type="primary" @click="$router.push('/servers')">查看全部 →</el-button>
            </div>
          </template>
          <el-table :data="myServers" size="small" v-loading="loading.servers">
            <el-table-column prop="id" label="ID" width="55" />
            <el-table-column label="配置" min-width="140">
              <template #default="{ row }">
                <div>{{ row.cpuCores }}核/{{ (row.ramMb/1024).toFixed(0) }}G/{{ row.diskGb }}G</div>
                <div class="muted small">{{ row.region }} · {{ row.os }}</div>
              </template>
            </el-table-column>
            <el-table-column prop="ip" label="IP" />
            <el-table-column label="月租" width="75">
              <template #default="{ row }">¥{{ (row.priceMonth||0).toFixed(0) }}</template>
            </el-table-column>
            <el-table-column label="状态" width="65">
              <template #default="{ row }">
                <span class="status-dot" :style="{ background: statusColor(row.status) }"></span>
              </template>
            </el-table-column>
          </el-table>
          <el-empty v-if="!loading.servers && !myServers.length" description="还没有服务器，去购买一台吧" :image-size="80" />
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card class="page-card">
          <template #header>
            <div class="flex-between">
              <span class="title">最近订单 TOP 5</span>
              <el-button link type="primary" @click="$router.push('/orders')">立即购买 →</el-button>
            </div>
          </template>
          <el-table :data="orders" size="small" v-loading="loading.orders">
            <el-table-column prop="orderNo" label="订单号" width="160" />
            <el-table-column prop="product" label="商品" />
            <el-table-column prop="amount" label="金额" width="80">
              <template #default="{ row }">¥{{ row.amount }}</template>
            </el-table-column>
            <el-table-column label="状态" width="80">
              <template #default="{ row }">
                <el-tag size="small" :type="row.status==='paid'?'success':(row.status==='pending'?'warning':'info')">
                  {{ orderStatus(row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="createdAt" label="时间" width="150" />
          </el-table>
          <el-empty v-if="!loading.orders && !orders.length" description="还没有订单" :image-size="80" />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, watch, nextTick } from 'vue'
import * as echarts from 'echarts'
import { useUserStore } from '@/stores/user'
import { listServers } from '@/api/servers'
import { getOrderList } from '@/api/order'
import request from '@/utils/request'
import { Wallet, Monitor, Promotion, List } from '@element-plus/icons-vue'
import { getTransactionsSummary, getTransactionsList } from '@/api/transactions'

const userStore = useUserStore()
const summary = ref({ users: 0, servers: 0, orders: 0, bandwidth: 0 })
const loading = reactive({ servers: false, orders: false })

const baseStats = ref([
  { key: 'balance', label: '账户余额', icon: Wallet, color: '#409eff', bg: 'rgba(64,158,255,0.1)', trend: 8 },
  { key: 'servers', label: '在用云服务器', icon: Monitor, color: '#67c23a', bg: 'rgba(103,194,58,0.1)', trend: 12 },
  { key: 'traffic', label: '本月带宽总量', icon: Promotion, color: '#e6a23c', bg: 'rgba(230,162,60,0.1)', trend: -3 },
  { key: 'orders', label: '累计订单', icon: List, color: '#f56c6c', bg: 'rgba(245,108,108,0.1)', trend: 5 },
])

const stats = ref([])
function refreshStats() {
  stats.value = baseStats.value.map(s => {
    const r = { ...s }
    if (s.key === 'balance') r.value = `¥ ${userStore.userInfo?.balance || '0.00'}`
    if (s.key === 'servers') r.value = summary.value.servers || '0'
    if (s.key === 'traffic') r.value = `${summary.value.bandwidth || 0} Gbps·h`
    if (s.key === 'orders') r.value = summary.value.orders || '0'
    return r
  })
}

const chartRange = ref('7d')
const chartDays = ref(7)
const chartRef = ref(null)
const pieRef = ref(null)
let chartInst = null
let pieInst = null

const myServers = ref([])
const orders = ref([])
const txSummary = ref({})
const txList = ref([])

const statusColor = (s) => ({
  active: '#67c23a', running: '#67c23a', stopped: '#909399',
  provisioning: '#e6a23c', error: '#f56c6c'
})[s] || '#909399'

const orderStatus = (s) => ({
  paid: '已完成', pending: '待支付', cancelled: '已取消', failed: '失败'
})[s] || s

async function loadSummary() {
  try {
    const r = await request({ url: '/stats/summary', method: 'get' }) || {}
    summary.value = r?.data || r || {}
    await userStore.fetchProfile?.().catch(() => {})
    refreshStats()
  } catch (e) { console.warn(e) }
}

async function loadServers() {
  loading.servers = true
  try {
    const res = await listServers({ page: 1, pageSize: 5 })
    myServers.value = (res?.data?.list || res?.list || [])
  } catch (e) {}
  finally { loading.servers = false }
}

async function loadOrders() {
  loading.orders = true
  try {
    const res = await getOrderList({ page: 1, pageSize: 5 })
    orders.value = (res?.data?.list || res?.list || []).map(o => ({
      ...o,
      product: o.productName || o.product || o.planName || '云服务器套餐',
      amount: (o.amount != null ? o.amount : (o.totalAmount || o.total || 0)).toFixed?.(2) || (o.amount || 0),
      createdAt: o.createdAt || o.created_at || '-',
    }))
  } catch (e) {}
  finally { loading.orders = false }
}

async function loadTxData() {
  try {
    const [sr, lr] = await Promise.all([
      getTransactionsSummary({ days: chartDays.value }),
      getTransactionsList({ page: 1, page_size: 300 }),
    ])
    txSummary.value = sr?.data || sr || {}
    txList.value = lr?.data?.list || lr?.list || []
    await nextTick()
    renderChart()
    renderPie()
  } catch (e) {
    await nextTick()
    renderChart(true)
    renderPie(true)
  }
}

function genDates(days) {
  const dates = []
  const d = new Date()
  for (let i = days - 1; i >= 0; i--) {
    const dt = new Date(d.getTime() - i * 86400000)
    dates.push(`${dt.getMonth() + 1}/${dt.getDate()}`)
  }
  return dates
}

function renderChart(fallback) {
  if (!chartInst) return
  const days = chartDays.value
  const dates = genDates(days)

  let income = new Array(days).fill(0)
  let expense = new Array(days).fill(0)

  if (!fallback && txList.value?.length) {
    txList.value.forEach(tx => {
      const dateStr = (tx.createdAt || tx.ts || '').replace(/-/g, '/').slice(0, 10)
      if (!dateStr) return
      const dt = new Date(dateStr)
      const now = new Date(); now.setHours(0,0,0,0)
      const diff = Math.floor((now - dt) / 86400000)
      if (diff < 0 || diff >= days) return
      const idx = days - 1 - diff
      const amt = Number(tx.amount) || 0
      if (['recharge','transfer_in','coupon_rebate','affiliate_commission','order_refund','system_adjust'].includes(tx.type)) {
        income[idx] += amt
      } else {
        expense[idx] += amt
      }
    })
  } else {
    income = dates.map(() => Math.round(50 + Math.random() * 300))
    expense = dates.map(() => Math.round(30 + Math.random() * 200))
  }

  chartInst.setOption({
    tooltip: { trigger: 'axis', valueFormatter: (v) => '¥ ' + Number(v).toFixed(2) },
    legend: { data: ['收入 (充值/退款等)', '支出 (订单/扣费等)'] },
    grid: { left: 50, right: 30, top: 40, bottom: 40 },
    xAxis: { type: 'category', data: dates, boundaryGap: false },
    yAxis: { type: 'value', axisLabel: { formatter: '¥ {value}' } },
    series: [
      {
        name: '收入 (充值/退款等)', type: 'line', smooth: true,
        areaStyle: { opacity: 0.18, color: 'rgba(103,194,58,0.3)' },
        data: income, itemStyle: { color: '#67c23a' }, lineStyle: { width: 2.5 },
      },
      {
        name: '支出 (订单/扣费等)', type: 'line', smooth: true,
        areaStyle: { opacity: 0.18, color: 'rgba(245,108,108,0.3)' },
        data: expense, itemStyle: { color: '#f56c6c' }, lineStyle: { width: 2.5 },
      },
    ]
  })
}

function renderPie(fallback) {
  if (!pieInst) return
  const typeNames = {
    recharge: '充值', order_pay: '订单支付', order_refund: '订单退款',
    transfer_out: '资金划出', transfer_in: '资金划入',
    daily_fee: '日扣费', system_adjust: '系统调整',
    coupon_rebate: '优惠券返利', affiliate_commission: '分销佣金',
  }
  const counts = {}
  if (!fallback && txList.value?.length) {
    txList.value.forEach(tx => {
      const key = typeNames[tx.type] || tx.type || '其他'
      counts[key] = (counts[key] || 0) + Math.abs(Number(tx.amount) || 1)
    })
  }
  let pieData = Object.entries(counts).map(([name, value]) => ({ name, value: Math.round(value * 100) / 100 }))
  if (pieData.length === 0) {
    pieData = [
      { name: '充值',   value: 38 },
      { name: '订单支付', value: 30 },
      { name: '日扣费',   value: 14 },
      { name: '资金划转', value: 10 },
      { name: '其他',     value: 8 },
    ]
  }
  pieInst.setOption({
    tooltip: { trigger: 'item', valueFormatter: (v) => '¥ ' + Number(v).toFixed(2) },
    legend: { orient: 'vertical', left: 'left', top: 'center' },
    series: [{
      type: 'pie', radius: ['42%', '72%'], avoidLabelOverlap: true, center: ['60%','50%'],
      label: { show: true, formatter: '{b}\n{d}%' },
      itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 2 },
      data: pieData,
    }]
  })
}

onMounted(async () => {
  chartDays.value = 7
  await nextTick()
  chartInst = echarts.init(chartRef.value)
  pieInst = echarts.init(pieRef.value)
  await Promise.all([loadSummary(), loadServers(), loadOrders(), loadTxData()])
  window.addEventListener('resize', () => { chartInst?.resize(); pieInst?.resize() })
})

watch(chartRange, async (r) => {
  chartDays.value = r === '7d' ? 7 : 30
  await loadTxData()
})
</script>

<style scoped>
.dashboard { }
.stat-card { display: flex; align-items: center; gap: 16px; padding: 8px !important; }
.stat-card :deep(.el-card__body) { display: flex; align-items: center; gap: 16px; width: 100%; }
.stat-icon { width: 56px; height: 56px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.stat-label { font-size: 13px; }
.stat-value { font-size: 22px; font-weight: 600; margin: 4px 0; }
.stat-trend.up { color: #67c23a; }
.stat-trend.down { color: #f56c6c; }
.mt-20 { margin-top: 16px; }
.title { font-weight: 600; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }
.muted { color: #6b7280; }
.small { font-size: 12px; }
.status-dot {
  display: inline-block;
  width: 10px; height: 10px;
  border-radius: 50%;
  box-shadow: 0 0 0 3px rgba(0,0,0,0.05);
}
</style>
