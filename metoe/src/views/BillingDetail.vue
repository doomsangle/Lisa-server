<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="6"><el-card shadow="hover" class="stat-card c1">
        <div class="lbl muted small">本月消费总额</div>
        <div class="val">¥ 8,642.30</div>
        <el-progress :percentage="62" :stroke-width="6" :show-text="false" color="#3b82f6" />
        <div class="foot muted small">预算额度 ¥ 14,000 / 月</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card">
        <div class="lbl muted small">今日消费</div>
        <div class="val">¥ 286.15</div>
        <el-progress :percentage="38" :stroke-width="6" :show-text="false" color="#10b981" />
        <div class="foot muted small">较昨日 ↑ 6.4%</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card">
        <div class="lbl muted small">可用余额</div>
        <div class="val ok">¥ 45,320.88</div>
        <el-progress :percentage="78" :stroke-width="6" :show-text="false" color="#10b981" />
        <div class="foot muted small">账户安全余量充足</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card">
        <div class="lbl muted small">欠费 / 挂账</div>
        <div class="val err">¥ 0.00</div>
        <el-progress :percentage="0" :stroke-width="6" :show-text="false" color="#f56c6c" />
        <div class="foot muted small">最近账单已全部结清</div>
      </el-card></el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="16">
        <el-card shadow="never" class="trend-card">
          <template #header>
            <div class="card-header">
              <b>近 30 天消费趋势（小时级聚合）</b>
              <el-radio-group v-model="gran" size="small">
                <el-radio-button value="day">按日</el-radio-button>
                <el-radio-button value="week">按周</el-radio-button>
                <el-radio-button value="month">按月</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div class="chart-area">
            <div class="bars">
              <div v-for="(b, i) in bars" :key="i" class="bar-col">
                <div class="bar" :style="{ height: `${b.h}%`, background: b.color }"></div>
                <div class="bar-lbl muted small">{{ b.lbl }}</div>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never" class="trend-card">
          <template #header><b>消费构成（按产品）</b></template>
          <div class="pie-list">
            <div v-for="(p, i) in pies" :key="i" class="pie-row">
              <div class="pie-info">
                <span class="dot" :style="{ background: p.color }"></span>
                <span class="pie-name">{{ p.name }}</span>
                <span class="muted small">（{{ p.count }} 项）</span>
              </div>
              <div class="pie-right">
                <span class="pie-val">¥ {{ p.val }}</span>
                <el-progress :percentage="p.pct" :stroke-width="6" :show-text="false" :color="p.color" style="width: 110px; margin-left: 10px;" />
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <b>消费明细（按订单 / 产品）</b>
          <div>
            <el-tabs v-model="tab" size="small">
              <el-tab-pane label="按时间" name="time" />
              <el-tab-pane label="按服务器" name="server" />
              <el-tab-pane label="按产品类型" name="type" />
            </el-tabs>
          </div>
        </div>
      </template>

      <div class="toolbar">
        <el-input v-model="kw" size="default" placeholder="搜索订单号 / 服务器名 / 产品名" style="width: 280px;" clearable>
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
        <el-select v-model="filter.product" size="default" placeholder="产品类型" clearable style="width: 160px;">
          <el-option label="云服务器 (VPS)" value="vps" />
          <el-option label="带宽包 / 流量" value="bw" />
          <el-option label="DDoS 防护" value="ddos" />
          <el-option label="备份 / 快照" value="bak" />
          <el-option label="IP / 附加服务" value="ip" />
        </el-select>
        <el-date-picker v-model="filter.date" type="month" size="default" placeholder="选择月份" style="width: 180px;" />
        <el-button type="primary" :icon="Search">查询</el-button>
        <el-button plain :icon="Download">导出账单</el-button>
      </div>

      <el-table :data="rows" stripe style="width: 100%; margin-top: 16px;">
        <el-table-column prop="time" label="扣费时间" width="170" />
        <el-table-column prop="orderNo" label="关联订单号" width="220">
          <template #default="{ row }"><span class="mono">{{ row.orderNo }}</span></template>
        </el-table-column>
        <el-table-column label="产品" width="200">
          <template #default="{ row }">
            <div class="prod">
              <span class="prod-tag" :class="row.product">{{ prodNames[row.product] }}</span>
              <span class="prod-name">{{ row.item }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="qty" label="数量" width="80" align="center" />
        <el-table-column prop="unit" label="单价" width="110" align="right">
          <template #default="{ row }">¥ {{ row.unit }}</template>
        </el-table-column>
        <el-table-column label="折扣" width="90" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.discount < 1" type="success" size="small" round>
              {{ Math.round(row.discount * 100) / 10 }}折
            </el-tag>
            <span v-else class="muted small">—</span>
          </template>
        </el-table-column>
        <el-table-column label="本次扣费金额" width="150" align="right">
          <template #default="{ row }"><b class="amt">¥ {{ row.total }}</b></template>
        </el-table-column>
        <el-table-column label="操作" width="110" align="right">
          <template #default>
            <el-button link type="primary" size="small">详情</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination layout="total, sizes, prev, pager, next, jumper" :total="1286" background />
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { Search, Download } from '@element-plus/icons-vue'
import { getTransactionsList, getTransactionsSummary } from '@/api/transactions'

const gran = ref('day')
const tab = ref('time')
const kw = ref('')
const filter = reactive({ product: '', date: '' })
const page = ref(1)
const pageSize = ref(15)
const total = ref(0)
const loading = ref(false)
const statCards = reactive({ monthBill: '0.00', monthPay: '0.00', waitPay: '0.00', coupons: 0 })

const prodNames = { vps: '云服务器', bw: '带宽流量', ddos: 'DDoS防护', bak: '备份快照', ip: '附加服务' }
const txTypeProduct = { order_pay: 'vps', daily_fee: 'vps', order_refund: 'bak', system_adjust: 'ip' }

const bars = ref(Array.from({ length: 30 }, (_, i) => {
  const base = 30 + Math.sin(i / 3) * 20 + Math.random() * 35
  return { h: Math.min(100, Math.max(10, base)), lbl: i % 5 === 0 ? `${i + 1}日` : '', color: base > 65 ? '#f59e0b' : '#10b981' }
}))
const pies = ref([
  { name: '云服务器 (VPS)', count: 8, val: '5,820.00', pct: 67, color: '#3b82f6' },
  { name: '带宽 / 流量包', count: 12, val: '1,380.30', pct: 16, color: '#10b981' },
  { name: 'DDoS 防护', count: 3, val: '780.00', pct: 9, color: '#f59e0b' },
  { name: '备份与快照', count: 6, val: '420.00', pct: 5, color: '#8b5cf6' },
  { name: '附加 IP / 其他', count: 4, val: '242.00', pct: 3, color: '#ef4444' },
])
const rows = ref([])

function mockRows() {
  const ps = ['vps','bw','ddos','bak','ip']
  const items = {
    vps: ['SG-Std-2C4G-SGP01','LA-VC2-1C2G-LAX02','Tokyo-Ent-4C8G-NRT05'],
    bw: ['亚太带宽包 500GB','北美流量季包 3TB','国际精品网 100Mbps'],
    ddos: ['基础 DDoS 防护 20G','高防包 100Gbps/月','高防 IP 30G 突发'],
    bak: ['自动快照 每日保留7份','异地容灾备份包 1TB','镜像库存储 100GB'],
    ip: ['额外独立 IPv4 地址','BGP 静态 IP 租用','反向 DNS 解析'],
  }
  const arr = []
  for (let i = 0; i < 10; i++) {
    const p = ps[i % 5]
    const qty = i % 3 + 1
    const unit = (30 + i * 8).toFixed(2)
    const discount = i % 4 === 0 ? 0.9 : (i % 7 === 0 ? 0.8 : 1)
    arr.push({
      time: new Date(Date.now() - i * 3600 * 1000 * 8).toLocaleString('zh-CN', { hour12: false }),
      orderNo: `ORD${20260721}${String(30000 + i).padStart(6,'0')}`,
      product: p, item: items[p][i % items[p].length], qty, unit, discount,
      total: (qty * parseFloat(unit) * (discount || 1)).toFixed(2)
    })
  }
  return arr
}
async function load() {
  loading.value = true
  try {
    const types = 'order_pay,order_refund,daily_fee,system_adjust'
    const [listR, sumR] = await Promise.all([
      getTransactionsList({
        type: types, keyword: kw.value?.trim() || undefined,
        page: page.value, page_size: pageSize.value,
      }).catch(() => null),
      getTransactionsSummary({ type: types }).catch(() => null),
    ])
    if (sumR?.code === 0) {
      statCards.monthBill = String(sumR.data.totalExpense || '0.00')
      statCards.monthPay = String(sumR.data.totalIncome || '0.00')
    }
    if (listR?.code === 0) {
      total.value = listR.data.total || 0
      const map = { vps: 0, bw: 0, ddos: 0, bak: 0, ip: 0, _other: 0 }
      rows.value = (listR.data.list || []).map(tx => {
        const p = txTypeProduct[tx.type] || 'ip'
        const amt = Math.abs(Number(tx.amountNum || 0))
        map[p] = (map[p] || 0) + amt
        return {
          time: tx.createdAt || '',
          orderNo: tx.orderNo || ('ORD-' + (tx.id || '')),
          product: p, item: (tx.remark || tx.typeLabel || prodNames[p] || '服务消费').slice(0, 32),
          qty: 1, unit: amt.toFixed(2), discount: 1.0,
          total: amt.toFixed(2),
        }
      })
      const totalAmt = Object.values(map).reduce((s, x) => s + x, 0) || 1
      pies.value = ['云服务器','带宽 / 流量包','DDoS 防护','备份与快照','附加 IP / 其他']
        .map((label, idx) => {
          const k = ['vps', 'bw', 'ddos', 'bak', 'ip'][idx]
          const amt = map[k] || 0
          const pct = Math.round((amt / totalAmt) * 100)
          return {
            name: `${label}${[' (VPS)', '', '', '', ''][idx] || ''}`,
            count: Math.max(1, Math.round(amt / 500)),
            val: amt.toFixed(2), pct,
            color: ['#3b82f6','#10b981','#f59e0b','#8b5cf6','#ef4444'][idx],
          }
        })
    } else {
      rows.value = mockRows()
      total.value = rows.value.length
    }
  } catch (_) {
    rows.value = mockRows()
    total.value = rows.value.length
  } finally {
    loading.value = false
  }
}
function onSearch() { page.value = 1; load() }
function onReset() { kw.value = ''; filter.product = ''; filter.date = ''; onSearch() }
function onExport() { ElMessage.info('账单导出功能已触发（请在生产配置报表服务）') }
onMounted(load)
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; }
.stat-card.c1 { background: linear-gradient(135deg,#eff6ff,#e0e7ff); }
.stat-card .lbl { margin-bottom: 6px; }
.stat-card .val { font-size: 28px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.stat-card .val.ok { color: #059669; }
.stat-card .val.err { color: #111827; font-weight: 700; }
.stat-card :deep(.el-progress) { margin: 12px 0 8px; }
.card-header { display: flex; justify-content: space-between; align-items: center; }

.trend-card { border-radius: 14px; height: 100%; }
.chart-area { padding: 10px 4px 4px; }
.bars { display: flex; align-items: flex-end; gap: 5px; height: 220px; border-bottom: 1px dashed #e5e7eb; padding-bottom: 6px; }
.bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 5px; }
.bar { width: 100%; border-radius: 4px 4px 0 0; min-height: 4px; transition: all .3s ease; }
.bar:hover { filter: brightness(1.08); transform: translateY(-2px); }
.bar-lbl { font-size: 11px; }

.pie-list { display: flex; flex-direction: column; gap: 18px; padding: 6px 2px; }
.pie-row { display: flex; justify-content: space-between; align-items: center; gap: 14px; }
.pie-info { display: flex; align-items: center; gap: 8px; min-width: 140px; }
.pie-right { display: flex; align-items: center; }
.dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; }
.pie-name { font-weight: 600; color: #111827; }
.pie-val { color: #111827; font-weight: 700; min-width: 100px; text-align: right; }

.toolbar { display: flex; flex-wrap: wrap; gap: 10px; }
.prod { display: flex; align-items: center; gap: 8px; }
.prod-tag { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.prod-tag.vps { background: #dbeafe; color: #1d4ed8; }
.prod-tag.bw { background: #ecfdf5; color: #047857; }
.prod-tag.ddos { background: #fee2e2; color: #b91c1c; }
.prod-tag.bak { background: #ede9fe; color: #6d28d9; }
.prod-tag.ip { background: #fff7ed; color: #c2410c; }
.prod-name { color: #374151; font-size: 13px; }
.amt { color: #111827; font-size: 14px; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
