<template>
  <div class="servers-page">
    <div class="page-card">
      <div class="filter-bar">
      <el-form :inline="true" :model="filters" size="default">
        <el-form-item label="关键字">
          <el-input v-model="filters.keyword" placeholder="IP/订单号/区域" clearable style="width: 220px" />
        </el-form-item>
        <el-form-item label="区域">
          <el-select v-model="filters.region" placeholder="全部" clearable filterable style="width: 150px">
            <el-option v-for="c in countries" :key="c.code" :label="`${c.flag} ${c.name}`" :value="c.code" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filters.status" placeholder="全部" clearable style="width: 130px">
            <el-option label="运行中" value="active" />
            <el-option label="初始化" value="provisioning" />
            <el-option label="关机" value="stopped" />
            <el-option label="异常" value="error" />
            <el-option label="已过期" value="expired" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="loadData"><el-icon><Search /></el-icon> 查询</el-button>
          <el-button @click="resetFilters"><el-icon><Refresh /></el-icon> 重置</el-button>
          <el-button type="success" @click="$router.push('/servers/buy')"><el-icon><Plus /></el-icon> 购买新服务器</el-button>
        </el-form-item>
      </el-form>
      </div>
      <div class="flex-between stat-row muted small">
        <div>共 <b>{{ pagination.total }}</b> 台 &nbsp;
          运行中 <b class="ok">{{ stats.active }}</b> ·
          初始化 <b class="warn">{{ stats.provisioning }}</b> ·
          已关机 <b>{{ stats.stopped }}</b> ·
          异常 <b class="danger">{{ stats.error }}</b>
        </div>
        <div>总配置：<b>{{ stats.totalCpu }}</b> 核 / <b>{{ stats.totalRam }}</b> GB / <b>{{ stats.totalBw }}</b> Mbps</div>
      </div>
      <el-table :data="list" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column label="配置 / 用途" min-width="180">
          <template #default="{ row }">
            <div class="conf-line">
              <el-tag size="small" :type="usageTag(row.usage).type">{{ usageTag(row.usage).name }}</el-tag>
              <el-tag size="small" type="info" effect="plain">{{ row.region }}</el-tag>
            </div>
            <div class="spec-line mt-4">
              <el-tooltip content="CPU 核数"><el-icon><Cpu /></el-icon> {{ row.cpuCores }}核</el-tooltip>
              <el-tooltip content="内存"><el-icon><Coin /></el-icon> {{ (row.ramMb/1024).toFixed(0) }}GB</el-tooltip>
              <el-tooltip content="磁盘"><el-icon><Folder /></el-icon> {{ row.diskGb }}G</el-tooltip>
            </div>
            <div class="muted small mt-4">{{ row.os }} · {{ row.bandwidthMbps }} Mbps · {{ row.spec }}</div>
          </template>
        </el-table-column>
        <el-table-column label="IP / 区域" width="210">
          <template #default="{ row }">
            <div>
              <el-tag size="small" type="info" effect="plain">{{ row.provider }}</el-tag>
              <span class="ml-4">{{ countryFlag(row.region) }} {{ countryName(row.region) }}</span>
            </div>
            <div class="mono mt-4">{{ row.ip }}:{{ row.sshPort }}</div>
            <div v-if="row.ipv6" class="mono muted small">IPv6: {{ row.ipv6 }}</div>
          </template>
        </el-table-column>
        <el-table-column label="登录账号" width="180">
          <template #default="{ row }">
            <div class="mono small">{{ row.sshUser }} / ********</div>
            <div class="mt-4">
              <el-button link size="small" type="primary" @click="copyLogin(row)">复制登录</el-button>
              <el-button link size="small" type="success" @click="showPwd(row)">查看密码</el-button>
            </div>
            <el-button link size="small" type="warning" @click="showEntry(row)">入口面板</el-button>
          </template>
        </el-table-column>
        <el-table-column label="交付 / 远程入口" min-width="220">
          <template #default="{ row }">
            <div v-if="row.entryUrl" class="url-row">
              <el-icon :size="14" color="#67c23a"><Link /></el-icon>
              <a :href="row.entryUrl" target="_blank" class="link mono small">{{ row.entryUrl }}</a>
            </div>
            <div v-else class="muted small">初始化中，入口链接待生成</div>
            <div class="entry-actions mt-4">
              <el-popover v-if="row.qrCode" placement="top" :width="230" trigger="click">
                <template #reference>
                  <el-button link size="small" type="success"><el-icon><PictureFilled /></el-icon> 入口二维码</el-button>
                </template>
                <div style="text-align:center">
                  <div class="qr-box">
                    <div class="qr-inner">
                      <el-icon :size="96" color="#1f6feb"><PictureFilled /></el-icon>
                      <div class="small muted mt-4">手机扫码访问入口</div>
                    </div>
                  </div>
                  <div class="mt-8 small muted mono">{{ row.qrCode }}</div>
                </div>
              </el-popover>
              <el-tag v-if="!row.qrCode" size="small" type="info" effect="plain">二维码生成中</el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="月租 / 到期" width="150" align="center">
          <template #default="{ row }">
            <div>¥{{ (row.priceMonth || 0).toFixed(2) }} / 月</div>
            <div class="muted small mt-4" :class="{danger: isExpireSoon(row.expireAt)}">到期: {{ row.expireAt || '—' }}</div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTag(row.status).type" effect="light">
              {{ statusTag(row.status).name }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" @click="openConsole(row)">控制台</el-button>
            <el-button link size="small" type="warning" @click="reboot(row)">重启</el-button>
            <el-button link size="small" type="primary" @click="reinstall(row)">重装</el-button>
            <el-button link size="small" type="success" @click="renew(row)">续费</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pagination-wrap">
        <el-pagination v-model:current-page="pagination.page" v-model:page-size="pagination.pageSize"
          :page-sizes="[10,20,50,100]" layout="total, sizes, prev, pager, next, jumper"
          :total="pagination.total" @current-change="loadData" />
      </div>
    </div>
  </div>
</template>
<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search, Refresh, Plus, Cpu, Coin, Folder, Link, PictureFilled } from '@element-plus/icons-vue'
import { listServers, rebootServer, reinstallServer } from '@/api/servers'
import { getCountryTree } from '@/api/proxies'

const countries = ref([
  { code:'US', name:'美国', flag:'🇺🇸' }, { code:'JP', name:'日本', flag:'🇯🇵' },
  { code:'DE', name:'德国', flag:'🇩🇪' }, { code:'GB', name:'英国', flag:'🇬🇧' },
  { code:'SG', name:'新加坡', flag:'🇸🇬' }, { code:'KR', name:'韩国', flag:'🇰🇷' },
  { code:'HK', name:'香港', flag:'🇭🇰' }, { code:'FR', name:'法国', flag:'🇫🇷' },
])

function countryFlag(region) {
  const c = countries.value.find((x) => (region||'').toLowerCase().includes(x.code.toLowerCase()))
  return c ? c.flag : '🌐'
}
function countryName(region) {
  const c = countries.value.find((x) => (region||'').toLowerCase().includes(x.code.toLowerCase()))
  return c ? c.name : (region || '未知')
}
function usageTag(u) {
  const m = {
    web:  { name:'网站托管', type:'' },
    ecom: { name:'跨境电商', type:'warning' },
    office:{name:'企业办公', type:'success' },
    dev:  { name:'开发测试', type:'info' },
    data: { name:'数据运算', type:'' },
    game: { name:'游戏应用', type:'danger' },
  }
  return m[u] || { name: u || '通用', type: 'info' }
}
function statusTag(s) {
  if (s === 'active') return { name: '运行中', type: 'success' }
  if (s === 'provisioning' || s === 'deploying') return { name: '初始化', type: 'warning' }
  if (s === 'stopped') return { name: '关机', type: 'info' }
  if (s === 'error') return { name: '异常', type: 'danger' }
  if (s === 'expired') return { name: '已过期', type: 'danger' }
  return { name: s || '未知', type: 'info' }
}
function isExpireSoon(d) {
  if (!d) return false
  return (new Date(d).getTime() - Date.now()) / 86400000 < 7
}

const filters = reactive({ keyword: '', status: '', region: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })
const list = ref([])
const loading = ref(false)
const stats = reactive({ active: 0, provisioning: 0, stopped: 0, error: 0, totalCpu: 0, totalRam: 0, totalBw: 0 })

async function loadCountries() {
  try {
    const tree = await getCountryTree()
    if (tree && tree.length) {
      const flat = []
      tree.forEach((g) => g.items?.forEach((c) => flat.push({ code: c.code, name: c.name, flag: c.flag })))
      if (flat.length) countries.value = flat
    }
  } catch (e) {}
}

async function loadData() {
  loading.value = true
  try {
    const params = { page: pagination.page, pageSize: pagination.pageSize }
    if (filters.keyword) params.keyword = filters.keyword
    if (filters.status) params.status = filters.status
    if (filters.region) params.region = filters.region
    const res = await listServers(params)
    const rows = res?.data?.list || res?.list || []
    list.value = rows.map((r) => ({
      ...r,
      entryUrl: r.entryUrl || r.vpnUrl || '',
      qrCode: r.qrCode || r.vpnQrCode || '',
      usage: r.usage || r.category || 'ecom',
    }))
    pagination.total = res?.data?.total || res?.total || 0
    stats.active = rows.filter(r => r.status === 'active').length
    stats.provisioning = rows.filter(r => ['provisioning','deploying'].includes(r.status)).length
    stats.stopped = rows.filter(r => r.status === 'stopped').length
    stats.error = rows.filter(r => r.status === 'error').length
    stats.totalCpu = rows.reduce((s, r) => s + (r.cpuCores || 0), 0)
    stats.totalRam = rows.reduce((s, r) => s + ((r.ramMb||0)/1024), 0).toFixed(0)
    stats.totalBw = rows.reduce((s, r) => s + (r.bandwidthMbps || 0), 0)
  } finally { loading.value = false }
}
function resetFilters() {
  Object.assign(filters, { keyword: '', status: '', region: '' })
  pagination.page = 1
  loadData()
}
function copyLogin(row) {
  const cmd = row.os?.toLowerCase().includes('windows')
    ? `mstsc /v:${row.ip}:${row.sshPort}`
    : `ssh ${row.sshUser}@${row.ip} -p ${row.sshPort}`
  navigator.clipboard.writeText(cmd)
  ElMessage.success(row.os?.toLowerCase().includes('windows') ? 'RDP连接命令已复制' : 'SSH命令已复制')
}
function showPwd(row) {
  ElMessageBox.alert(
    `<div style="line-height:2">
      <div>登录账号：<b class="mono">${row.sshUser}</b></div>
      <div>登录密码：<b class="mono">${row.sshPassword || '********'}</b></div>
      <div>IP 地址：<b class="mono">${row.ip}:${row.sshPort}</b></div>
      <div class="muted small mt-4">请勿在公共场合展示或分享您的登录凭据</div>
    </div>`,
    `云服务器 #${row.id} 登录凭据`,
    { dangerouslyUseHTMLString: true, confirmButtonText: '我已保存' }
  )
}
function showEntry(row) {
  if (!row.entryUrl) { ElMessage.warning('入口尚未生成，请稍候或联系客服'); return }
  window.open(row.entryUrl, '_blank')
}
function openConsole(row) { ElMessage.success(`Web 控制台即将打开：${row.ip}`) }
async function reboot(row) {
  ElMessageBox.confirm(`确认重启服务器 ${row.ip}？期间服务将短暂中断。`, '提示', { type: 'warning' })
    .then(async () => { try { await rebootServer(row.id); ElMessage.success('已发送重启命令') } catch(e){} })
    .catch(()=>{})
}
async function reinstall(row) {
  ElMessageBox.confirm(`确认重装服务器 ${row.ip}？所有数据将丢失且无法恢复！`, '警告', { type: 'warning' })
    .then(async () => { try { await reinstallServer(row.id); ElMessage.success('重装任务已开始，约 3-5 分钟完成') } catch(e){} })
    .catch(()=>{})
}
function renew(row) {
  ElMessageBox.prompt(`为服务器 #${row.id} (${row.ip}) 选择续费周期`, '续费', {
    inputType: 'select', inputValue: '1m',
    inputOptions: [
      { value: '1m', label: '1 个月 - ¥' + (row.priceMonth||0).toFixed(2) },
      { value: '3m', label: '3 个月 - 93折' },
      { value: '6m', label: '6 个月 - 88折' },
      { value: '1y', label: '1 年 - 84折+送1月' },
    ],
  }).then(() => ElMessage.success('续费订单已创建，请前往订单中心支付')).catch(()=>{})
}

onMounted(async () => { await loadCountries(); loadData() })
</script>
<style scoped>
.filter-bar { border-bottom:1px solid #f0f0f0; padding-bottom:12px; margin-bottom:12px }
.stat-row { padding: 8px 4px; margin-bottom: 12px; }
.mono { font-family: Consolas, Monaco, monospace; }
.small { font-size: 12px; }
.muted { color: #6b7280; }
.ok { color: #67c23a; } .warn { color: #e6a23c; } .danger { color: #f56c6c; }
.mt-4 { margin-top: 4px; } .ml-4 { margin-left: 8px; } .mt-8 { margin-top: 8px; }
.conf-line, .spec-line { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.url-row { display: flex; align-items: center; gap: 4px; }
.link { color: #409eff; max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; }
.entry-actions { display: flex; gap: 4px; flex-wrap: wrap; align-items: center; }
.qr-box {
  width: 190px; height: 190px; border: 1px dashed #c0c4cc; border-radius: 10px;
  background: #fafafa; display: flex; align-items: center; justify-content: center;
}
.qr-inner { display: flex; flex-direction: column; align-items: center; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }
</style>
