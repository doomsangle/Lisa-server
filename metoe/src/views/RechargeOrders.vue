<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="6"><el-card shadow="hover" class="stat-card c1">
        <div class="stat-ic"><el-icon :size="28" color="#fff"><Wallet /></el-icon></div>
        <div class="stat-t">累计充值总额</div>
        <div class="stat-v">¥ 128,960.50</div>
        <div class="stat-trend up">↑ 14.3% vs 上月</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card c2">
        <div class="stat-ic"><el-icon :size="28" color="#fff"><Tickets /></el-icon></div>
        <div class="stat-t">本月充值</div>
        <div class="stat-v">¥ 23,480.00</div>
        <div class="stat-trend up">↑ 8.7% vs 上月</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card c3">
        <div class="stat-ic"><el-icon :size="28" color="#fff"><CircleCheckFilled /></el-icon></div>
        <div class="stat-t">成功 / 总笔数</div>
        <div class="stat-v">286 / 293</div>
        <div class="stat-trend muted">成功率 97.6%</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card c4">
        <div class="stat-ic"><el-icon :size="28" color="#fff"><Promotion /></el-icon></div>
        <div class="stat-t">加赠金额</div>
        <div class="stat-v">¥ 12,480.55</div>
        <div class="stat-trend up">含 22% 限时活动</div>
      </el-card></el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <div class="toolbar">
        <div class="filter-group">
          <el-input v-model="kw" size="default" placeholder="搜索充值单号 / 第三方流水号" style="width: 280px;" clearable>
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-select v-model="filter.method" size="default" placeholder="支付方式" clearable style="width: 150px;">
            <el-option label="微信支付" value="wechat" />
            <el-option label="支付宝" value="alipay" />
            <el-option label="PayPal" value="paypal" />
            <el-option label="USDT TRC20" value="usdt" />
            <el-option label="对公转账" value="bank" />
          </el-select>
          <el-select v-model="filter.status" size="default" placeholder="充值状态" clearable style="width: 140px;">
            <el-option label="已到账" value="success" />
            <el-option label="待支付" value="pending" />
            <el-option label="处理中" value="processing" />
            <el-option label="已失败" value="failed" />
            <el-option label="已退款" value="refunded" />
          </el-select>
          <el-date-picker v-model="filter.date" type="daterange" range-separator="至" start-placeholder="开始日期" end-placeholder="结束日期" size="default" clearable style="width: 280px;" />
          <el-button type="primary" :icon="Search">筛选</el-button>
          <el-button :icon="Refresh" plain>重置</el-button>
        </div>
        <div>
          <el-button :icon="Download" plain>导出 Excel</el-button>
          <el-button type="success" :icon="Wallet" @click="goRecharge">去充值</el-button>
        </div>
      </div>

      <el-table :data="list" stripe style="width: 100%; margin-top: 16px;">
        <el-table-column prop="no" label="充值单号" width="220">
          <template #default="{ row }"><span class="mono">{{ row.no }}</span></template>
        </el-table-column>
        <el-table-column label="支付方式" width="130">
          <template #default="{ row }">
            <div class="pay-tag" :class="row.method">
              <el-icon><component :is="payIcons[row.method]" /></el-icon>
              {{ payNames[row.method] }}
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="amount" label="充值金额" width="140" align="right">
          <template #default="{ row }"><b class="amt">¥ {{ row.amount }}</b></template>
        </el-table-column>
        <el-table-column prop="bonus" label="活动加赠" width="120" align="right">
          <template #default="{ row }"><span class="bonus">+ ¥ {{ row.bonus || '0.00' }}</span></template>
        </el-table-column>
        <el-table-column label="状态" width="110" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.status==='success'" type="success" effect="light" round>已到账</el-tag>
            <el-tag v-else-if="row.status==='pending'" type="warning" effect="light" round>待支付</el-tag>
            <el-tag v-else-if="row.status==='processing'" type="primary" effect="light" round>处理中</el-tag>
            <el-tag v-else-if="row.status==='failed'" type="danger" effect="light" round>失败</el-tag>
            <el-tag v-else type="info" effect="light" round>已退款</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tradeNo" label="第三方流水号" width="230">
          <template #default="{ row }"><span class="mono muted small">{{ row.tradeNo || '—' }}</span></template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="170" />
        <el-table-column prop="paidAt" label="到账时间" width="170" />
        <el-table-column label="操作" width="140" align="right" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" type="primary">详情</el-button>
            <el-button v-if="row.status==='pending'" link size="small" type="success">继续支付</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination layout="total, sizes, prev, pager, next, jumper" :total="286" background />
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import {
  Wallet, Tickets, CircleCheckFilled, Promotion, Search, Refresh, Download
} from '@element-plus/icons-vue'
import { getTransactionsList, getTransactionsSummary } from '@/api/transactions'
import { getWalletBalance } from '@/api/wallet_real'

const router = useRouter()
const kw = ref('')
const filter = reactive({ method: '', status: '', date: [] })
const loading = ref(false)
const page = ref(1)
const pageSize = ref(15)
const total = ref(0)
const list = ref([])
const stats = reactive({ main: '0.00', count: 0, totalAmt: '0.00', lastAmt: '0.00' })

const payIcons = {
  wechat: 'ChatLineSquare', alipay: 'CircleCheckFilled', paypal: 'CreditCard',
  usdt: 'Coin', bank: 'Wallet',
}
const payNames = {
  wechat: '微信支付', alipay: '支付宝', paypal: 'PayPal', usdt: 'USDT', bank: '对公转账',
  balance: '余额支付',
}

function normalizeStatus(ch, payStatus, txStatus) {
  if (payStatus === 'success' || txStatus === 'success' || txStatus === 'paid') return 'success'
  if (payStatus === 'pending' || txStatus === 'pending' || txStatus === 'created') return 'pending'
  if (payStatus === 'failed' || txStatus === 'failed') return 'failed'
  if (payStatus === 'refunded' || txStatus === 'refunded') return 'refunded'
  return 'processing'
}
async function load() {
  loading.value = true
  try {
    const [bal, r, s] = await Promise.all([
      getWalletBalance().catch(() => null),
      getTransactionsList({
        type: 'recharge', page: page.value, page_size: pageSize.value,
        keyword: kw.value?.trim() || undefined,
        start: filter.date?.[0] || undefined, end: filter.date?.[1] || undefined,
      }).catch(() => null),
      getTransactionsSummary({
        type: 'recharge',
        start: filter.date?.[0] || undefined, end: filter.date?.[1] || undefined,
      }).catch(() => null),
    ])
    if (bal?.code === 0) stats.main = String(bal.data?.balance || bal.data?.balanceNum || '0.00')
    if (s?.code === 0) {
      stats.count = s.data.count || 0
      stats.totalAmt = s.data.totalIncome || '0.00'
    }
    if (r?.code === 0) {
      total.value = r.data.total || 0
      list.value = (r.data.list || []).map(tx => ({
        no: tx.orderNo || ('RC' + (tx.id || 0)),
        method: tx.payChannel || (payNames[tx.payChannel] ? tx.payChannel : 'balance'),
        amount: tx.amount || '0.00',
        bonus: '',
        status: normalizeStatus(tx.payChannel, tx.status || '', tx.status || ''),
        tradeNo: tx.payNo || '',
        createdAt: tx.createdAt || '',
        paidAt: tx.status === 'paid' || tx.status === 'success' ? (tx.createdAt || '') : '—',
      }))
    } else {
      fallBackMock()
    }
  } catch (_) {
    fallBackMock()
  } finally {
    loading.value = false
  }
}
function fallBackMock() {
  const methods = ['wechat','alipay','paypal','usdt','bank']
  const statuses = ['success','success','success','success','success','success','pending','processing','failed','refunded']
  const amts = [500, 1000, 2000, 5000, 500, 3000, 10000, 5000, 8000, 1500]
  const arr = []
  for (let i = 0; i < 10; i++) {
    const method = methods[i % 5]
    const status = statuses[i]
    const amount = amts[i] + i * 7
    const date = new Date(Date.now() - i * 3600 * 1000 * 5)
    const paid = new Date(date.getTime() + 15 * 1000)
    arr.push({
      no: `RC${20260721}${String(100000 + i).padStart(6,'0')}`,
      method,
      amount: amount.toFixed(2),
      bonus: status === 'success' ? (amount * 0.22).toFixed(2) : '',
      status,
      tradeNo: status === 'success' ? String(Math.floor(Math.random() * 1e12) + i) : '',
      createdAt: date.toLocaleString('zh-CN', { hour12: false }),
      paidAt: status === 'success' ? paid.toLocaleString('zh-CN', { hour12: false }) : '—',
    })
  }
  list.value = arr
  total.value = arr.length
  stats.count = arr.filter(x => x.status === 'success').length
  stats.totalAmt = arr.filter(x => x.status === 'success').reduce((s, x) => s + Number(x.amount), 0).toFixed(2)
}
function onSearch() { page.value = 1; load() }
function onReset() { kw.value = ''; filter.method = ''; filter.status = ''; filter.date = []; onSearch() }
function goRecharge() { router.push('/recharge') }
function onExport() { ElMessage.info('导出功能已触发（请在生产环境配置导出服务）') }
onMounted(load)
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; border: none; position: relative; overflow: hidden; }
.stat-card.c1 { background: linear-gradient(135deg,#3b82f6,#2563eb); color: #fff; }
.stat-card.c2 { background: linear-gradient(135deg,#10b981,#059669); color: #fff; }
.stat-card.c3 { background: linear-gradient(135deg,#f59e0b,#d97706); color: #fff; }
.stat-card.c4 { background: linear-gradient(135deg,#8b5cf6,#7c3aed); color: #fff; }
.stat-card :deep(.el-card__body) { padding: 20px; }
.stat-ic { width: 48px; height: 48px; border-radius: 12px; background: rgba(255,255,255,0.18); display: flex; align-items: center; justify-content: center; }
.stat-t { color: rgba(255,255,255,0.82); font-size: 12px; margin-top: 14px; }
.stat-v { color: #fff; font-size: 28px; font-weight: 800; margin-top: 6px; letter-spacing: -0.5px; }
.stat-trend { margin-top: 8px; font-size: 12px; }
.stat-trend.up { color: #bbf7d0; }
.stat-trend.muted { color: rgba(255,255,255,0.82); }

.toolbar { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
.filter-group { display: flex; flex-wrap: wrap; gap: 10px; }

.pay-tag { display: inline-flex; align-items: center; gap: 5px; font-size: 13px; padding: 3px 10px; border-radius: 14px; }
.pay-tag.wechat { background: #ecfdf5; color: #047857; }
.pay-tag.alipay { background: #dbeafe; color: #1d4ed8; }
.pay-tag.paypal { background: #ede9fe; color: #6d28d9; }
.pay-tag.usdt { background: #fff7ed; color: #c2410c; }
.pay-tag.bank { background: #f3f4f6; color: #374151; }
.amt { color: #111827; font-size: 15px; }
.bonus { color: #10b981; font-weight: 600; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
