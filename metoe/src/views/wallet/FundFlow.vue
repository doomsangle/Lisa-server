<template>
  <div class="fund-flow-page">
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-green">
          <div class="stat-icon-wrap">
            <el-icon :size="28" class="stat-icon"><Wallet /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">本月充值</div>
            <div class="stat-value">¥ {{ formatMoney(stats.monthRecharge) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-red">
          <div class="stat-icon-wrap">
            <el-icon :size="28" class="stat-icon"><Coin /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">本月消费</div>
            <div class="stat-value">¥ {{ formatMoney(stats.monthSpend) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-orange">
          <div class="stat-icon-wrap">
            <el-icon :size="28" class="stat-icon"><Transfer /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">本月净划转（出-入）</div>
            <div class="stat-value">¥ {{ formatMoney(stats.monthTransferOut - stats.monthTransferIn) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card stat-blue">
          <div class="stat-icon-wrap">
            <el-icon :size="28" class="stat-icon"><Money /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">当前可用余额</div>
            <div class="stat-value">¥ {{ formatMoney(stats.mainBalance) }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" class="main-card" style="margin-top: 16px;">
      <el-tabs v-model="activeTab" @tab-change="onTabChange" class="flow-tabs">
        <el-tab-pane label="全部" name="all" />
        <el-tab-pane label="充值" name="recharge" />
        <el-tab-pane label="消费" name="spend" />
        <el-tab-pane label="划转出" name="transfer_out" />
        <el-tab-pane label="划转进" name="transfer_in" />
        <el-tab-pane label="退款" name="refund" />
        <el-tab-pane label="归集" name="collect" />
      </el-tabs>

      <div class="filter-bar">
        <div class="filter-left">
          <el-select v-model="filters.userId" placeholder="全部账号" clearable style="width: 200px;">
            <el-option label="全部账号" value="all" />
            <el-option
              v-for="acc in accounts"
              :key="acc.userId"
              :label="acc.name"
              :value="acc.userId"
            />
          </el-select>

          <el-date-picker
            v-model="filters.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 260px;"
          />

          <el-input
            v-model="filters.keyword"
            placeholder="流水号 / 备注 / 对手账号"
            clearable
            style="width: 260px;"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>

          <el-button type="primary" :icon="Search" @click="loadData">查询</el-button>
          <el-button plain :icon="Refresh" @click="resetFilters">重置</el-button>
        </div>

        <div class="filter-right">
          <el-button type="warning" :icon="Transfer" @click="goTransfer">
            去划转
          </el-button>
          <el-button type="success" plain :icon="Download" @click="exportCSV">
            导出 CSV
          </el-button>
        </div>
      </div>

      <el-table
        :data="tableData"
        v-loading="loading"
        border
        stripe
        style="width: 100%; margin-top: 16px;"
        class="flow-table"
      >
        <el-table-column prop="flowNo" label="流水号" width="200">
          <template #default="{ row }">
            <span class="mono small">{{ row.flowNo }}</span>
          </template>
        </el-table-column>

        <el-table-column prop="time" label="时间" width="170" />

        <el-table-column label="类型" width="110" align="center">
          <template #default="{ row }">
            <el-tag
              size="small"
              :type="getTypeTag(row.type).type"
              effect="light"
              :class="'type-tag type-' + row.type"
              round
            >
              <el-icon style="margin-right: 3px;">
                <ArrowUp v-if="row.type === 'recharge' || row.type === 'transfer_in' || row.type === 'refund'" />
                <ArrowDown v-else />
              </el-icon>
              {{ getTypeTag(row.type).text }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column label="收入金额(¥)" width="140" align="right">
          <template #default="{ row }">
            <span v-if="Number(row.amount) > 0" class="amount-income">
              + {{ formatMoney(row.amount) }}
            </span>
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>

        <el-table-column label="支出金额(¥)" width="140" align="right">
          <template #default="{ row }">
            <span v-if="Number(row.amount) < 0" class="amount-expense">
              - {{ formatMoney(Math.abs(Number(row.amount))) }}
            </span>
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>

        <el-table-column label="操作后余额" width="150" align="right">
          <template #default="{ row }">
            <b class="balance-val">¥ {{ formatMoney(row.balanceAfter) }}</b>
          </template>
        </el-table-column>

        <el-table-column label="关联账号" width="180">
          <template #default="{ row }">
            <span>{{ row.userId }}</span>
            <span v-if="row.counterparty && row.counterparty !== '-'" class="counterparty">
              <el-icon style="margin: 0 4px;"><DataLine /></el-icon>
              {{ row.counterparty }}
            </span>
          </template>
        </el-table-column>

        <el-table-column prop="operator" label="操作员" width="130" />

        <el-table-column prop="remark" label="备注" min-width="200">
          <template #default="{ row }">
            <span class="remark-text">{{ row.remark }}</span>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrap">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="pagination.total"
          background
          @current-change="loadData"
          @size-change="onSizeChange"
        />
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import {
  Wallet,
  Coin,
  Download,
  Search,
  Refresh,
  DataLine,
  Transfer,
  Money,
  ArrowUp,
  ArrowDown
} from '@element-plus/icons-vue'
import { getFundFlow, getWalletStats, listWalletAccounts } from '@/api/wallet'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const activeTab = ref('all')
const loading = ref(false)
const tableData = ref([])
const accounts = ref([])

const stats = reactive({
  mainBalance: 99979,
  monthRecharge: 3000,
  monthSpend: 516,
  monthTransferOut: 6000,
  monthTransferIn: 0,
  monthRefund: 0,
  subTotal: 0
})

const filters = reactive({
  userId: 'all',
  dateRange: [],
  keyword: ''
})

const pagination = reactive({
  page: 1,
  pageSize: 15,
  total: 0
})

const mainUserId = computed(() => {
  return userStore.userInfo?.userId || 'admin'
})

function formatMoney(val) {
  const num = Number(val) || 0
  return num.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function getTypeTag(type) {
  const map = {
    recharge: { text: '充值', type: 'success' },
    spend: { text: '消费', type: 'danger' },
    transfer_out: { text: '划转出', type: 'warning' },
    transfer_in: { text: '划转进', type: 'primary' },
    refund: { text: '退款', type: 'info' },
    collect: { text: '归集', type: '' }
  }
  return map[type] || { text: type, type: '' }
}

async function loadStats() {
  try {
    const res = await getWalletStats(mainUserId.value)
    if (res?.code === 0 && res.data) {
      Object.assign(stats, res.data)
    }
  } catch (e) {
    console.error('加载统计数据失败', e)
  }
}

async function loadAccounts() {
  try {
    const res = await listWalletAccounts(mainUserId.value)
    if (res?.code === 0 && res.data) {
      accounts.value = res.data
    }
  } catch (e) {
    console.error('加载账号列表失败', e)
  }
}

async function loadData() {
  loading.value = true
  try {
    const params = {
      mainUserId: mainUserId.value,
      page: pagination.page,
      pageSize: pagination.pageSize
    }
    if (filters.userId && filters.userId !== 'all') {
      params.userId = filters.userId
    }
    if (activeTab.value && activeTab.value !== 'all') {
      params.type = activeTab.value
    }
    if (filters.keyword) {
      params.keyword = filters.keyword
    }
    const res = await getFundFlow(params)
    if (res?.code === 0 && res.data) {
      tableData.value = res.data.list || []
      pagination.total = res.data.total || 0
    }
  } catch (e) {
    ElMessage.error('加载流水数据失败')
    console.error(e)
  } finally {
    loading.value = false
  }
}

function onTabChange() {
  pagination.page = 1
  loadData()
}

function onSizeChange() {
  pagination.page = 1
  loadData()
}

function resetFilters() {
  Object.assign(filters, {
    userId: 'all',
    dateRange: [],
    keyword: ''
  })
  activeTab.value = 'all'
  pagination.page = 1
  loadData()
}

function goTransfer() {
  router.push('/wallet/transfer')
}

function exportCSV() {
  if (!tableData.value.length) {
    ElMessage.warning('暂无可导出的数据')
    return
  }
  const headers = ['流水号', '时间', '类型', '收入金额(¥)', '支出金额(¥)', '操作后余额', '关联账号', '对手账号', '操作员', '备注']
  const rows = tableData.value.map(row => [
    row.flowNo,
    row.time,
    getTypeTag(row.type).text,
    Number(row.amount) > 0 ? formatMoney(row.amount) : '',
    Number(row.amount) < 0 ? formatMoney(Math.abs(Number(row.amount))) : '',
    formatMoney(row.balanceAfter),
    row.userId,
    row.counterparty === '-' ? '' : row.counterparty,
    row.operator,
    (row.remark || '').replace(/,/g, '，')
  ])
  const csv = '\uFEFF' + [headers, ...rows].map(r => r.join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `资金流水_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  ElMessage.success('导出成功')
}

onMounted(async () => {
  if (route.query.userId) {
    filters.userId = String(route.query.userId)
  }
  await Promise.all([loadStats(), loadAccounts()])
  loadData()
})
</script>

<style scoped>
.fund-flow-page {
  padding: 4px 2px 30px;
}

.stat-card {
  border-radius: 14px;
  overflow: hidden;
  border: none;
  transition: transform 0.25s ease, box-shadow 0.25s ease;
  position: relative;
}

.stat-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.1);
}

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 20px 20px;
}

.stat-green {
  background: linear-gradient(135deg, #d1fae5 0%, #6ee7b7 50%, #34d399 100%);
  color: #064e3b;
}

.stat-red {
  background: linear-gradient(135deg, #fee2e2 0%, #fca5a5 50%, #f87171 100%);
  color: #7f1d1d;
}

.stat-orange {
  background: linear-gradient(135deg, #ffedd5 0%, #fdba74 50%, #fb923c 100%);
  color: #7c2d12;
}

.stat-blue {
  background: linear-gradient(135deg, #dbeafe 0%, #93c5fd 50%, #60a5fa 100%);
  color: #1e3a8a;
}

.stat-icon-wrap {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.35);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  backdrop-filter: blur(8px);
}

.stat-icon {
  color: rgba(255, 255, 255, 0.95);
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
}

.stat-info {
  flex: 1;
  min-width: 0;
}

.stat-label {
  font-size: 13px;
  font-weight: 500;
  opacity: 0.85;
  margin-bottom: 6px;
}

.stat-value {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.3px;
  line-height: 1.1;
  color: inherit;
}

.main-card {
  border-radius: 14px;
}

.flow-tabs {
  margin-bottom: 4px;
}

.flow-tabs :deep(.el-tabs__header) {
  margin-bottom: 18px;
}

.flow-tabs :deep(.el-tabs__item) {
  font-size: 14px;
  font-weight: 600;
  padding: 0 20px;
  height: 40px;
  line-height: 40px;
}

.filter-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding: 16px 0 8px;
  border-top: 1px solid #f3f4f6;
}

.filter-left {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.filter-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.flow-table :deep(.el-table__row:hover) {
  background-color: #f0f9ff !important;
}

.flow-table :deep(.el-table__cell) {
  padding: 12px 10px;
}

.type-tag {
  font-weight: 600;
  padding: 4px 10px;
  display: inline-flex;
  align-items: center;
}

.type-tag.type-refund {
  background: linear-gradient(135deg, #f3e8ff, #ede9fe) !important;
  color: #7c3aed !important;
  border-color: #ddd6fe !important;
}

.type-tag.type-collect {
  background: linear-gradient(135deg, #fef9c3, #fef3c7) !important;
  color: #a16207 !important;
  border-color: #fde68a !important;
}

.amount-income {
  color: #059669;
  font-weight: 700;
}

.amount-expense {
  color: #dc2626;
  font-weight: 700;
}

.balance-val {
  color: #1f2937;
  font-size: 13px;
}

.counterparty {
  color: #6b7280;
  font-size: 12px;
  display: inline-flex;
  align-items: center;
}

.remark-text {
  color: #4b5563;
  font-size: 13px;
  line-height: 1.5;
}

.pagination-wrap {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}

.mono {
  font-family: Consolas, Monaco, monospace;
}

.small {
  font-size: 12px;
}

.muted {
  color: #9ca3af;
}
</style>
