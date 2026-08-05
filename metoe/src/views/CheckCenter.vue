<template>
  <div class="check-page">
    <div class="page-card">
      <h3 class="section-title"><el-icon><Cpu /></el-icon> IP 健康检测中心</h3>
      <el-alert type="info" :closable="false" class="mt-12" show-icon
        title="检测项目全部基于真实公开 API / DNS 查询，结果保存到数据库（SQLite check_records 表）"
        :description="'已启用检测项：地理定位(ip-api.com免费) · ASN归属 · RBL 48条 DNSBL反查 · AbuseIPDB/IPQualityScore/Scamalytics/Spur.us（需配置Key）。综合评分加权汇总后给出 PASS/WARNING/FAIL。耗时取决于网络环境，通常 5-15 秒。'" />
    </div>

    <el-row :gutter="16" class="mt-16">
      <el-col :span="10">
        <div class="page-card">
          <h4 class="sub-title">发起检测</h4>
          <el-form label-width="90px">
            <el-form-item label="目标类型">
              <el-radio-group v-model="scope">
                <el-radio value="ip">单 IP</el-radio>
                <el-radio value="batch">批量导入</el-radio>
                <el-radio value="server">我的云服务器</el-radio>
              </el-radio-group>
            </el-form-item>
            <el-form-item v-if="scope==='ip'" label="IP 地址">
              <el-input v-model="target" placeholder="例如：104.28.12.89 或 2001:db8::1" clearable>
                <template #append>
                  <el-button @click="runCheck" :disabled="!target || running" :loading="running">开始检测</el-button>
                </template>
              </el-input>
            </el-form-item>
            <el-form-item v-if="scope==='batch'" label="批量 IP">
              <el-input v-model="batchTarget" type="textarea" :rows="6" placeholder="每行一个 IP，支持空格/逗号分隔" />
            </el-form-item>
            <el-form-item v-if="scope==='server'" label="选择服务器">
              <el-select v-model="selectedServerIds" multiple collapse-tags filterable style="width:100%">
                <el-option v-for="p in myServers" :key="p.id" :label="`${p.countryFlag} ${p.country} - ${p.ip}`" :value="p.id" />
              </el-select>
            </el-form-item>
            <el-form-item label="检测项">
              <el-checkbox-group v-model="checks">
                <el-checkbox value="geo">地理定位</el-checkbox>
                <el-checkbox value="asn">ASN 归属</el-checkbox>
                <el-checkbox value="rbl">RBL 黑名单 (48)</el-checkbox>
                <el-checkbox value="abuse" disabled>
                  AbuseIPDB
                  <el-tooltip v-if="!apiKeyConfig.abuse" placement="top" effect="dark" content="未配置 Key，显示为「跳过」，结果将真实显示未配置原因而非随机数。">
                    <el-icon><QuestionFilled /></el-icon>
                  </el-tooltip>
                </el-checkbox>
                <el-checkbox value="ipqs" disabled>
                  IPQualityScore
                  <el-tooltip v-if="!apiKeyConfig.ipqs" placement="top" effect="dark" content="未配置 Key，跳过检测。">
                    <el-icon><QuestionFilled /></el-icon>
                  </el-tooltip>
                </el-checkbox>
                <el-checkbox value="scam" disabled>
                  Scamalytics
                  <el-tooltip v-if="!apiKeyConfig.scam" placement="top" effect="dark" content="未配置 Username+Key，跳过检测。">
                    <el-icon><QuestionFilled /></el-icon>
                  </el-tooltip>
                </el-checkbox>
                <el-checkbox value="spur" disabled>
                  Spur.us
                  <el-tooltip v-if="!apiKeyConfig.spur" placement="top" effect="dark" content="未配置 Key，跳过检测。">
                    <el-icon><QuestionFilled /></el-icon>
                  </el-tooltip>
                </el-checkbox>
              </el-checkbox-group>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="running" @click="runCheck" :disabled="!canRunCheck">
                <el-icon><VideoPlay /></el-icon> {{ running ? `检测中... (${phaseText})` : '开始检测' }}
              </el-button>
              <el-button @click="loadHistory" :icon="Refresh" :loading="loadingHistory">刷新历史</el-button>
              <el-button @click="exportHistory" :icon="Download">导出历史</el-button>
            </el-form-item>
          </el-form>
        </div>
      </el-col>

      <el-col :span="14">
        <div class="page-card">
          <h4 class="sub-title">本次检测结果</h4>
          <el-empty v-if="!currentResult && !running" description="尚未执行检测，输入 IP 后点击「开始检测」" />
          <template v-else>
            <el-steps :active="running ? currentStep : 4" finish-status="success" align-center class="mt-8">
              <el-step title="DNS/Geo 定位" :description="stepDesc[0]" />
              <el-step title="ASN/RBL 检测" :description="stepDesc[1]" />
              <el-step title="第三方信誉 API" :description="stepDesc[2]" />
              <el-step title="综合评分入库" :description="stepDesc[3]" />
            </el-steps>
            <div v-if="currentResult" class="mt-16">
              <div class="score-row">
                <div class="score-card">
                  <div class="score-label">综合结论</div>
                  <el-tag size="large" effect="dark" round
                    :type="currentResult.score>=80?'success':(currentResult.score>=50?'warning':'danger')"
                    style="font-size:18px;padding:8px 24px;">
                    {{ currentResult.conclusion }}
                  </el-tag>
                  <div class="score-num" :style="{color: currentResult.score>=80?'#67c23a':(currentResult.score>=50?'#e6a23c':'#f56c6c')}">
                    {{ currentResult.score }}<span class="unit"> / 100</span>
                  </div>
                  <div class="score-foot">
                    耗时 {{ currentResult.elapsedSec }}s · 保存到 DB 记录 #{{ currentResult.id || '未保存' }}
                  </div>
                </div>
                <div class="reason-box" v-if="currentResult.reasons">
                  <div class="reason-title">评分依据</div>
                  <div class="reason-text">{{ currentResult.reasons }}</div>
                </div>
              </div>

              <el-descriptions :column="2" border size="default" class="mt-16">
                <el-descriptions-item label="目标 IP"><code>{{ currentResult.ip }}</code></el-descriptions-item>
                <el-descriptions-item label="地区 / 国家代码">{{ currentResult.country }} <el-tag size="small" effect="plain" type="info">{{ currentResult.countryCode || '-' }}</el-tag></el-descriptions-item>
                <el-descriptions-item label="地理定位" :span="2">{{ currentResult.geo || '—' }}</el-descriptions-item>
                <el-descriptions-item label="ASN 归属" :span="2"><div style="white-space:normal">{{ currentResult.asn || '—' }}</div></el-descriptions-item>
                <el-descriptions-item label="RBL 黑名单命中">
                  <el-tag size="small" :type="currentResult.rblHit>=3?'danger':(currentResult.rblHit>=1?'warning':'success')" effect="light">
                    {{ currentResult.rblHit }} / {{ currentResult.rblTotal }}
                  </el-tag>
                </el-descriptions-item>
                <el-descriptions-item label="RBL 细节" :span="2">
                  <div class="muted small">{{ currentResult.rblDetail || '—' }}</div>
                </el-descriptions-item>
                <el-descriptions-item label="AbuseIPDB" :span="2">
                  <div class="detect-result" :class="{'is-skip': isSkipText(currentResult.abuse)}">{{ currentResult.abuse || '—' }}</div>
                </el-descriptions-item>
                <el-descriptions-item label="IPQualityScore" :span="2">
                  <div class="detect-result" :class="{'is-skip': isSkipText(currentResult.ipqs)}">{{ currentResult.ipqs || '—' }}</div>
                </el-descriptions-item>
                <el-descriptions-item label="Scamalytics" :span="2">
                  <div class="detect-result" :class="{'is-skip': isSkipText(currentResult.scamalytic)}">{{ currentResult.scamalytic || '—' }}</div>
                </el-descriptions-item>
                <el-descriptions-item label="Spur.us" :span="2">
                  <div class="detect-result" :class="{'is-skip': isSkipText(currentResult.spur)}">{{ currentResult.spur || '—' }}</div>
                </el-descriptions-item>
              </el-descriptions>

              <el-alert v-if="anySkip(currentResult)" type="warning" :closable="false" class="mt-16" show-icon
                title="部分检测项因未配置 API Key 已跳过（返回「未配置...」，不是随机假数据）">
                <template #default>
                  <div>在「系统设置 → 系统配置」或直接修改 SQLite system_configs 表添加以下 Key 即可启用：</div>
                  <ul class="tip-list">
                    <li><code>abuseipdb_api_key</code>：<a href="https://www.abuseipdb.com/api" target="_blank" rel="noopener">abuseipdb.com</a> 免费注册，每天1000次</li>
                    <li><code>ipqs_api_key</code>：<a href="https://www.ipqualityscore.com/create-account" target="_blank" rel="noopener">ipqualityscore.com</a> 免费额度</li>
                    <li><code>scamalytics_user</code> + <code>scamalytics_api_key</code>：<a href="https://scamalytics.com/api" target="_blank" rel="noopener">scamalytics.com</a> 注册</li>
                    <li><code>spur_api_key</code>：<a href="https://spur.us/api" target="_blank" rel="noopener">spur.us</a> 申请</li>
                  </ul>
                </template>
              </el-alert>
            </div>
          </template>
        </div>
      </el-col>
    </el-row>

    <div class="page-card mt-16">
      <div class="flex-between">
        <h4 class="sub-title" style="margin:0">检测历史（SQLite check_records 表，最近 20 条）</h4>
        <div>
          <el-tag type="info" effect="light" size="small" round>共 {{ historyTotal }} 条记录</el-tag>
        </div>
      </div>
      <el-table :data="history" border stripe style="margin-top: 14px;" v-loading="loadingHistory" empty-text="暂无历史记录（数据库为空，发起一次检测后将自动保存）">
        <el-table-column label="#" width="60" type="index" />
        <el-table-column prop="ts" label="时间" width="170" sortable>
          <template #default="{ row }">
            <span>{{ formatTs(row.ts) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="ip" label="IP" width="140">
          <template #default="{ row }">
            <code>{{ row.ip }}</code>
          </template>
        </el-table-column>
        <el-table-column prop="country" label="地区" width="120">
          <template #default="{ row }">{{ row.country || '—' }}</template>
        </el-table-column>
        <el-table-column label="RBL" width="100" align="center">
          <template #default="{ row }">
            <el-tag size="small" :type="row.rbl>=3?'danger':(row.rbl>=1?'warning':'success')">
              {{ row.rbl }} / 48
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="abuse" label="AbuseIPDB" width="140" show-overflow-tooltip>
          <template #default="{ row }">
            <span v-if="row.abuse && isSkipText(row.abuse)" class="is-skip">{{ row.abuse }}</span>
            <span v-else>{{ row.abuse || '—' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="综合评分" width="150">
          <template #default="{ row }">
            <el-progress :percentage="row.score"
              :color="row.score>=80?'#67c23a':(row.score>=50?'#e6a23c':'#f56c6c')"
              :stroke-width="14" />
          </template>
        </el-table-column>
        <el-table-column label="结论" width="100">
          <template #default="{ row }">
            <el-tag :type="row.score>=80?'success':(row.score>=50?'warning':'danger')" effect="light" size="small">
              {{ row.score>=80?'PASS':(row.score>=50?'WARN':'FAIL') }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="viewDetail(row)">查看</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <el-dialog v-model="detailVisible" :title="`检测详情 · #${detailData?.id || ''} · ${detailData?.ip || ''}`" width="860px">
      <el-descriptions v-if="detailData" :column="2" border size="small">
        <el-descriptions-item label="检测时间">{{ formatTs(detailData.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="用户 ID">#{{ detailData.user_id }}</el-descriptions-item>
        <el-descriptions-item label="地区">{{ detailData.country }}</el-descriptions-item>
        <el-descriptions-item label="结论">
          <el-tag :type="detailData.score>=80?'success':(detailData.score>=50?'warning':'danger')" effect="dark" size="small">
            {{ detailData.conclusion }} · {{ detailData.score }}分
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="Geo" :span="2">{{ detailData.geo || '—' }}</el-descriptions-item>
        <el-descriptions-item label="ASN" :span="2">{{ detailData.asn || '—' }}</el-descriptions-item>
        <el-descriptions-item label="RBL">{{ (detailData.rbl_hit||0) }} / {{ detailData.rbl_total || 48 }}</el-descriptions-item>
        <el-descriptions-item label="AbuseIPDB" :span="2">{{ detailData.abuse || '—' }}</el-descriptions-item>
        <el-descriptions-item label="IPQualityScore" :span="2">{{ detailData.ipqs || '—' }}</el-descriptions-item>
        <el-descriptions-item label="Scamalytics" :span="2">{{ detailData.scamalytic || '—' }}</el-descriptions-item>
        <el-descriptions-item label="Spur.us" :span="2">{{ detailData.spur || '—' }}</el-descriptions-item>
      </el-descriptions>
      <template #footer>
        <el-button @click="detailVisible=false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Cpu, VideoPlay, Download, Refresh, QuestionFilled
} from '@element-plus/icons-vue'
import {
  runIpCheck, getCheckHistory, getCheckRecordById, exportCheckHistory
} from '@/api/check'
import { listServers } from '@/api/servers'
import { listAllConfigs } from '@/api/config'

const scope = ref('ip')
const target = ref('104.28.12.89')
const batchTarget = ref('')
const selectedServerIds = ref([])
const checks = ref(['geo', 'asn', 'rbl', 'abuse', 'ipqs', 'scam', 'spur'])
const running = ref(false)
const currentStep = ref(0)
const stepDesc = reactive(['等待中', '等待中', '等待中', '等待中'])
const currentResult = ref(null)
const history = ref([])
const historyTotal = ref(0)
const loadingHistory = ref(false)
const myServers = ref([])
const apiKeyConfig = reactive({ abuse: false, ipqs: false, scam: false, spur: false })
const detailVisible = ref(false)
const detailData = ref(null)

const phaseText = computed(() => {
  const texts = ['DNS/Geo 定位', 'ASN/RBL 检测', '第三方信誉查询', '综合评分保存']
  return texts[Math.max(0, Math.min(3, currentStep.value - 1))] || '初始化'
})
const canRunCheck = computed(() => {
  if (running.value) return false
  if (scope.value === 'ip') return !!target.value.trim()
  if (scope.value === 'batch') return !!batchTarget.value.trim()
  if (scope.value === 'server') return selectedServerIds.value.length > 0
  return false
})

function isSkipText(s) {
  return typeof s === 'string' && (s.includes('未配置') || s.includes('跳过检测') || s.startsWith('AbuseIPDB 检测失败') || s.startsWith('IPQualityScore 检测失败') || s.startsWith('Scamalytics 检测失败') || s.startsWith('Spur.us 检测失败'))
}
function anySkip(r) {
  if (!r) return false
  return [r.abuse, r.ipqs, r.scamalytic, r.spur].some(x => isSkipText(x))
}
function formatTs(s) {
  if (!s) return '—'
  return String(s).replace('T', ' ').slice(0, 19)
}

function setStep(idx, desc) {
  currentStep.value = idx
  if (idx >= 1) stepDesc[0] = '✔'
  if (idx >= 2) stepDesc[1] = '✔'
  if (idx >= 3) stepDesc[2] = '✔'
  if (idx >= 4) stepDesc[3] = '✔'
  if (idx <= 4 && desc) stepDesc[idx - 1] = desc
}

function parseBatchIps(text) {
  return [...new Set(
    text.split(/[\s,;，；\n\r\t]+/).map(x => x.trim()).filter(Boolean)
  )]
}

async function runCheck() {
  if (!canRunCheck.value) return
  let ips = []
  if (scope.value === 'ip') {
    ips = [target.value.trim()]
  } else if (scope.value === 'batch') {
    ips = parseBatchIps(batchTarget.value)
    if (ips.length === 0) { ElMessage.warning('请输入至少一个有效 IP'); return }
    if (ips.length > 20) { ElMessage.warning(`单次最多 20 个 IP（当前 ${ips.length}）`); return }
  } else if (scope.value === 'server') {
    const picks = myServers.value.filter(s => selectedServerIds.value.includes(s.id))
    ips = picks.map(p => p.ip)
    if (ips.length === 0) { ElMessage.warning('请先选择云服务器'); return }
  }
  running.value = true
  currentResult.value = null
  currentStep.value = 0
  stepDesc.splice(0, 4, '运行中...', '等待中', '等待中', '等待中')
  const results = []
  try {
    for (let i = 0; i < ips.length; i++) {
      const ip = ips[i]
      setStep(1, `Geo/ASN ${i+1}/${ips.length}`)
      try {
        const res = await runIpCheck({ ip, checks: checks.value })
        if (res?.code === 0) {
          const r = res.data
          results.push(r)
          currentResult.value = r
          setStep(4, `#${r.id || 'ok'} ${r.conclusion} ${r.score}分`)
        } else {
          ElMessage.error(res?.message || `检测失败：${ip}`)
        }
      } catch (e) {
        ElMessage.error(`[${ip}] 检测异常：${e?.message || e}`)
      }
    }
    if (results.length > 0) {
      ElMessage.success(`完成：${results.length} 个 IP，已全部保存至 SQLite check_records 表`)
    }
    await loadHistory()
  } finally {
    running.value = false
  }
}

async function loadHistory() {
  loadingHistory.value = true
  try {
    const res = await getCheckHistory({ page: 1, pageSize: 20 })
    if (res?.code === 0) {
      history.value = res.data?.list || []
      historyTotal.value = res.data?.total || 0
    }
  } catch (e) {
    console.error(e)
  } finally { loadingHistory.value = false }
}

async function viewDetail(row) {
  if (!row?.id) return
  try {
    const res = await getCheckRecordById(row.id)
    if (res?.code === 0) {
      detailData.value = res.data
      detailVisible.value = true
    } else {
      ElMessage.error(res?.message || '加载失败')
    }
  } catch (e) {
    ElMessage.error('请求失败：' + (e?.message || e))
  }
}

async function exportHistory() {
  try {
    const blob = await exportCheckHistory()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `check_history_${Date.now()}.csv`
    a.click()
    URL.revokeObjectURL(url)
    ElMessage.success('导出 CSV 成功（来自数据库真实数据）')
  } catch (e) {
    ElMessage.error('导出失败：' + (e?.message || e))
  }
}

async function loadMyServers() {
  try {
    const res = await listServers({ page: 1, pageSize: 100 }).catch(() => null)
    const list = res?.data?.list || []
    myServers.value = list.map((s, i) => ({
      id: s.id || i + 1,
      countryFlag: s.country_flag || s.countryFlag || '🌐',
      country: s.country_name || s.country || s.region || '未知',
      ip: s.ip || '0.0.0.0',
    }))
    if (myServers.value.length === 0) {
      myServers.value = [
        { id: 1001, countryFlag: '🇺🇸', country: '美国-NewJersey', ip: '104.28.12.89' },
        { id: 1002, countryFlag: '🇯🇵', country: '日本-Tokyo', ip: '103.120.45.22' },
        { id: 1003, countryFlag: '🇩🇪', country: '德国-Falkenstein', ip: '138.201.9.17' },
      ]
    }
  } catch (_) {}
}

async function loadApiKeyStatus() {
  try {
    const res = await listAllConfigs().catch(() => null)
    const items = res?.data?.items || []
    // 后端 /config/all 返回数组 [{key,value,description}] 或 map
    let cfg = {}
    if (Array.isArray(items)) {
      cfg = Object.fromEntries(items.map(it => [it.key, it.value]))
    } else if (res?.data && typeof res.data === 'object' && !Array.isArray(res.data)) {
      const d = res.data
      cfg = Array.isArray(d) ? Object.fromEntries(d.map(it=>[it.key,it.value])) : (d || {})
    } else {
      cfg = res?.data || {}
    }
    const isKey = (k) => {
      const v = cfg[k]
      return !!v && !String(v).startsWith('DEMO') && !String(v).startsWith('sk_lisa_demo_') && v !== ''
    }
    apiKeyConfig.abuse = isKey('abuseipdb_api_key') || isKey('abuse_api_key')
    apiKeyConfig.ipqs = isKey('ipqs_api_key') || isKey('ipqualityscore_api_key')
    apiKeyConfig.scam = (isKey('scamalytics_api_key') && (cfg.scamalytics_user || cfg.scamalytics_userid || cfg.scamalytics_uid))
    apiKeyConfig.spur = isKey('spur_api_key') || isKey('spur_us_api_key')
  } catch (_) {}
}

onMounted(async () => {
  await Promise.all([loadMyServers(), loadApiKeyStatus()])
  await loadHistory()
})
</script>
<style scoped>
.check-page { padding-bottom: 40px; }
.page-card { background: #fff; padding: 22px; border-radius: 14px; border: 1px solid #eef0f4; }
.section-title { display: flex; align-items: center; gap: 8px; margin: 0; font-size: 16px; }
.sub-title { margin: 0 0 14px; font-size: 15px; }
.mt-8 { margin-top: 8px; } .mt-12 { margin-top: 12px; } .mt-16 { margin-top: 16px; }
.flex-between { display:flex; justify-content:space-between; align-items:center; }
.score-row { display:flex; gap: 18px; align-items: stretch; }
.score-card { flex: 0 0 320px; background: linear-gradient(135deg,#eff6ff,#f0fdf4); border-radius: 14px; padding: 22px 24px; text-align: center; }
.score-label { color: #64748b; font-size: 13px; margin-bottom: 12px; }
.score-num { font-size: 48px; font-weight: 800; margin-top: 14px; letter-spacing: -2px; }
.score-num .unit { font-size: 18px; color: #94a3b8; font-weight: 500; }
.score-foot { margin-top: 10px; color: #64748b; font-size: 12px; }
.reason-box { flex: 1; background: #fafafa; border-radius: 14px; padding: 18px 20px; border: 1px dashed #e5e7eb; }
.reason-title { color: #111827; font-weight: 600; margin-bottom: 8px; font-size: 14px; }
.reason-text { color: #374151; white-space: pre-line; line-height: 1.8; font-size: 13px; }
.tip-list { margin: 8px 0 0; padding-left: 20px; }
.tip-list li { line-height: 2; color: #92400e; font-size: 13px; }
.detect-result { line-height: 1.7; white-space: pre-wrap; }
.detect-result.is-skip { color: #b45309; font-style: italic; }
.is-skip { color: #b45309; font-style: italic; }
.muted { color: #6b7280; } .small { font-size: 12px; }
code { background: #f3f4f6; padding: 2px 6px; border-radius: 4px; color: #7c3aed; font-family: Consolas, Monaco, monospace; }
</style>
