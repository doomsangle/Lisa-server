<template>
  <div class="orders-page">
    <div class="page-card">
      <div class="filter-bar">
        <el-form :inline="true" :model="filters" size="default">
          <el-form-item label="订单号">
            <el-input v-model="filters.keyword" placeholder="订单号/产品" clearable style="width: 220px" />
          </el-form-item>
          <el-form-item label="状态">
            <el-select v-model="filters.status" placeholder="全部" clearable style="width: 130px">
              <el-option label="待支付" value="pending" />
              <el-option label="已支付" value="paid" />
              <el-option label="已完成" value="completed" />
              <el-option label="已取消" value="canceled" />
              <el-option label="已退款" value="refunded" />
            </el-select>
          </el-form-item>
          <el-form-item label="部署">
            <el-select v-model="filters.deploy" placeholder="全部" clearable style="width: 130px">
              <el-option label="待部署" value="pending" />
              <el-option label="部署中" value="running" />
              <el-option label="部署成功" value="done" />
              <el-option label="部署失败" value="failed" />
            </el-select>
          </el-form-item>
          <el-form-item>
            <el-button type="primary" @click="loadData"><el-icon><Search /></el-icon> 查询</el-button>
            <el-button @click="resetFilters"><el-icon><Refresh /></el-icon> 重置</el-button>
          </el-form-item>
        </el-form>
      </div>

      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="orderNo" label="订单号" width="190">
          <template #default="{ row }">
            <span class="mono small">{{ row.orderNo }}</span>
            <el-button link size="small" type="primary" @click="goDetail(row)">详情</el-button>
          </template>
        </el-table-column>
        <el-table-column label="产品">
          <template #default="{ row }">
            <div>
            {{ row.countryFlag }} {{ row.product }}</div>
            <div class="muted small">数量：{{ row.qty }} IP · {{ row.period }}</div>
          </template>
        </el-table-column>
        <el-table-column label="金额" width="110">
          <template #default="{ row }"><b>¥ {{ row.total }}</b></template>
        </el-table-column>
        <el-table-column label="支付方式" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.payMethod" size="small">{{ row.payMethod }}</el-tag>
            <span v-else class="muted small">—</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTag(row.status).type" effect="light">{{ statusTag(row.status).text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="部署状态" width="110" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.deployStatus" size="small" :type="deployTag(row.deployStatus).type">
              {{ deployTag(row.deployStatus).text }}
            </el-tag>
            <span v-else class="muted small">—</span>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="160" />
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" type="primary" @click="goDetail(row)">查看</el-button>
            <el-button v-if="row.status==='pending'" link size="small" type="warning" @click="goPay(row)">去支付</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination-wrap">
        <el-pagination v-model:current-page="pagination.page" v-model:page-size="pagination.pageSize"
          :page-sizes="[10, 20, 50]" layout="total, sizes, prev, pager, next, jumper"
          :total="pagination.total" @current-change="loadData" />
      </div>
    </div>
  </div>
</template>
<script setup>
import { reactive, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Search, Refresh } from '@element-plus/icons-vue'
import { getOrderList } from '@/api/order'
const router = useRouter()
const filters = reactive({ keyword: '', status: '', deploy: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })
const list = ref([])
const loading = ref(false)

function statusTag(s) {
  return {
    pending: { text: '待支付', type: 'warning' },
    paid: { text: '已支付', type: 'info' },
    completed: { text: '已完成', type: 'success' },
    canceled: { text: '已取消', type: 'info' },
    refunded: { text: '已退款', type: 'danger' },
  }[s] || { text: s, type: '' }
}
function deployTag(s) {
  return {
    pending: { text: '待部署', type: 'info' },
    running: { text: '部署中', type: 'warning' },
    done: { text: '部署完成', type: 'success' },
    failed: { text: '部署失败', type: 'danger' },
  }[s] || { text: s, type: '' }
}
async function loadData() {
  loading.value = true
  try {
    const params = { page: pagination.page, pageSize: pagination.pageSize, keyword: filters.keyword }
    if (filters.status) params.status = filters.status
    if (filters.deploy) params.deploy_status = filters.deploy
    const res = await getOrderList(params)
    list.value = res?.data?.list || res?.list || []
    pagination.total = res?.data?.total || res?.total || 0
  } finally { loading.value = false }
}
function resetFilters() {
  Object.assign(filters, { keyword: '', status: '', deploy: '' })
  pagination.page = 1; loadData()
}
function goDetail(row) { router.push(`/orders/${row.orderNo}`) }
function goPay(row) { router.push(`/orders/${row.orderNo}?pay=1`) }
onMounted(loadData)
</script>
<style scoped>
.filter-bar { border-bottom: 1px solid #f0f0f0; padding-bottom: 12px; margin-bottom: 16px; }
.mono { font-family: Consolas, Monaco, monospace; }
.small { font-size: 12px; }
.muted { color: #6b7280; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
</style>
