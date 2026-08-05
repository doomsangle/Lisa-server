<template>
  <div class="isp-list">
    <div class="page-card">
      <div class="filter-bar">
        <el-form :inline="true" :model="filters" size="default">
          <el-form-item label="类型">
            <el-select v-model="filters.type" placeholder="全部" clearable style="width: 140px">
              <el-option label="静态住宅 ISP" value="ISP" />
              <el-option label="数据中心" value="DC" />
              <el-option label="移动 4G/5G" value="MOBILE" />
            </el-select>
          </el-form-item>
          <el-form-item label="国家/地区">
            <el-select v-model="filters.country" placeholder="全部" clearable filterable style="width: 160px">
              <el-option v-for="c in countries" :key="c.code" :label="`${c.flag} ${c.name}`" :value="c.code" />
            </el-select>
          </el-form-item>
          <el-form-item label="状态">
            <el-select v-model="filters.status" placeholder="全部" clearable style="width: 120px">
              <el-option label="运行中" value="active" />
              <el-option label="已过期" value="expired" />
              <el-option label="已暂停" value="paused" />
            </el-select>
          </el-form-item>
          <el-form-item label="关键字">
            <el-input v-model="filters.keyword" placeholder="IP / 备注" style="width: 180px" clearable />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" @click="loadData"><el-icon><Search /></el-icon> 查询</el-button>
            <el-button @click="resetFilters"><el-icon><Refresh /></el-icon> 重置</el-button>
          </el-form-item>
        </el-form>
      </div>

      <div class="flex-between action-bar">
        <div class="left-actions">
          <el-button type="primary" @click="openBuy"><el-icon><ShoppingCart /></el-icon> 购买新节点</el-button>
          <el-button :disabled="!selected.length" @click="batchRenew"><el-icon><RefreshRight /></el-icon> 批量续费</el-button>
          <el-button type="danger" :disabled="!selected.length" @click="batchDelete"><el-icon><Delete /></el-icon> 批量删除</el-button>
          <el-button :disabled="!selected.length" @click="exportList"><el-icon><Download /></el-icon> 导出</el-button>
        </div>
        <div class="summary muted small">
          共 <b>{{ pagination.total }}</b> 条 &nbsp;
          活跃：<b class="ok">{{ stats.active }}</b>
          过期：<b class="danger">{{ stats.expired }}</b>
        </div>
      </div>

      <el-table :data="list" v-loading="loading" border stripe @selection-change="e => selected = e">
        <el-table-column type="selection" width="50" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="country" label="地区" width="110">
          <template #default="{ row }">
            <span>{{ row.countryFlag }} {{ row.country }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="row.type==='ISP'?'success':(row.type==='DC'?'info':'warning')">{{ row.type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="protocol" label="协议" width="90" />
        <el-table-column label="连接信息">
          <template #default="{ row }">
            <div class="conn-info">
              <span class="mono">{{ row.ip || '—' }}:{{ row.port || '—' }}</span>
              <el-button v-if="row.ip" link size="small" type="primary" @click="copyConn(row)">复制</el-button>
              <el-button link size="small" @click="showDetail(row)">详情</el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="auth" label="账号/密码" width="180">
          <template #default="{ row }">
            <span v-if="row.username" class="mono small muted">{{ row.username }} / *****</span>
            <span v-else class="muted small">部署中…</span>
          </template>
        </el-table-column>
        <el-table-column label="入口 / 交付" width="300">
          <template #default="{ row }">
            <div class="entry-col">
              <div v-if="row.entryUrl || row.vpnUrl" class="entry-url-row">
                <el-icon :size="14" color="#67c23a"><Link /></el-icon>
                <a :href="row.entryUrl || row.vpnUrl" target="_blank" class="link mono small entry-link">{{ row.entryUrl || row.vpnUrl }}</a>
              </div>
              <div v-else class="muted small">初始化中，入口链接待生成</div>
              <div class="entry-actions">
                <el-popover v-if="row.qrCode || row.vpnQrCode" placement="top" :width="220" trigger="click">
                  <template #reference>
                    <el-button link size="small" type="success">
                      <el-icon><PictureFilled /></el-icon> 入口二维码
                    </el-button>
                  </template>
                  <div style="text-align:center">
                    <div class="qr-placeholder">
                      <img v-if="(row.qrCode || row.vpnQrCode) && String(row.qrCode || row.vpnQrCode).startsWith('http')" :src="row.qrCode || row.vpnQrCode" style="width:160px;height:160px" />
                      <div v-else class="qr-tip">
                        <el-icon :size="88" color="#2c7be5"><PictureFilled /></el-icon>
                        <div class="small muted mt-4">手机扫码访问入口面板</div>
                      </div>
                      <div class="mt-8 small muted mono">{{ row.qrCode || row.vpnQrCode }}</div>
                    </div>
                  </div>
                </el-popover>
                <el-tag v-if="!(row.qrCode || row.vpnQrCode)" size="small" type="info" effect="plain">二维码生成中</el-tag>
                <el-button v-if="row.configContent || row.vpnConfigContent" link size="small" type="primary" @click="downloadConfig(row)">
                  <el-icon><Download /></el-icon> 下载配置
                </el-button>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="trafficUsed" label="流量" width="140">
          <template #default="{ row }">
            <el-progress v-if="row.trafficTotal" :percentage="Math.round(row.trafficUsed / row.trafficTotal * 100)"
              :stroke-width="6" :color="progressColor(row)">
              <span class="small">{{ formatGB(row.trafficUsed) }} / {{ formatGB(row.trafficTotal) }}</span>
            </el-progress>
            <span v-else class="muted small">—</span>
          </template>
        </el-table-column>
        <el-table-column prop="expireAt" label="到期日" width="110">
          <template #default="{ row }">
            <span :class="{ danger: isExpireSoon(row.expireAt) }">{{ row.expireAt || '—' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="80" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status==='active'?'success':(row.status==='expired'?'danger':'info')" effect="light">
              {{ row.status==='active' ? '运行中' : row.status==='expired' ? '已过期' : (row.status==='paused'?'已暂停':row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" @click="renew(row)"><el-icon><RefreshRight /></el-icon> 续费</el-button>
            <el-button v-if="row.status && (row.entryUrl || row.vpnUrl)" link size="small" type="warning" @click="redeploy(row)">重新部署</el-button>
            <el-button link size="small" type="primary" @click="togglePause(row)">
              {{ row.status === 'paused' ? '启用' : '暂停' }}
            </el-button>
            <el-button link size="small" type="danger" @click="remove(row)"><el-icon><Delete /></el-icon></el-button>
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
          @current-change="loadData"
        />
      </div>
    </div>
  </div>
</template>
<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh, ShoppingCart, RefreshRight, Delete, Download, Link, PictureFilled } from '@element-plus/icons-vue'
import { getProxyList, deleteProxy, updateProxy, batchAction, getCountryTree, redeployProxy } from '@/api/proxies'

const route = useRoute()
const router = useRouter()

const countries = ref([
  { code: 'US', name: '美国', flag: '🇺🇸' },
  { code: 'JP', name: '日本', flag: '🇯🇵' },
  { code: 'DE', name: '德国', flag: '🇩🇪' },
  { code: 'GB', name: '英国', flag: '🇬🇧' },
  { code: 'FR', name: '法国', flag: '🇫🇷' },
  { code: 'KR', name: '韩国', flag: '🇰🇷' },
  { code: 'SG', name: '新加坡', flag: '🇸🇬' },
  { code: 'CA', name: '加拿大', flag: '🇨🇦' },
  { code: 'AU', name: '澳大利亚', flag: '🇦🇺' },
  { code: 'BR', name: '巴西', flag: '🇧🇷' }
])

const currentType = computed(() => route.meta?.type || 'ISP')

const filters = reactive({
  type: '',
  country: '',
  status: '',
  keyword: ''
})
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })
const list = ref([])
const selected = ref([])
const loading = ref(false)
const stats = reactive({ active: 0, expired: 0 })

async function loadCountryTree() {
  try {
    const tree = await getCountryTree()
    if (tree && tree.length) {
      const flat = []
      tree.forEach((g) => g.items?.forEach((c) => flat.push({ code: c.code, name: c.name, flag: c.flag })))
      if (flat.length) countries.value = flat
    }
  } catch (e) {}
}

function progressColor(row) {
  const p = row.trafficUsed / row.trafficTotal
  if (p > 0.9) return '#f56c6c'
  if (p > 0.7) return '#e6a23c'
  return '#67c23a'
}
function formatGB(v) {
  return v < 1024 ? `${v} MB` : `${(v / 1024).toFixed(2)} GB`
}
function isExpireSoon(d) {
  if (!d) return false
  const diff = (new Date(d).getTime() - Date.now()) / 86400000
  return diff < 7
}
function resetFilters() {
  Object.assign(filters, { type: '', country: '', status: '', keyword: '' })
  pagination.page = 1
  loadData()
}
async function loadData() {
  loading.value = true
  try {
    const params = {
      page: pagination.page,
      pageSize: pagination.pageSize,
    }
    const t = filters.type || currentType.value
    if (t !== 'ISP' || filters.type) params.type = filters.type || t
    if (filters.country) params.country = filters.country
    if (filters.status) params.status = filters.status
    if (filters.keyword) params.keyword = filters.keyword

    const res = await getProxyList(params)
    list.value = res?.data?.list || res?.list || []
    pagination.total = res?.data?.total || res?.total || 0
    stats.active = list.value.filter(r => r.status === 'active').length
    stats.expired = list.value.filter(r => r.status === 'expired').length
  } catch (e) {
    ElMessage.error(e.message || '加载失败')
  } finally {
    loading.value = false
  }
}

function openBuy() { router.push('/servers/buy') }
function copyConn(row) {
  const proto = (row.protocol || 'HTTP').split(',')[0].toLowerCase()
  const text = `${proto}://${row.username}:${row.password}@${row.ip}:${row.port}`
  navigator.clipboard.writeText(text)
  ElMessage.success('已复制节点接入信息')
}
function showDetail(row) {
  ElMessageBox.alert(
    `<div style="line-height:2"><b>ID:</b> ${row.id}<br><b>地区:</b> ${row.countryFlag || ''} ${row.country}<br><b>IP:</b> ${row.ip}<br><b>端口:</b> ${row.port}<br><b>协议:</b> ${row.protocol}<br><b>账号:</b> ${row.username}<br><b>密码:</b> ${row.password}<br><b>到期:</b> ${row.expireAt}</div>`,
    `节点 #${row.id} 详情`, { dangerouslyUseHTMLString: true, confirmButtonText: '关闭' }
  )
}
function renew(row) {
  ElMessageBox.prompt(`续费节点 #${row.id} (${row.countryFlag || ''} ${row.country})`, '选择套餐', {
    inputType: 'select',
    inputValue: '1m',
    inputPattern: null,
    inputValidator: () => true,
    inputOptions: [
      { value: '1m', label: '1 个月 - ¥89' },
      { value: '3m', label: '3 个月 - ¥249 (93折)' },
      { value: '1y', label: '1 年 - ¥899 (84折)' }
    ]
  }).then(() => {
    batchAction('renew', { ids: [row.id] })
    ElMessage.success('续费订单已提交，请前往支付')
  }).catch(() => {})
}
function batchRenew() {
  if (!selected.value.length) return
  batchAction('renew', { ids: selected.value.map(s => s.id) })
  ElMessage.success(`已为 ${selected.value.length} 个节点提交续费订单`)
}
async function batchDelete() {
  if (!selected.value.length) return
  ElMessageBox.confirm(`确认删除选中的 ${selected.value.length} 个节点？此操作不可恢复。`, '警告', { type: 'warning' })
    .then(async () => {
      try {
        await batchAction('delete', { ids: selected.value.map(s => s.id) })
        ElMessage.success('已删除')
        loadData()
      } catch (e) {}
    }).catch(() => {})
}
async function remove(row) {
  ElMessageBox.confirm(`删除节点 #${row.id}？`, '提示', { type: 'warning' })
    .then(async () => {
      try {
        await deleteProxy(row.id)
        ElMessage.success('已删除')
        loadData()
      } catch (e) {}
    }).catch(() => {})
}
async function togglePause(row) {
  const action = row.status === 'paused' ? 'resume' : 'pause'
  try {
    await batchAction(action, { ids: [row.id] })
    row.status = action === 'resume' ? 'active' : 'paused'
    ElMessage.success(row.status === 'paused' ? '已暂停' : '已启用')
  } catch (e) {}
}
function exportList() { ElMessage.success(`已导出 ${selected.value.length || list.value.length} 条记录`) }
async function redeploy(row) {
  ElMessageBox.confirm(`确认重新初始化节点 #${row.id}？将保留服务器并重新配置接入环境`, '提示', { type: 'warning' })
    .then(async () => {
      try {
        await redeployProxy(row.id)
        ElMessage.success('重部署任务已启动，约30-60秒完成，页面将自动刷新')
        setTimeout(loadData, 4000)
      } catch (e) {}
    }).catch(() => {})
}
function downloadConfig(row) {
  const content = row.configContent || row.vpnConfigContent
  if (!content) {
    ElMessage.warning('配置尚未生成，请稍候...')
    return
  }
  const blob = new Blob([content], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = ((row.configPath || row.vpnConfigPath || `access-${row.id}.conf`).split('/').pop()) || `access-${row.id}.conf`
  a.click()
  URL.revokeObjectURL(url)
  ElMessage.success('配置文件已下载')
}

watch(() => route.path, () => {
  filters.type = ''
  pagination.page = 1
  loadData()
})
onMounted(async () => {
  await loadCountryTree()
  loadData()
})
</script>
<style scoped>
.isp-list { }
.filter-bar { border-bottom: 1px solid #f0f0f0; padding-bottom: 12px; margin-bottom: 16px; }
.action-bar { margin-bottom: 14px; }
.left-actions { display: flex; gap: 8px; }
.conn-info { display: flex; align-items: center; gap: 4px; }
.mono { font-family: Consolas, Monaco, monospace; color: #374151; }
.danger { color: #f56c6c; }
.ok { color: #67c23a; }
.small { font-size: 12px; }
.muted { color: #6b7280; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
.entry-col { line-height: 1.8; }
.entry-url-row { display: flex; align-items: center; gap: 4px; margin-bottom: 2px; }
.entry-link { max-width: 220px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; vertical-align: top; }
.entry-actions { display: flex; gap: 4px; align-items: center; flex-wrap: wrap; }
.qr-placeholder {
  width: 170px; height: 170px; border: 1px dashed #c0c4cc; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  background: #fafafa; flex-direction: column;
}
.mt-4 { margin-top: 4px; }
.mt-8 { margin-top: 8px; }
</style>
