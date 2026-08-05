<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="5"><el-card shadow="hover" class="stat-card ok">
        <div class="lbl muted small">今日操作总数</div>
        <div class="val">{{ summary.today }}</div>
        <div class="ft">审计模块已接入实时数据库</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card warn">
        <div class="lbl muted small">7 日高危操作</div>
        <div class="val">{{ summary.high7d }}</div>
        <div class="ft">删除资源 / 改权限 / 改密 / 退款</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card danger">
        <div class="lbl muted small">7 日失败操作</div>
        <div class="val">{{ summary.fail7d }}</div>
        <div class="ft">密码错误 / 鉴权失败 / 下发失败</div>
      </el-card></el-col>
      <el-col :span="9">
        <el-card shadow="hover" class="stat-card legend">
          <div class="l-row">
            <div v-for="(l, i) in levels" :key="i" class="l-item">
              <span class="d" :style="{ background: l.color }"></span>
              <span class="t">{{ l.name }}</span>
              <b class="n">{{ l.count }}</b>
            </div>
          </div>
          <div v-if="!isSuperAdmin" class="tip muted small" style="margin-top: 10px;">
            ℹ️ 普通账户仅展示您本人的审计日志。如需全平台审计追溯，请使用超管账号 + "全平台数据"开关。
          </div>
          <div v-else class="tip muted small" style="margin-top: 10px;">
            🔒 审计数据不可删除，180 天内支持监管追溯（《服务条款》第 2.3 条 / 《隐私政策》第 3.2 条）
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <b>敏感操作全链路审计 · 保留 180 天</b>
          <div class="btns">
            <el-date-picker v-model="range" type="datetimerange" start-placeholder="起始时间" end-placeholder="结束时间" size="default" range-separator="至" style="width: 360px;" />
            <el-select v-model="filter.level" size="default" placeholder="风险等级" clearable style="width: 130px;">
              <el-option label="高危" value="high" />
              <el-option label="中危" value="mid" />
              <el-option label="低危" value="low" />
            </el-select>
            <el-select v-model="filter.type" size="default" placeholder="操作类型" clearable style="width: 200px;" filterable>
              <el-option v-for="t in opTypes" :key="t.k" :label="`${t.icon || '📒'} ${t.name} · ${t.k}`" :value="t.k" />
            </el-select>
            <el-input v-model="kw" size="default" placeholder="搜索操作人 / IP / 单号 / 摘要" clearable style="width: 240px;">
              <template #prefix><el-icon><Search /></el-icon></template>
            </el-input>
            <el-switch v-if="isSuperAdmin" v-model="showAll" style="margin-left: 4px;" active-text="全平台数据" inactive-text="仅我的" />
            <el-button type="primary" :icon="Search" @click="loadLogs(1)">查询</el-button>
            <el-button :icon="Refresh" plain @click="resetFilter">重置</el-button>
            <el-button type="success" plain :icon="Download" @click="exportCsv">导出 CSV</el-button>
          </div>
        </div>
      </template>

      <el-table :data="logs" stripe style="width: 100%;" v-loading="loading">
        <el-table-column label="时间" width="170">
          <template #default="{ row }">{{ row.created_at }}</template>
        </el-table-column>
        <el-table-column label="风险等级" width="100" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.level==='high'" type="danger" effect="dark" round>高危</el-tag>
            <el-tag v-else-if="row.level==='mid'" type="warning" effect="light" round>中危</el-tag>
            <el-tag v-else type="info" effect="plain" round>低危</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作类型" width="180">
          <template #default="{ row }">
            <div class="op-cell">
              <el-icon><component :is="opTypesMap[row.action]?.icon || 'Notebook'" /></el-icon>
              <span>{{ opTypesMap[row.action]?.name || row.action }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作人" width="110">
          <template #default="{ row }"><b>{{ row.username || ('user#' + row.user_id) }}</b></template>
        </el-table-column>
        <el-table-column label="来源 IP" width="150">
          <template #default="{ row }">
            <span class="mono">{{ row.ip || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="资源" width="130">
          <template #default="{ row }">
            <span v-if="row.resource_type">{{ row.resource_type }} #{{ row.resource_id || '-' }}</span>
            <span v-else class="muted">—</span>
          </template>
        </el-table-column>
        <el-table-column label="UA" min-width="180">
          <template #default="{ row }">
            <div class="muted small ua" :title="row.user_agent">{{ (row.user_agent || '').slice(0, 60) }}{{ (row.user_agent || '').length > 60 ? '…' : '' }}</div>
          </template>
        </el-table-column>
        <el-table-column label="操作详情" min-width="260">
          <template #default="{ row }">
            <el-popover placement="top" width="560" trigger="hover">
              <template #reference>
                <span class="detail-cell">{{ row.summary || '（无摘要）' }}</span>
              </template>
              <div style="font-size: 12px; line-height: 1.7;">
                <div v-if="row.old_json"><b>旧值：</b><pre class="json-box">{{ row.old_json }}</pre></div>
                <div v-if="row.new_json"><b>新值：</b><pre class="json-box">{{ row.new_json }}</pre></div>
                <div class="muted" v-if="!row.old_json && !row.new_json">该操作未记录差异字段（通常为一次性动作或失败时）</div>
              </div>
            </el-popover>
          </template>
        </el-table-column>
        <el-table-column label="结果" width="90" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.ok" type="success" effect="light" round>成功</el-tag>
            <el-tag v-else type="danger" effect="light" round>失败</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="110" align="right" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="viewDetail(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          :page-sizes="[20, 50, 100, 200]"
          v-model:current-page="page"
          v-model:page-size="pageSize"
          @size-change="loadLogs(1)"
          @current-change="loadLogs()"
          background />
      </div>
    </el-card>

    <el-dialog v-model="detailVisible" title="审计详情" width="640px" destroy-on-close>
      <pre v-if="detailRow" class="json-box" style="max-height: 560px;">{{ JSON.stringify(detailRow, null, 2) }}</pre>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed, nextTick } from 'vue'
import {
  Search, Refresh, Download, Notebook, Lock, Wallet, Delete,
  Avatar, Connection, CircleCheckFilled, Key, Share, Tickets
} from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import axios from 'axios'
import { useAuth } from '@/stores/auth'

const authStore = useAuth()
const isSuperAdmin = computed(() => {
  const roles = authStore.user?.roles || authStore.roles || []
  return roles.includes('super_admin')
})

const range = ref([])
const kw = ref('')
const filter = reactive({ level: '', type: '' })
const showAll = ref(false)
const loading = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const logs = ref([])
const opTypes = ref([])
const opTypesMap = ref({})
const summary = reactive({ today: 0, high7d: 0, fail7d: 0 })
const levels = ref([
  { name: '高危', color: '#ef4444', count: 0 },
  { name: '中危', color: '#f59e0b', count: 0 },
  { name: '低危', color: '#3b82f6', count: 0 },
])
const detailVisible = ref(false)
const detailRow = ref(null)

async function loadOpTypes() {
  try {
    const { data: res } = await axios.get('/audit/actions')
    if (res.code === 0) {
      opTypes.value = res.data || []
      opTypesMap.value = Object.fromEntries((res.data || []).map(t => [t.k, t]))
    }
  } catch (e) {
    // 兜底显示
  }
}

async function loadLogs(resetPage) {
  if (resetPage) page.value = 1
  loading.value = true
  try {
    const params = {
      page: page.value,
      page_size: pageSize.value,
    }
    if (filter.level) params.level = filter.level
    if (filter.type) params.action = filter.type
    if (kw.value) params.kw = kw.value
    if (range.value && range.value.length === 2) {
      params.start = range.value[0] ? new Date(range.value[0]).toISOString().replace('T', ' ').slice(0, 19) : ''
      params.end = range.value[1] ? new Date(range.value[1]).toISOString().replace('T', ' ').slice(0, 19) : ''
    }
    if (showAll.value && isSuperAdmin.value) params.all = '1'
    const { data: res } = await axios.get('/audit/list', { params })
    if (res.code === 0) {
      logs.value = res.data.list || []
      total.value = res.data.total || 0
      const s = res.data.summary
      if (s) {
        summary.today = s.today ?? 0
        summary.high7d = s.high7d ?? 0
        summary.fail7d = s.fail7d ?? 0
      }
      // 按等级重新计数（当前页维度，更直观）
      levels.value[0].count = logs.value.filter(l => l.level === 'high').length
      levels.value[1].count = logs.value.filter(l => l.level === 'mid').length
      levels.value[2].count = logs.value.filter(l => l.level === 'low').length
    } else {
      ElMessage.error(res.message || '审计日志加载失败')
    }
  } catch (e) {
    ElMessage.error('审计接口异常：' + (e?.message || e))
  } finally {
    loading.value = false
  }
}

function resetFilter() {
  range.value = []
  kw.value = ''
  filter.level = ''
  filter.type = ''
  showAll.value = false
  nextTick(() => loadLogs(1))
}

function exportCsv() {
  const header = ['时间', '风险', '操作类型', '操作人', 'IP', '资源类型', '资源ID', '摘要', '结果']
  const lines = [header.join(',')]
  logs.value.forEach(r => {
    const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
    lines.push([
      r.created_at, r.level, r.action,
      r.username || ('user#' + r.user_id),
      r.ip || '',
      r.resource_type || '',
      r.resource_id || '',
      r.summary || '',
      r.ok ? '成功' : '失败',
    ].map(esc).join(','))
  })
  const blob = new Blob(['\ufeff' + lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `audit_logs_${Date.now()}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function viewDetail(row) {
  detailRow.value = row
  detailVisible.value = true
}

onMounted(async () => {
  await loadOpTypes()
  await loadLogs(1)
})
</script>

<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; }
.stat-card.ok { background: linear-gradient(135deg,#ecfeff,#dbeafe); }
.stat-card.warn { background: linear-gradient(135deg,#fff7ed,#fee2e2); }
.stat-card.danger { background: linear-gradient(135deg,#fee2e2,#fecaca); }
.stat-card .lbl { margin-bottom: 6px; }
.stat-card .val { font-size: 28px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.stat-card .ft { font-size: 12px; color: #374151; margin-top: 8px; }
.legend .l-row { display: flex; gap: 22px; flex-wrap: wrap; }
.legend .l-item { display: flex; align-items: center; gap: 8px; }
.legend .d { width: 14px; height: 14px; border-radius: 4px; display: inline-block; }
.legend .t { font-size: 13px; color: #374151; }
.legend .n { font-weight: 800; color: #111827; margin-left: 4px; }

.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.card-header .btns { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
.op-cell { display: flex; align-items: center; gap: 8px; color: #374151; }
.ua { margin-top: 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 260px; }
.detail-cell { color: #111827; font-size: 13px; background: #fafbfc; padding: 4px 8px; border-radius: 6px; display: inline-block; max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
.json-box { margin: 6px 0 0; padding: 10px; background: #0f172a; color: #e2e8f0; border-radius: 8px; font-size: 12px; white-space: pre-wrap; word-break: break-all; max-height: 200px; overflow: auto; }
</style>
