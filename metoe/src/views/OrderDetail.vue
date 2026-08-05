<template>
  <div class="order-detail">
    <div v-if="loading" class="page-card"><el-empty description="加载订单信息..." /></div>
    <template v-else>
      <div class="page-card">
        <div class="flex-between">
          <div>
            <h2 style="margin:0 0 6px">
              订单 <span class="mono">{{ order?.order_no }}</span>
              <el-tag size="small" :type="statusTag(order?.status).type" style="margin-left:10px">{{ statusTag(order?.status).text }}</el-tag>
              <el-tag v-if="order?.deployStatus" size="small" :type="deployTag(order?.deployStatus).type" style="margin-left:8px">
                部署：{{ deployTag(order?.deployStatus).text }}
              </el-tag>
            </h2>
            <div class="muted small">{{ order?.createdAt || order?.created_at }} 创建 · 订单ID {{ order?.id }}</div>
          </div>
          <div>
            <el-button v-if="order?.status==='pending'" type="warning" size="large" @click="showPay = true">
              <el-icon><Wallet /></el-icon> 立即支付
            </el-button>
            <el-button v-if="order?.deploy?.status==='failed'" type="danger" @click="retryDeploy">
              <el-icon><RefreshRight /></el-icon> 重试部署
            </el-button>
            <el-button @click="$router.back()">返回</el-button>
          </div>
        </div>
        <el-descriptions :column="3" border class="mt-16">
          <el-descriptions-item label="产品名称">{{ order?.product }}</el-descriptions-item>
          <el-descriptions-item label="地区">{{ order?.countryFlag }} {{ order?.countryName || order?.country_name }}</el-descriptions-item>
          <el-descriptions-item label="数量/周期">{{ order?.qty }} 台 · {{ periodLabel(order?.period) }}</el-descriptions-item>
          <el-descriptions-item label="原价">¥ {{ order?.amount }}</el-descriptions-item>
          <el-descriptions-item label="折扣">-¥ {{ order?.discount }}</el-descriptions-item>
          <el-descriptions-item label="实付"><b class="price">¥ {{ order?.total }}</b></el-descriptions-item>
          <el-descriptions-item label="Lisa主机订单号">{{ order?.lisaOrderId || order?.lisa_order_id || '—' }}</el-descriptions-item>
          <el-descriptions-item label="机房/规格">{{ order?.lisaRegion || order?.lisa_region }} · {{ order?.lisaSpec || '—' }}</el-descriptions-item>
          <el-descriptions-item label="支付时间">{{ order?.paidAt || order?.paid_at || '待支付' }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <el-row :gutter="16" class="mt-16">
        <el-col :span="14">
          <div class="page-card">
            <h3 class="section-title"><el-icon><Monitor /></el-icon> 部署进度</h3>
            <el-steps :active="deployStep" finish-status="success" process-status="process" align-center>
              <el-step title="下单支付" description="确认订单信息 & 支付" />
              <el-step title="Lisa主机采购" :description="order?.lisaOrderId || '机房分配资源'" />
              <el-step title="云服务器初始化" description="创建实例 & 远程连接配置" />
              <el-step title="接入环境配置" description="入口面板 & 远程访问设置" />
              <el-step title="结果交付保存" description="生成入口二维码 & 访问链接" />
            </el-steps>

            <div v-if="order?.deploy" class="deploy-info mt-16">
              <div class="flex-between">
                <span class="muted small">任务号 <b class="mono">{{ order.deploy.task_no }}</b> · 进度 {{ order.deploy.progress || 0 }}%</span>
                <el-button link size="small" type="primary" @click="loadDetail">刷新</el-button>
              </div>
              <el-progress class="mt-8" :percentage="order.deploy.progress || 0" :status="deployProgressStatus()" />
              <pre class="logs-box mt-12">{{ deployLogs }}</pre>
            </div>
            <el-empty v-else-if="order?.status==='pending'" description="待支付后自动开始部署" />
            <el-empty v-else description="暂无部署记录" />
          </div>

          <div v-if="proxies && proxies.length" class="page-card mt-16">
            <h3 class="section-title"><el-icon><Link /></el-icon> 接入面板交付（共 {{ proxies.length }} 条）</h3>
            <el-table :data="proxies" border stripe>
              <el-table-column prop="id" label="ID" width="60" />
              <el-table-column label="地区" width="100">
                <template #default="{ row }">{{ row.countryFlag }} {{ row.country }}</template>
              </el-table-column>
              <el-table-column label="接入地址" width="220">
                <template #default="{ row }">
                  <div class="mono small">{{ row.ip }}:{{ row.port }}</div>
                  <div class="muted small">{{ row.username }} / {{ row.password }}</div>
                </template>
              </el-table-column>
              <el-table-column label="入口面板">
                <template #default="{ row }">
                  <a v-if="row.entryUrl || row.vpnUrl" :href="row.entryUrl || row.vpnUrl" target="_blank" class="link">{{ row.entryUrl || row.vpnUrl }}</a>
                  <span v-else class="muted small">初始化中，入口待生成</span>
                </template>
              </el-table-column>
              <el-table-column label="入口二维码" width="150" align="center">
                <template #default="{ row }">
                  <el-popover placement="left" :width="200" trigger="click">
                    <template #reference>
                      <el-button link size="small" type="primary" :disabled="!(row.qrCode || row.vpnQrCode)">扫码访问</el-button>
                    </template>
                    <div style="text-align:center">
                      <div v-if="row.qrCode || row.vpnQrCode" class="qr-placeholder">
                        <el-icon :size="96" color="#2c7be5"><PictureFilled /></el-icon>
                        <div class="mt-8 small muted">手机扫码访问入口</div>
                      </div>
                      <div v-else class="muted small">暂无</div>
                    </div>
                  </el-popover>
                  <el-button v-if="row.configPath || row.vpnConfigPath" link size="small" type="success" @click="downloadConfig(row)">下载配置</el-button>
                </template>
              </el-table-column>
              <el-table-column label="状态" width="80" align="center">
                <template #default="{ row }">
                  <el-tag size="small" :type="row.status==='active'?'success':'info'">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
            </el-table>
          </div>
        </el-col>

        <el-col :span="10">
          <div class="page-card">
            <h3 class="section-title"><el-icon><Cpu /></el-icon> 云服务器</h3>
            <div v-if="order?.server">
              <div class="info-row"><span>IP 地址</span><b class="mono">{{ order.server.ip }}</b></div>
              <div class="info-row"><span>机房/提供商</span>{{ order.server.provider }} / {{ order.server.region }}</div>
              <div class="info-row"><span>规格</span>{{ order.server.cpuCores || order.server.cpu_cores }}核 / {{ ((order.server.ramMb || order.server.ram_mb || 0)/1024).toFixed(0) }}GB / {{ order.server.diskGb || order.server.disk_gb }}GB SSD</div>
              <div class="info-row"><span>带宽</span>{{ order.server.bandwidthMbps || order.server.bandwidth_mbps }} Mbps</div>
              <div class="info-row"><span>SSH / RDP 登录</span><span class="mono small">{{ order.server.sshUser || order.server.ssh_user }}@{{ order.server.ip }}:{{ order.server.sshPort || order.server.ssh_port }}</span></div>
              <div class="info-row"><span>登录密码</span>
                <el-button link size="small" type="primary" @click="copySsh">复制命令</el-button>
                <el-button link size="small" type="success" @click="showSshPwd">查看</el-button>
              </div>
              <div class="info-row"><span>操作系统</span>{{ order.server.os }}</div>
              <div class="info-row"><span>月租</span>¥ {{ order.server.priceMonth || order.server.price_month }}</div>
              <div class="info-row"><span>到期日</span>{{ order.server.expireAt || order.server.expire_at }}</div>
              <div class="info-row"><span>状态</span>
                <el-tag size="small" :type="['active','running'].includes(order.server.status)?'success':(order.server.status==='error'?'danger':'info')">
                  {{ ({active:'运行中',running:'运行中',provisioning:'初始化',deploying:'初始化',stopped:'关机',reinstalling:'重装中',expired:'已过期',error:'异常'})[order.server.status] || order.server.status }}
                </el-tag>
              </div>
            </div>
            <el-empty v-else description="支付成功后自动分配服务器资源" />
          </div>

          <div class="page-card mt-16">
            <h3 class="section-title"><el-icon><Wallet /></el-icon> 支付记录</h3>
            <el-table :data="order?.payments || []" size="small" border>
              <el-table-column prop="pay_no" label="支付单号" width="180">
                <template #default="{ row }"><span class="mono small">{{ row.pay_no }}</span></template>
              </el-table-column>
              <el-table-column prop="channel" label="渠道" width="100" />
              <el-table-column prop="amount" label="金额" width="90">
                <template #default="{ row }">¥ {{ row.amount }}</template>
              </el-table-column>
              <el-table-column label="状态" width="90">
                <template #default="{ row }">
                  <el-tag size="small" :type="row.status==='paid'?'success':(row.status==='pending'?'warning':'danger')">
                    {{ row.status==='paid'?'成功':row.status==='pending'?'待支付':row.status }}
                  </el-tag>
                </template>
              </el-table-column>
            </el-table>
          </div>
        </el-col>
      </el-row>
    </template>

    <el-dialog v-model="showPay" title="选择支付方式" width="540px">
      <el-radio-group v-model="payChannel" style="width:100%">
        <el-radio value="balance" style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px">
          <b><el-icon><Wallet /></el-icon> 余额支付</b><span class="muted ml-8">当前余额：¥{{ userBalance }}</span>
        </el-radio>
        <el-radio value="paypal" style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px">
          <b><el-icon><CreditCard /></el-icon> PayPal（美元结算）</b>
          <el-tag size="small" type="success" class="ml-8">已接入 官方 v2</el-tag>
        </el-radio>
        <el-radio value="usdt" style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px">
          <b><el-icon><Coin /></el-icon> USDT（TRC20 链上）</b>
          <el-tag size="small" type="warning" class="ml-8">官方模拟 30 分钟有效</el-tag>
        </el-radio>
        <el-radio value="mock" style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px">
          <b><el-icon><MagicStick /></el-icon> 模拟支付（演示）</b>
          <span class="muted ml-8">支付后可模拟确认回调</span>
        </el-radio>
        <el-radio value="alipay" disabled style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px;opacity:.55">
          <b>支付宝</b> <el-tag size="small" type="info">对接中</el-tag>
        </el-radio>
        <el-radio value="wechat" disabled style="display:block;padding:10px 14px;border:1px solid #eee;border-radius:8px;margin-bottom:10px;opacity:.55">
          <b>微信支付</b> <el-tag size="small" type="info">对接中</el-tag>
        </el-radio>
      </el-radio-group>

      <div v-if="qrResult" class="qr-box">
        <el-alert v-if="qrResult.paid" type="success" :closable="false" show-icon>
          ✓ 支付成功，部署已启动，稍后自动刷新...
        </el-alert>
        <template v-else>
          <el-alert type="warning" :closable="false">
            支付单号：<span class="mono small">{{ qrResult.pay_no }}</span><br/>
            金额：<b>¥ {{ qrResult.amount }}</b><br/>
            二维码：<span class="mono small">{{ qrResult.qr_data }}</span>
          </el-alert>
          <el-button class="mt-8" type="warning" @click="confirmMock">模拟支付回调</el-button>
        </template>
      </div>

      <template #footer>
        <el-button @click="showPay=false">取消</el-button>
        <el-button type="primary" @click="doPay">确认支付 ¥ {{ order?.total }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup>
import { computed, reactive, ref, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getOrderDetail, payOrder } from '@/api/order'
import { retryDeploy as apiRetryDeploy } from '@/api/deploy'
import { mockConfirmPay } from '@/api/payments'
import { useUserStore } from '@/stores/user'
import {
  Wallet, RefreshRight, Monitor, Link, Cpu,
  CreditCard, Coin, MagicStick
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const order = ref(null)
const loading = ref(true)
const deployLogs = ref('')
const showPay = ref(false)
const payChannel = ref('balance')
const qrResult = ref(null)

const userBalance = computed(() => userStore.profile?.balance || 0)
const proxies = computed(() => order.value?.proxies || [])
const deployStep = computed(() => {
  if (!order.value?.status || order.value.status === 'pending') return 0
  const s = order.value?.deploy?.status || order.value?.deployStatus
  if (s === 'done') return 5
  if (s === 'failed') return 3
  if (s === 'running') return 3
  if (order.value?.lisaOrderId || order.value?.deploy) return 2
  return 1
})

const STATUS_MAP = {
  pending: { text: '待支付', type: 'warning' },
  paid: { text: '已支付', type: 'info' },
  completed: { text: '完成', type: 'success' },
  canceled: { text: '取消', type: 'info' },
  refunded: { text: '退款', type: 'danger' },
};
const DEPLOY_MAP = {
  pending: { text: '待启动', type: 'info' },
  waiting: { text: '待启动', type: 'info' },
  running: { text: '部署中', type: 'warning' },
  installing_base: { text: '部署中', type: 'warning' },
  done: { text: '完成', type: 'success' },
  success: { text: '完成', type: 'success' },
  failed: { text: '失败', type: 'danger' },
};
const PERIOD_MAP = {
  '1m': '1个月',
  '3m': '3个月',
  '6m': '6个月',
  '1y': '1年',
};
function statusTag(s) {
  return STATUS_MAP[s] || { text: s, type: '' };
}
function deployTag(s) {
  return DEPLOY_MAP[s] || { text: s, type: '' };
}
function periodLabel(p) {
  return PERIOD_MAP[p] || p || '—';
}
function deployProgressStatus() {
  const s = order.value?.deploy?.status
  if (s === 'done' || s === 'success') return 'success'
  if (s === 'failed' || s === 'error') return 'exception'
  return null
}

async function loadDetail() {
  try {
    order.value = await getOrderDetail(route.params.orderNo)
    deployLogs.value = order.value?.deploy?.logsOutput || order.value?.deploy?.log_text || order.value?.deploy?.logs_output || '(暂无日志)'
  } finally { loading.value = false }
}
let timer = null
function startPolling() {
  stopPolling()
  timer = setInterval(() => {
    const dstatus = order.value?.deploy?.status
    if (order.value && (dstatus === 'running' || dstatus === 'pending' || (!dstatus && order.value.status === 'paid'))) {
      loadDetail()
    } else if (order.value && dstatus === 'done') {
      stopPolling()
    }
  }, 4000)
}
function stopPolling() { if (timer) { clearInterval(timer); timer = null } }

async function doPay() {
  try {
    const res = await payOrder(order.value.order_no, { channel: payChannel.value })
    if (res?.paid) {
      qrResult.value = res
      ElMessage.success('支付成功！部署已启动')
      setTimeout(async () => { await userStore.fetchProfile(); showPay.value = false; await loadDetail(); startPolling() }, 800)
    } else {
      qrResult.value = res
      ElMessage.info('请扫码完成支付（或点击下方模拟支付按钮）')
    }
  } catch (e) {}
}
async function confirmMock() {
  try {
    await mockConfirmPay(qrResult.value.pay_no)
    ElMessage.success('模拟支付成功回调已触发')
    setTimeout(async () => { showPay.value=false; await loadDetail(); startPolling() }, 800)
  } catch(e) {}
}
async function retryDeploy() {
  try {
    const dp = order.value.deploy
    if (!dp) return
    await apiRetryDeploy(dp.id)
    ElMessage.success('重部署任务已启动')
    loadDetail()
  } catch(e){}
}
function copySsh() {
  if (!order.value?.server) return
  const s = order.value.server
  const u = s.sshUser || s.ssh_user || 'root'
  const p = s.sshPort || s.ssh_port || 22
  const cmd = (s.os || '').toLowerCase().includes('windows')
    ? `mstsc /v:${s.ip}:${p}`
    : `ssh ${u}@${s.ip} -p ${p}`
  navigator.clipboard.writeText(cmd)
  ElMessage.success((s.os || '').toLowerCase().includes('windows') ? 'RDP 连接命令已复制' : 'SSH 命令已复制')
}
function showSshPwd() {
  if (!order.value?.server) return
  const s = order.value.server
  const u = s.sshUser || s.ssh_user || 'root'
  const pwd = s.sshPassword || s.ssh_password || '********'
  const p = s.sshPort || s.ssh_port || 22
  ElMessageBox.alert(
    `<div style="line-height:2">
      <div>登录账号：<b class="mono">${u}</b></div>
      <div>登录密码：<b class="mono">${pwd}</b></div>
      <div>IP / 端口：<b class="mono">${s.ip}:${p}</b></div>
      <div>操作系统：${s.os || '—'}</div>
      <div class="muted small mt-8">请勿在公共场合展示或分享您的登录凭据，建议首次登录后修改密码</div>
    </div>`,
    `云服务器 #${s.id} 登录凭据`,
    { dangerouslyUseHTMLString: true, confirmButtonText: '我已保存', type: 'success' }
  )
}
function downloadConfig(row) {
  const content = row.configContent || row.vpnConfigContent || row.vpn_config_content || '# 节点客户端配置\n'
  const blob = new Blob([content], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  const name = (row.configPath || row.vpnConfigPath || row.vpn_config_path || 'node-client.conf').split('/').pop()
  a.href = url; a.download = name; a.click()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  await loadDetail()
  if (route.query.pay === '1' && order.value?.status === 'pending') showPay.value = true
  if (order.value?.deploy?.status === 'running' || order.value?.deploy?.status === 'pending') startPolling()
})
onBeforeUnmount(stopPolling)
</script>
<style scoped>
.mt-8{margin-top:8px} .mt-12{margin-top:12px} .mt-16{margin-top:16px} .ml-8{margin-left:8px}
.muted{color:#6b7280} .small{font-size:12px} .mono{font-family:Consolas,Monaco,monospace}
.flex-between{display:flex;justify-content:space-between;align-items:center}
.info-row{display:flex;justify-content:space-between;padding:8px 4px;border-bottom:1px dashed #f0f0f0}
.info-row:last-child{border-bottom:none}
.section-title{margin:0 0 12px;font-size:15px;display:flex;align-items:center;gap:6px}
.price{color:#f56c6c;font-size:16px}
.logs-box{background:#111827;color:#a7f3d0;font-size:12px;padding:12px;border-radius:6px;max-height:240px;overflow:auto;white-space:pre-wrap}
.qr-box{margin-top:14px}
.qr-placeholder{width:170px;height:170px;border:1px dashed #c0c4cc;border-radius:8px;display:flex;align-items:center;justify-content:center;background:#fafafa;flex-direction:column}
</style>
