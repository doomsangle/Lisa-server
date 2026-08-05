<template>
  <div class="developer-page">
    <!-- 顶部 API 文档入口 -->
    <el-card class="page-hero" shadow="never">
      <div class="hero-left">
        <div class="hero-icon"><el-icon :size="42"><MagicStick /></el-icon></div>
        <div>
          <h1 class="hero-title">MetoE 开发者中心 · REST API 文档</h1>
          <p class="hero-desc muted">
            通过 HTTP API 自动化管理您的云服务器、接入实例、订单、支付、部署流水线；
            所有接口均支持 <code class="inline-code">Bearer Token</code> 认证，兼容 /api 与 /v1 两套前缀。
          </p>
        </div>
      </div>
      <div class="hero-right">
        <el-tag type="success" effect="dark" round>Swagger UI: /docs</el-tag>
        <el-tag type="warning" effect="dark" round class="ml-8">ReDoc: /redoc</el-tag>
        <el-tag type="info" round class="ml-8">v1.0.0 · OAS 3.1</el-tag>
      </div>
    </el-card>

    <el-row :gutter="18" class="mt-16">
      <!-- 左列：API Key + 环境 + 调用日志 -->
      <el-col :span="7">
        <div class="lhs-wrap">
          <el-card class="lhs-card" shadow="hover">
            <h3 class="lhs-title"><el-icon><Key /></el-icon> 接口访问凭证</h3>
            <div class="env-select">
              <label class="lbl">环境</label>
              <el-radio-group v-model="env" size="small">
                <el-radio-button value="dev">本地 dev (3000)</el-radio-button>
                <el-radio-button value="staging">Staging</el-radio-button>
                <el-radio-button value="prod">Production</el-radio-button>
              </el-radio-group>
            </div>
            <div class="base-url-box">
              <div class="lbl small muted">Base URL</div>
              <div class="base-url">{{ baseURL }}</div>
              <el-button size="small" link @click="copy(baseURL)">复制</el-button>
            </div>
            <el-divider />
            <div class="key-section">
              <div class="flex-between">
                <span class="lbl"><b>API Key</b></span>
                <el-button link size="small" @click="regenerate"><el-icon><Refresh /></el-icon> 重新生成</el-button>
              </div>
              <el-input v-model="apiKey" readonly size="default" show-password type="password" class="key-input">
                <template #append>
                  <el-button @click="copy(apiKey)">复制</el-button>
                </template>
              </el-input>
              <el-form size="small" label-width="72px" class="mt-12">
                <el-form-item label="Key 名称">
                  <el-input v-model="newKeyName" placeholder="例如：Production-Server" />
                </el-form-item>
                <el-form-item label="权限范围">
                  <el-checkbox-group v-model="keyScopes">
                    <el-checkbox value="access:read">接入读取</el-checkbox>
                    <el-checkbox value="servers:read">主机读取</el-checkbox><br>
                    <el-checkbox value="access:write">接入管理</el-checkbox>
                    <el-checkbox value="servers:write">主机管理</el-checkbox><br>
                    <el-checkbox value="orders:read">订单读取</el-checkbox>
                    <el-checkbox value="orders:write">下单购买</el-checkbox><br>
                    <el-checkbox value="payment:write">发起支付</el-checkbox>
                    <el-checkbox value="check:run">检测中心</el-checkbox>
                  </el-checkbox-group>
                </el-form-item>
                <el-form-item>
                  <el-button type="primary" size="default"><el-icon><Plus /></el-icon> 新增 Key</el-button>
                  <el-button size="default"><el-icon><Upload /></el-icon> 上传公钥</el-button>
                </el-form-item>
              </el-form>
            </div>
          </el-card>

          <el-card class="lhs-card mt-14" shadow="hover">
            <h3 class="lhs-title"><el-icon><Tickets /></el-icon> 实时调用日志</h3>
            <el-timeline>
              <el-timeline-item
                v-for="(log, i) in apiLogs" :key="i"
                :timestamp="log.ts" placement="top"
                :color="log.status < 300 ? '#10b981' : (log.status < 500 ? '#f59e0b' : '#ef4444')"
              >
                <div class="log-line">
                  <span :class="['method-pill', log.method.toLowerCase()]">{{ log.method }}</span>
                  <span class="log-path muted small">{{ log.path }}</span>
                </div>
                <div class="log-meta small muted">
                  <b :class="log.status < 300 ? 'ok' : (log.status < 500 ? 'warn' : 'bad')">{{ log.status }}</b>
                  · {{ log.latency }}ms · {{ log.ip }}
                </div>
              </el-timeline-item>
            </el-timeline>
          </el-card>

          <el-card class="lhs-card mt-14" shadow="hover">
            <h3 class="lhs-title"><el-icon><Document /></el-icon> SDK & 文档</h3>
            <ul class="sdk-list">
              <li><el-icon><Link /></el-icon> <b>OpenAPI 规范</b> <span class="muted small">(openapi.json)</span>
                <el-button link size="small" @click="copy(baseURL + '/openapi.json')">复制链接</el-button>
              </li>
              <li><el-icon><Link /></el-icon> <b>Swagger UI 在线调试</b>
                <el-button link size="small" @click="openExt(baseURL + '/docs')">打开</el-button>
              </li>
              <li><el-icon><Link /></el-icon> <b>ReDoc 文档</b>
                <el-button link size="small" @click="openExt(baseURL + '/redoc')">打开</el-button>
              </li>
              <li><el-icon><Reading /></el-icon> <b>Postman Collection</b> <span class="muted small">v2.1</span></li>
              <li><el-icon><ChatDotRound /></el-icon> <b>开发者社区</b> <span class="muted small">Discord / QQ群</span></li>
            </ul>
          </el-card>
        </div>
      </el-col>

      <!-- 右列：Tab 页 API 分类 -->
      <el-col :span="17">
        <el-card shadow="never" class="rhs-card">
          <el-tabs v-model="tab" class="api-tabs" type="card">
            <!-- 0. 快速开始 -->
            <el-tab-pane name="start">
              <template #label><el-icon><Odometer /></el-icon> 快速开始</template>
              <section class="doc-section">
                <h3 class="sec-h">① 基础 URL（两种前缀均可）</h3>
                <p class="muted">所有接口同时挂载在 <b>/api</b> 与 <b>/v1</b> 两个前缀下（以及无前缀根路径），调用时任选其一即可：</p>
                <code-block :code="codeBaseUrl" />
              </section>

              <section class="doc-section">
                <h3 class="sec-h">② 认证（JWT / Bearer Token）</h3>
                <p class="muted">
                  登录接口 <code class="inline-code">POST /auth/login</code> 成功后返回 <code class="inline-code">accessToken</code>，
                  后续所有需登录接口请在 HTTP Header 中携带：
                </p>
                <code-block title="请求头" :code="codeAuthHeaders" />
                <code-block title="cURL 示例" :code="codeAuthCurl" />
              </section>

              <section class="doc-section">
                <h3 class="sec-h">③ 统一响应结构</h3>
                <p class="muted">所有接口统一返回 <code class="inline-code">{ code, message, data }</code> 三段式 JSON：</p>
                <code-block title="200 OK" :code="codeRespOk200" />
                <el-table :data="respCodes" size="small" border class="mt-10">
                  <el-table-column prop="code" label="code" width="80" />
                  <el-table-column prop="meaning" label="含义" width="260" />
                  <el-table-column prop="desc" label="说明" />
                </el-table>
              </section>

              <section class="doc-section">
                <h3 class="sec-h">④ 错误码 & 限流</h3>
                <el-table :data="errorCodes" size="small" border>
                  <el-table-column prop="http" label="HTTP" width="80" />
                  <el-table-column prop="code" label="业务 code" width="110" />
                  <el-table-column prop="meaning" label="含义" />
                  <el-table-column prop="how" label="如何处理" />
                </el-table>
                <p class="muted mt-10">
                  限流：默认 <b>120 次 / 分钟 / IP</b>；超限返回 <code class="inline-code">429 Too Many Requests</code>，请退避重试（指数退避推荐）。
                </p>
              </section>

              <section class="doc-section">
                <h3 class="sec-h">⑤ 角色 & 权限一览（RBAC）</h3>
                <el-table :data="rolesTable" size="small" border>
                  <el-table-column prop="role" label="角色 code" width="140" />
                  <el-table-column prop="name" label="显示名" width="130" />
                  <el-table-column prop="perms" label="权限范围" />
                </el-table>
              </section>
            </el-tab-pane>

            <!-- 1. 根路径与统计 -->
            <el-tab-pane name="root">
              <template #label><el-icon><DataBoard /></el-icon> 根路径 & 统计</template>
              <api-catalog :list="rootApis" :env="env" />
            </el-tab-pane>

            <!-- 2. 认证 -->
            <el-tab-pane name="auth">
              <template #label><el-icon><Avatar /></el-icon> 认证 Auth</template>
              <api-catalog :list="authApis" :env="env" />
            </el-tab-pane>

            <!-- 3. 云服务器 -->
            <el-tab-pane name="servers">
              <template #label><el-icon><Monitor /></el-icon> 云服务器 Servers</template>
              <p class="muted sec-lead">购买后由 Lisa 主机 API 交付的云服务器实例；支持重启 / 重装 / 查询 / 续费。</p>
              <api-catalog :list="serverApis" :env="env" />
            </el-tab-pane>

            <!-- 4. 接入实例 -->
            <el-tab-pane name="access">
              <template #label><el-icon><Connection /></el-icon> 接入实例 Access</template>
              <p class="muted sec-lead">
                访问入口（接入实例）资源；接口同时挂载在 <code class="inline-code">/proxies/*</code> 与 <code class="inline-code">/access/*</code>。
              </p>
              <api-catalog :list="accessApis" :env="env" />
            </el-tab-pane>

            <!-- 5. 订单 -->
            <el-tab-pane name="orders">
              <template #label><el-icon><Tickets /></el-icon> 订单 Orders</template>
              <api-catalog :list="orderApis" :env="env" />
            </el-tab-pane>

            <!-- 6. 支付 -->
            <el-tab-pane name="payments">
              <template #label><el-icon><Wallet /></el-icon> 支付 Payments</template>
              <p class="muted sec-lead">
                支持余额 / 模拟 / 支付宝 / 微信 / USDT (TRC20) / PayPal v2 Orders；支付成功将触发 <b>Lisa主机下单 → 部署流水线 → 回调保存结果</b>。
              </p>
              <api-catalog :list="payApis" :env="env" />
            </el-tab-pane>

            <!-- 7. 部署任务 -->
            <el-tab-pane name="deploy">
              <template #label><el-icon><UploadFilled /></el-icon> 部署 Deploy</template>
              <p class="muted sec-lead">deploy-init.sh 远程主机初始化部署进度查询 / 日志查看 / 重试；<b>/internal/deploy/notify</b> 为回调接口。</p>
              <api-catalog :list="deployApis" :env="env" />
            </el-tab-pane>

            <!-- 8. 系统配置 -->
            <el-tab-pane name="config">
              <template #label><el-icon><Setting /></el-icon> 系统配置 Config</template>
              <api-catalog :list="configApis" :env="env" />
            </el-tab-pane>

            <!-- 9. 检测中心 -->
            <el-tab-pane name="check">
              <template #label><el-icon><ZoomIn /></el-icon> 检测中心 Check</template>
              <api-catalog :list="checkApis" :env="env" />
            </el-tab-pane>

            <!-- 10. 反馈工单 -->
            <el-tab-pane name="fb">
              <template #label><el-icon><ChatLineSquare /></el-icon> 反馈工单</template>
              <api-catalog :list="fbApis" :env="env" />
            </el-tab-pane>

            <!-- 11. 系统管理 -->
            <el-tab-pane name="sys">
              <template #label><el-icon><User /></el-icon> 系统管理 System</template>
              <p class="muted sec-lead">需要 <code class="inline-code">super_admin / admin / finance / support</code> 等管理员角色调用。</p>
              <api-catalog :list="sysApis" :env="env" />
            </el-tab-pane>

            <!-- 12. Webhook -->
            <el-tab-pane name="webhook">
              <template #label><el-icon><Bell /></el-icon> Webhook 事件</template>
              <section class="doc-section">
                <h3 class="sec-h">异步事件回调</h3>
                <p class="muted">
                  当订单支付成功、云服务器交付、部署完成、余额变动等事件发生时，平台将以 <b>POST JSON</b> 方式推送到您配置的 URL，
                  并使用 <code class="inline-code">X-MetoE-Signature</code> 做 HMAC-SHA256 签名校验。
                </p>
                <el-form label-width="90px" class="mt-12">
                  <el-form-item label="Webhook URL">
                    <el-input v-model="webhook.url" placeholder="https://your-server.com/webhook/metoe" />
                  </el-form-item>
                  <el-form-item label="Secret">
                    <el-input v-model="webhook.secret" placeholder="用于 HMAC 签名，建议 32+ 位随机" show-password type="password" />
                    <el-button link size="small" @click="webhook.secret=randomStr(32)">随机生成</el-button>
                  </el-form-item>
                  <el-form-item label="订阅事件">
                    <el-checkbox-group v-model="webhook.events">
                      <el-checkbox value="order.created">订单创建</el-checkbox>
                      <el-checkbox value="order.paid">订单支付成功</el-checkbox>
                      <el-checkbox value="server.created">云服务器交付</el-checkbox>
                      <el-checkbox value="access.created">接入实例创建</el-checkbox>
                      <el-checkbox value="deploy.success">部署成功</el-checkbox>
                      <el-checkbox value="deploy.failed">部署失败</el-checkbox>
                      <el-checkbox value="access.expired">接入实例到期</el-checkbox>
                      <el-checkbox value="balance.changed">余额变动</el-checkbox>
                    </el-checkbox-group>
                  </el-form-item>
                  <el-form-item>
                    <el-button type="primary">保存 Webhook</el-button>
                    <el-button @click="sendTestWebhook">发送测试</el-button>
                  </el-form-item>
                </el-form>
                <h3 class="sec-h mt-20">请求示例 & 签名校验</h3>
                <code-block title="Webhook POST 请求头" :code="codeWebhookHeaders" />
                <code-block title="HMAC-SHA256 签名（Node.js）" :code="codeHmacJs" />
              </section>
            </el-tab-pane>
          </el-tabs>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, reactive, computed, defineComponent, h, resolveComponent } from 'vue'
import { ElMessage } from 'element-plus'
import {
  MagicStick, Key, Refresh, Plus, Upload, Tickets, Document, Link, Reading, ChatDotRound,
  Odometer, DataBoard, Avatar, Monitor, Connection, Wallet, UploadFilled, Setting,
  ZoomIn, ChatLineSquare, User, Bell, Notebook, CircleCheckFilled
} from '@element-plus/icons-vue'

const env = ref('dev')
const tab = ref('start')
const baseURL = computed(() => ({
  dev: 'http://localhost:3000',
  staging: 'https://stg-api.metoe.io',
  prod: 'https://api.metoe.io'
}[env.value]))

const codeBaseUrl = computed(() => `# 本地开发
${baseURL.value}/auth/login
${baseURL.value}/api/auth/login
${baseURL.value}/v1/auth/login`)
const codeAuthHeaders = `Authorization: Bearer <accessToken>
Content-Type: application/json`
const codeAuthCurl = computed(() => `curl '${baseURL.value}/servers?page=1&pageSize=20' \\
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'`)
const codeRespOk200 = `{
  "code": 0,          // 0 = 成功；非 0 = 失败
  "message": "ok",
  "data": {
    "items": [],
    "total": 0,
    "page": 1,
    "pageSize": 20
  }
}`
const codeWebhookHeaders = `POST /webhook/metoe HTTP/1.1
Host: your-server.com
Content-Type: application/json
X-MetoE-Event: order.paid
X-MetoE-Delivery: evt_20260720_a1b2c3d4
X-MetoE-Timestamp: 1784534400
X-MetoE-Signature: t=1784534400,v1=8f3a9c...

{ "orderNo": "PO2026072000123", "amount": 198.00, ... }`
const codeHmacJs = `const crypto = require('crypto');
function verifySignature(body, timestamp, signature, secret) {
  const payload = timestamp + '.' + body;
  const expected = 't=' + timestamp + ',v1=' +
    crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}`


const apiKey = ref('metoe_sk_' + Math.random().toString(36).slice(2, 22))
const newKeyName = ref('Production-Server')
const keyScopes = ref(['access:read', 'servers:read', 'orders:read', 'check:run'])

const webhook = reactive({
  url: '',
  secret: '',
  events: ['order.paid', 'deploy.success', 'balance.changed']
})
function randomStr(len = 32) {
  const c = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.'
  let s = ''
  for (let i = 0; i < len; i++) s += c[Math.floor(Math.random() * c.length)]
  return s
}
function sendTestWebhook() { ElMessage.success('已向 ' + (webhook.url || '(未填写 URL)') + ' 发送测试事件') }

const apiLogs = [
  { ts: '2026-07-20 14:32:18', method: 'GET', path: '/v1/servers', status: 200, latency: 42, ip: '103.120.45.22' },
  { ts: '2026-07-20 14:31:05', method: 'POST', path: '/v1/payments/create', status: 200, latency: 138, ip: '103.120.45.22' },
  { ts: '2026-07-20 14:29:41', method: 'GET', path: '/v1/proxies?country=US', status: 200, latency: 29, ip: '103.120.45.22' },
  { ts: '2026-07-20 14:28:12', method: 'DELETE', path: '/v1/servers/999', status: 404, latency: 15, ip: '103.120.45.22' },
  { ts: '2026-07-20 14:27:01', method: 'POST', path: '/v1/check/ip', status: 429, latency: 6, ip: '103.120.45.22' },
  { ts: '2026-07-20 14:26:33', method: 'PUT', path: '/v1/auth/profile', status: 200, latency: 21, ip: '103.120.45.22' }
]

const respCodes = [
  { code: 0, meaning: '成功', desc: '业务执行成功，data 中返回有效数据。' },
  { code: 400, meaning: '参数错误', desc: '请求参数不符合校验规则，message 会给出具体原因。' },
  { code: 401, meaning: '未认证', desc: 'Token 缺失 / 过期 / 伪造，需重新登录。' },
  { code: 403, meaning: '无权限', desc: '当前账号角色缺少对应 permission。' },
  { code: 404, meaning: '资源不存在', desc: '指定 ID / 订单号 / 资源不存在。' },
  { code: 409, meaning: '状态冲突', desc: '重复支付、资源已释放等冲突。' },
  { code: 500, meaning: '服务端异常', desc: '内部错误，message 中包含错误原因。' }
]
const errorCodes = [
  { http: 200, code: 0, meaning: 'OK', how: '正常读取 data 字段。' },
  { http: 400, code: 400, meaning: 'Bad Request', how: '检查 message 并修正请求参数。' },
  { http: 401, code: 401, meaning: 'Unauthorized', how: '重新调用 /auth/login 获取新 Token。' },
  { http: 403, code: 403, meaning: 'Forbidden', how: '为账号申请对应 RBAC 权限或角色。' },
  { http: 404, code: 404, meaning: 'Not Found', how: '确认资源 ID / URL 拼写。' },
  { http: 429, code: 429, meaning: 'Too Many Requests', how: '指数退避重试 (1s→2s→4s→8s…)。' },
  { http: 500, code: 500, meaning: 'Internal Error', how: '提交工单并携带 X-Request-Id。' }
]
const rolesTable = [
  { role: 'super_admin', name: '超级管理员', perms: '* 全部权限（系统/订单/财务/支持）' },
  { role: 'admin', name: '运营管理员', perms: 'system:users:view / orders:manage / servers:manage / feedback:manage / config:view' },
  { role: 'finance', name: '财务人员', perms: 'payment:view / orders:view / recharge 充值 / billing export' },
  { role: 'support', name: '客服支持', perms: 'feedback:manage / orders:view / users:view' },
  { role: 'user', name: '普通用户', perms: '自助：云服务器/接入实例/订单/支付/检测/反馈（仅本人数据）' }
]

function copy(s) {
  navigator.clipboard?.writeText(String(s))
  ElMessage.success('已复制到剪贴板')
}
function regenerate() {
  ElMessage.warning('旧 Key 已失效，请及时更新至业务代码')
  apiKey.value = 'metoe_sk_' + Math.random().toString(36).slice(2, 22)
}
function openExt(url) { window.open(url, '_blank', 'noopener') }

/* =========================================================
 * 子组件 1：code-block（带拷贝按钮）
 * ========================================================= */
const CodeBlock = defineComponent({
  name: 'CodeBlock',
  props: { code: { type: String, required: true }, title: { type: String, default: '' } },
  setup(props) {
    const copied = ref(false)
    const onCopy = () => {
      navigator.clipboard?.writeText(props.code)
      copied.value = true
      setTimeout(() => copied.value = false, 1500)
    }
    return () => h('div', { class: 'code-block-wrap' }, [
      props.title && h('div', { class: 'cb-header' }, [
        h('span', { class: 'cb-title' }, props.title),
        h(resolveComponent('el-button'), {
          size: 'small', link: true, onClick: onCopy
        }, () => [h(resolveComponent('el-icon'), () => [h(copied.value ? CircleCheckFilled : Link)]), copied.value ? '已复制' : '复制'])
      ]),
      h('pre', { class: 'cb-body' }, [h('code', props.code)])
    ])
  }
})

/* =========================================================
 * 子组件 2：ApiCatalog —— 可折叠 API 卡片列表
 * ========================================================= */
const ApiCatalog = defineComponent({
  name: 'ApiCatalog',
  props: { list: { type: Array, required: true }, env: { type: String, default: 'dev' } },
  setup(props) {
    const open = ref({})
    const base = computed(() => ({ dev: 'http://localhost:3000', staging: 'https://stg-api.metoe.io', prod: 'https://api.metoe.io' }[props.env]))
    const toggle = (i) => { open.value[i] = !open.value[i] }
    const copy = (s) => { navigator.clipboard?.writeText(s); ElMessage.success('已复制') }
    const methodColor = (m) => ({
      GET: '#10b981', POST: '#2563eb', PUT: '#f59e0b', PATCH: '#8b5cf6', DELETE: '#ef4444'
    }[m] || '#64748b')
    const resolve = (name) => resolveComponent(name)

    return () => h('div', { class: 'api-catalog' }, props.list.map((api, idx) => {
      const isOpen = !!open.value[idx]
      const full = base.value + api.path
      return h('div', { class: 'api-card', key: idx }, [
        // Header
        h('div', { class: 'api-head', onClick: () => toggle(idx) }, [
          h('span', {
            class: 'm-pill',
            style: { background: methodColor(api.method) }
          }, api.method),
          h('code', { class: 'm-path' }, api.path),
          h('span', { class: 'm-title' }, api.title),
          api.auth === false
            ? h(resolveComponent('el-tag'), { size: 'small', type: 'info', effect: 'plain', class: 'm-tag' }, '公开')
            : h(resolveComponent('el-tag'), { size: 'small', type: 'warning', effect: 'plain', class: 'm-tag' }, '🔒 Bearer'),
          h('span', { class: 'm-arrow' }, isOpen ? '▲' : '▼'),
        ]),
        // Body
        isOpen && h('div', { class: 'api-body' }, [
          h('p', { class: 'api-desc' }, api.desc),
          // URL + 复制
          h('div', { class: 'url-row' }, [
            h('input', { class: 'url-input', readonly: true, value: full }),
            h('button', { class: 'url-copy', onClick: () => copy(full) }, [h(resolveComponent('el-icon'), () => [h(Link)]), ' 复制 URL'])
          ]),
          // 参数表
          api.params && api.params.length && h(resolveComponent('el-table'), {
            data: api.params, size: 'small', border: true, class: 'api-table'
          }, () => [
            h(resolveComponent('el-table-column'), { prop: 'name', label: '参数', width: 150 }),
            h(resolveComponent('el-table-column'), { prop: 'in', label: '位置', width: 90 }),
            h(resolveComponent('el-table-column'), { prop: 'type', label: '类型', width: 120 }),
            h(resolveComponent('el-table-column'), {
              label: '必填', width: 70,
              formatter: (r) => r.required ? (h('span', { class: 'red' }, '是')) : '否'
            }),
            h(resolveComponent('el-table-column'), { prop: 'desc', label: '说明' })
          ]),
          // Request Body
          api.body && h('div', { class: 'sub-section' }, [
            h('div', { class: 'sub-title' }, [h(resolveComponent('el-icon'), () => [h(Notebook)]), ' 请求体 JSON']),
            h(CodeBlock, { code: api.body, title: 'Request Body (application/json)' })
          ]),
          // cURL
          api.curl && h('div', { class: 'sub-section' }, [
            h('div', { class: 'sub-title' }, [h(resolveComponent('el-icon'), () => [h(Link)]), ' cURL 示例']),
            h(CodeBlock, { code: api.curl.replace(/\$\{BASE\}/g, base.value), title: 'cURL' })
          ]),
          // Response
          api.response && h('div', { class: 'sub-section' }, [
            h('div', { class: 'sub-title' }, [h(resolveComponent('el-tag'), {
              size: 'small', type: 'success', effect: 'dark'
            }, () => '200 OK'), ' 响应示例']),
            h(CodeBlock, { code: api.response, title: 'Response' })
          ]),
          api.errors && api.errors.length && h(resolveComponent('el-alert'), {
            type: 'warning', showIcon: true, class: 'mt-10', title: '常见业务错误'
          }, {
            default: () => h('ul', { class: 'err-list' }, api.errors.map(e => h('li', [
              h('b', { class: 'red' }, e.code), ' · ', e.scenario, ' —— ', e.how
            ])))
          })
        ])
      ])
    }))
  }
})

/* =========================================================
 * API 数据集
 * ========================================================= */
const rootApis = [
  {
    method: 'GET', path: '/', title: '平台信息 & 登录提示', auth: false,
    desc: '返回平台名、版本号、访问时间、Swagger 文档链接以及默认的测试账号/密码（仅开发环境）。',
    params: [],
    curl: `curl \${BASE}/`,
    response: `{
  "name": "MetoE 全球云服务器管理平台",
  "version": "1.0.0",
  "time": "2026-07-20 15:04:05",
  "docs": "/docs (Swagger UI)",
  "health": "ok",
  "notes": [
    "登录账号：admin / 123456 (超级管理员)   demo / 123456 (普通用户)",
    "前端 metoe 访问后端：Vite 已配置代理 '/api' -> http://localhost:3000"
  ]
}`
  },
  {
    method: 'GET', path: '/health', title: '健康检查', auth: false,
    desc: '应用启动时间 / DB 连通性 / SQLite 文件路径。用于 LB 健康检查与 uptime 监控。',
    params: [],
    curl: `curl \${BASE}/health`,
    response: `{
  "code": 0,
  "message": "ok",
  "data": {
    "status": "ok",
    "uptime_s": 86403.1,
    "db": true,
    "db_path": "/app/data/metoe.db"
  }
}`
  },
  {
    method: 'GET', path: '/stats/summary', title: '仪表盘汇总统计', auth: true,
    desc: 'Dashboard 顶部卡片数据：用户数 / 接入实例数 / 订单数 / 云服务器数 / 部署任务数 / 支付数 / 总金额 / 各国家分布。仅 super_admin 看到全局维度，普通用户仅能看到自己名下数据。',
    params: [],
    curl: `curl \${BASE}/stats/summary \\
  -H 'Authorization: Bearer TOKEN'`,
    response: `{
  "code": 0,
  "data": {
    "users": 128,
    "proxies": 512,
    "active_proxies": 498,
    "orders": 1042,
    "paid_orders": 988,
    "servers": 86,
    "deploys": 93,
    "success_deploy": 88,
    "running_deploy": 2,
    "payments": 1021,
    "total_paid_amount": 198832.58,
    "balance": 1234.56,
    "country_counts": [
      { "code": "US", "name": "美国", "flag": "🇺🇸", "count": 312 }
    ]
  }
}`
  }
]

const authApis = [
  {
    method: 'POST', path: '/auth/register', title: '注册新用户', auth: false,
    desc: '用户名 / 邮箱 + 密码 注册；可选手机号 / 微信 / QQ。注册成功后自动发放初始角色（默认 user）与初始余额。',
    params: [],
    body: `{
  "username": "alice_2026",
  "email": "alice@example.com",
  "password": "S3cret~!",
  "phone": "13800138000",
  "wechat": "wx_alice_001",
  "qq": "10086"
}`,
    curl: `curl -X POST \${BASE}/auth/register \\
  -H 'Content-Type: application/json' \\
  -d '{"username":"alice_2026","email":"alice@example.com","password":"S3cret~!"}'`,
    response: `{
  "code": 0,
  "message": "注册成功",
  "data": {
    "userId": 1024,
    "username": "alice_2026",
    "defaultRole": "user",
    "initialBalance": 0.0
  }
}`,
    errors: [
      { code: 400, scenario: '用户名已存在 / 邮箱已被注册 / 密码 <6 位', how: '更换用户名 / 找回密码' },
      { code: 400, scenario: '用户名格式不合法（仅允许 3-20 位字母数字下划线）', how: '修正后重试' }
    ]
  },
  {
    method: 'POST', path: '/auth/login', title: '登录换取 Token', auth: false,
    desc: '用户名 + 密码；成功返回 accessToken（JWT，默认 7 天有效）+ 用户资料 + 角色权限树。',
    params: [],
    body: `{ "username": "admin", "password": "123456" }`,
    curl: `curl -X POST \${BASE}/auth/login \\
  -H 'Content-Type: application/json' \\
  -d '{"username":"demo","password":"123456"}'`,
    response: `{
  "code": 0,
  "message": "登录成功",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "tokenType": "Bearer",
    "expiresIn": 604800,
    "user": {
      "id": 2, "username": "demo", "email": "demo@metoe.io",
      "roles": ["user"], "permissions": ["dashboard:view","orders:create"]
    }
  }
}`,
    errors: [
      { code: 401, scenario: '用户名不存在 / 密码错误', how: '找回密码 / 使用 demo/123456 测试' },
      { code: 423, scenario: '账号被锁定（连续失败超过 10 次）', how: '15 分钟后重试或联系客服解锁' }
    ]
  },
  {
    method: 'POST', path: '/auth/logout', title: '注销当前会话', auth: true,
    desc: '后端记录该 Token 进入黑名单（可选，JWT 本身无状态；用于服务端记录审计）。',
    curl: `curl -X POST \${BASE}/auth/logout -H 'Authorization: Bearer TOKEN'`,
    response: `{ "code": 0, "message": "已退出", "data": null }`
  },
  {
    method: 'GET', path: '/auth/profile', title: '读取当前用户资料', auth: true,
    desc: '返回账号基本信息 + 角色 + 权限 + 子账号列表。',
    curl: `curl \${BASE}/auth/profile -H 'Authorization: Bearer TOKEN'`,
    response: `{
  "code": 0,
  "data": {
    "id": 2, "username": "demo",
    "email": "demo@metoe.io", "phone": "138****8000",
    "wechat": "wx_xxx", "qq": "10086",
    "balance": 998.5,
    "roles": ["user"],
    "permissions": ["dashboard:view","orders:create","orders:view"]
  }
}`
  },
  {
    method: 'PUT', path: '/auth/profile', title: '修改联系信息', auth: true,
    desc: '修改手机号 / 邮箱 / 微信 / QQ；邮箱修改需要二次确认（接口内部校验格式）。',
    body: `{ "phone": "13900139000", "wechat": "new_wx", "email": "new@ex.com" }`,
    curl: `curl -X PUT \${BASE}/auth/profile \\
  -H 'Authorization: Bearer TOKEN' \\
  -H 'Content-Type: application/json' \\
  -d '{"phone":"13900139000","qq":"123456"}'`,
    response: `{ "code": 0, "message": "资料已更新" }`
  },
  {
    method: 'PUT', path: '/auth/password', title: '修改密码', auth: true,
    desc: '输入旧密码 + 新密码（6-64 位）；修改成功后当前 Token 立即失效，需要重新登录。',
    body: `{ "old": "123456", "password": "NewP@ssW0rd" }`,
    curl: `curl -X PUT \${BASE}/auth/password \\
  -H 'Authorization: Bearer TOKEN' \\
  -H 'Content-Type: application/json' \\
  -d '{"old":"123456","password":"NewP@ssW0rd"}'`,
    errors: [
      { code: 401, scenario: 'old 密码不匹配', how: '使用“忘记密码”流程或联系客服重置' }
    ],
    response: `{ "code": 0, "message": "密码已更新，请重新登录" }`
  }
]

const serverApis = [
  {
    method: 'GET', path: '/servers', title: '分页获取云服务器列表', auth: true,
    desc: '返回我名下所有云服务器实例；支持按状态 / 区域 / 关键字过滤，管理员可 all=1 看到全局。',
    params: [
      { name: 'page', in: 'query', type: 'int', required: false, desc: '页码，默认 1' },
      { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '每页条数，默认 20' },
      { name: 'status', in: 'query', type: 'string', required: false, desc: 'pending / running / stopped / error' },
      { name: 'region', in: 'query', type: 'string', required: false, desc: '如 us-east-1 / eu-west-2' },
      { name: 'keyword', in: 'query', type: 'string', required: false, desc: '模糊匹配 IP / hostname / spec / orderNo' },
      { name: 'all', in: 'query', type: 'string', required: false, desc: '1 = 查询全部（仅 super_admin）' }
    ],
    curl: `curl "\${BASE}/servers?page=1&pageSize=20&status=running" \\
  -H 'Authorization: Bearer TOKEN'`,
    response: `{
  "code": 0,
  "data": {
    "total": 12,
    "page": 1, "pageSize": 20,
    "items": [
      {
        "id": 5001, "userId": 2, "orderId": 8811,
        "serverId": "lisa-20260720-a1b2",
        "provider": "lisa", "region": "US · 洛杉矶",
        "spec": "4C8G50G", "ip": "104.28.12.89", "ipv6": null,
        "sshPort": 22, "sshUser": "root", "sshPassword": "***",
        "os": "Ubuntu 22.04 LTS",
        "cpuCores": 4, "ramGb": 8, "diskGb": 50,
        "bandwidthMbps": 30, "trafficGb": 2000,
        "status": "running",
        "expireAt": "2026-08-20 14:35:00"
      }
    ]
  }
}`
  },
  {
    method: 'GET', path: '/servers/{sid}', title: '云服务器详情', auth: true,
    desc: '按 ID 查询单台云服务器的完整信息；如果不是本人且非管理员，敏感字段（密码 / 私钥）自动打码。',
    params: [{ name: 'sid', in: 'path', type: 'int', required: true, desc: '服务器 ID' }],
    curl: `curl \${BASE}/servers/5001 -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'POST', path: '/servers/{sid}/reboot', title: '重启主机', auth: true,
    desc: '调用 Lisa 主机模拟重启接口；返回任务 ID，状态将在 30-90 秒内更新。',
    params: [{ name: 'sid', in: 'path', type: 'int', required: true, desc: '服务器 ID' }],
    curl: `curl -X POST \${BASE}/servers/5001/reboot -H 'Authorization: Bearer TOKEN'`,
    response: `{ "code": 0, "data": { "taskId": "RBT-889901", "expectedSec": 60 } }`
  },
  {
    method: 'POST', path: '/servers/{sid}/reinstall', title: '重装操作系统', auth: true,
    desc: '恢复出厂；所有数据将被清空（危险操作）。默认重装为 Ubuntu 22.04 LTS。',
    params: [{ name: 'sid', in: 'path', type: 'int', required: true, desc: '服务器 ID' }],
    curl: `curl -X POST \${BASE}/servers/5001/reinstall -H 'Authorization: Bearer TOKEN'`,
    response: `{ "code": 0, "data": { "taskId": "RI-20260720001", "newOs": "Ubuntu 22.04 LTS" } }`
  }
]

const accessApis = [
  {
    method: 'GET', path: '/access/country-tree', title: '获取可选国家 & 地区树', auth: true,
    desc: '购买页面左侧分组：热门 / 美洲 / 欧洲 / 亚洲 / 大洋洲 / 拉美 / 非洲。',
    curl: `curl \${BASE}/access/country-tree -H 'Authorization: Bearer TOKEN'`,
    response: `{
  "code": 0,
  "data": [
    {
      "group": "热门地区",
      "items": [
        { "code": "US", "name": "美国", "flag": "🇺🇸", "stock": 12800, "priceBase": 29 },
        { "code": "JP", "name": "日本", "flag": "🇯🇵", "stock": 8400, "priceBase": 32 }
      ]
    }
  ]
}`
  },
  {
    method: 'GET', path: '/access/prices', title: '获取价格方案', auth: true,
    desc: '根据 category 分类（ISP/机房住宅/移动 4G）返回 5 款套餐 + 对应价格因子。',
    params: [
      { name: 'category', in: 'query', type: 'string', required: false, desc: 'ISP (默认) / DC / MOBILE' }
    ],
    curl: `curl "\${BASE}/access/prices?category=ISP" -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'GET', path: '/access', title: '接入实例列表', auth: true,
    desc: '返回我名下接入实例。',
    params: [
      { name: 'page', in: 'query', type: 'int', required: false, desc: '默认 1' },
      { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '默认 20' },
      { name: 'country', in: 'query', type: 'string', required: false, desc: 'US / JP / ... 精确过滤' },
      { name: 'type', in: 'query', type: 'string', required: false, desc: 'SOCKS5 / HTTP / SSH_RDP' },
      { name: 'status', in: 'query', type: 'string', required: false, desc: 'active / expired / pending' }
    ],
    curl: `curl "\${BASE}/access?country=US&status=active&page=1" -H 'Authorization: Bearer TOKEN'`,
    response: `{
  "code": 0,
  "data": {
    "total": 3,
    "items": [
      {
        "id": 1001, "country": "US", "city": "Los Angeles",
        "ip": "104.28.12.89", "port": 10800,
        "protocol": "SOCKS5",
        "username": "u_alice", "password": "******",
        "expireAt": "2026-08-20 14:35:00", "status": "active"
      }
    ]
  }
}`
  },
  {
    method: 'GET', path: '/access/{id}', title: '接入实例详情', auth: true,
    desc: '按 ID 查询单个接入实例完整信息（含连接 URL、二维码 base64）。',
    params: [{ name: 'id', in: 'path', type: 'int', required: true, desc: '实例 ID' }],
    curl: `curl \${BASE}/access/1001 -H 'Authorization: Bearer TOKEN'`
  }
]

const orderApis = [
  {
    method: 'GET', path: '/orders', title: '订单列表', auth: true,
    params: [
      { name: 'page', in: 'query', type: 'int', required: false, desc: '页码' },
      { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '每页 20' },
      { name: 'status', in: 'query', type: 'string', required: false, desc: 'pending / paid / failed / refunded / cancelled' },
      { name: 'keyword', in: 'query', type: 'string', required: false, desc: '订单号 / 产品名 模糊' },
      { name: 'all', in: 'query', type: 'string', required: false, desc: '1=全部 (管理员)' }
    ],
    curl: `curl "\${BASE}/orders?status=paid&page=1" -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'GET', path: '/orders/{orderNo}', title: '订单详情', auth: true,
    desc: '返回订单主体 + 关联云服务器数组 + 关联接入实例数组 + 支付记录数组。',
    params: [{ name: 'orderNo', in: 'path', type: 'string', required: true, desc: '订单号，如 PO202607200001' }],
    curl: `curl \${BASE}/orders/PO202607200001 -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'POST', path: '/orders/{orderNo}/pay', title: '订单支付入口', auth: true,
    desc: '兼容旧路径；建议统一改为 /payments/create。当 channel 为 balance 且余额充足会直接扣款并触发交付流水线。',
    params: [{ name: 'orderNo', in: 'path', type: 'string', required: true, desc: '订单号' }],
    body: `{ "channel": "balance" }`,
    curl: `curl -X POST \${BASE}/orders/PO202607200001/pay \\
  -H 'Authorization: Bearer TOKEN' \\
  -H 'Content-Type: application/json' \\
  -d '{"channel":"balance"}'`
  },
  {
    method: 'PUT', path: '/orders/{id}/status', title: '管理员修改订单状态', auth: true,
    desc: '仅 orders:manage 权限可用（运营/超管）。手工标记 paid / cancelled / refunded 等。',
    params: [{ name: 'id', in: 'path', type: 'int', required: true, desc: '订单 ID' }],
    body: `{ "status": "cancelled", "remark": "用户主动取消" }`
  }
]

const payApis = [
  {
    method: 'POST', path: '/payments/create', title: '创建支付单（统一入口）', auth: true,
    desc: '所有支付方式统一入口：根据 channel 返回对应参数（USDT 返回钱包地址 + 金额 + 过期时间；PayPal 返回官方 approve_url；微信/支付宝返回 qrCode 或 payUrl）。',
    body: `{
  "order_id": 8811,
  "order_no": "PO202607200001",
  "channel": "balance",
  "return_url": "https://your-site.com/orders/PO202607200001/done",
  "cancel_url": "https://your-site.com/orders/PO202607200001/cancel"
}`,
    params: [],
    curl: `curl -X POST \${BASE}/payments/create \\
  -H 'Authorization: Bearer TOKEN' -H 'Content-Type: application/json' \\
  -d '{
    "order_no":"PO202607200001",
    "channel":"wechat",
    "return_url":"https://your-site.com/orders/PO202607200001/done"
  }'`,
    response: `{
  "code": 0,
  "data": {
    "payNo": "PAY20260720000991",
    "channel": "wechat",
    "amount": 198.00,
    "currency": "CNY",
    "qrCode": "weixin://wxpay/bizpayurl?pr=XXXX",
    "qrImgBase64": "data:image/png;base64,iVBORw0KGgo...",
    "expireAt": "2026-07-20 15:20:00"
  }
}`,
    errors: [
      { code: 409, scenario: '订单已支付 / 已取消', how: '不要重复创建，直接跳转到订单详情页' },
      { code: 402, scenario: '余额不足（channel=balance）', how: '先调用充值或切换其他渠道' }
    ]
  },
  {
    method: 'GET', path: '/payments/mock-confirm', title: '模拟支付确认（测试）', auth: false,
    desc: '适用于 mock / alipay / wechat / usdt / paypal 所有渠道的演示付款：直接把 payNo 标记为 success，等价于用户点击了“我已付款”。',
    params: [{ name: 'pay_no', in: 'query', type: 'string', required: true, desc: '支付单号' }],
    curl: `curl "\${BASE}/payments/mock-confirm?pay_no=PAY20260720000991"`
  },
  {
    method: 'GET', path: '/payments/list', title: '支付流水列表', auth: true,
    params: [
      { name: 'page', in: 'query', type: 'int', required: false, desc: '' },
      { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '' }
    ],
    curl: `curl "\${BASE}/payments/list?page=1" -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'GET', path: '/payments/{payNo}', title: '支付详情', auth: true,
    params: [{ name: 'payNo', in: 'path', type: 'string', required: true, desc: '支付单号' }],
    curl: `curl \${BASE}/payments/PAY20260720000991 -H 'Authorization: Bearer TOKEN'`
  },
  // PayPal
  {
    method: 'POST', path: '/payments/paypal/v2/orders', title: 'PayPal v2 创建订单', auth: false,
    desc: '与官方 PayPal Orders v2 API 同构：前端 @paypal/js-sdk 可直接通过 fetch 调用，返回 id=paypalOrderId；金额单位 USD。',
    body: `{
  "intent": "CAPTURE",
  "purchase_units": [{
    "reference_id": "PO202607200001",
    "amount": { "currency_code": "USD", "value": "27.50" }
  }]
}`,
    curl: `curl -X POST \${BASE}/payments/paypal/v2/orders \\
  -H 'Content-Type: application/json' -d '{"intent":"CAPTURE","purchase_units":[{"amount":{"currency_code":"USD","value":"27.50"}}]}'`
  },
  {
    method: 'GET', path: '/payments/paypal/v2/orders/{order_id}', title: 'PayPal 查询订单', auth: false,
    params: [{ name: 'order_id', in: 'path', type: 'string', required: true, desc: 'PayPal Order ID' }]
  },
  {
    method: 'POST', path: '/payments/paypal/v2/orders/{order_id}/capture', title: 'PayPal 捕获资金', auth: false,
    desc: '用户在 PayPal 官方页面 approve 后调用，成功后标记本地支付单为 success 并触发 Lisa 下单 → 部署流水线。'
  },
  {
    method: 'POST', path: '/payments/paypal/webhook', title: 'PayPal Webhook 回调', auth: false,
    desc: '订阅 CHECKOUT.ORDER.COMPLETED / PAYMENT.CAPTURE.COMPLETED 事件，签名校验通过后自动标记支付成功。'
  },
  {
    method: 'GET', path: '/payments/paypal-confirm', title: '一键模拟 PayPal 回调（测试）', auth: false,
    params: [{ name: 'pay_no', in: 'query', type: 'string', required: true, desc: '支付单号' }]
  },
  // USDT
  {
    method: 'POST', path: '/payments/usdt/notify', title: 'USDT 链上到账回调', auth: false,
    desc: '由第三方 USDT 网关 / 自建 TRC20 监听节点调用：携带 txid + 转账金额 + 区块高度，达到最小确认数后自动标记支付成功。',
    body: `{
  "payNo": "PAY20260720000991",
  "txid": "0x1234567890abcdef...",
  "amount": 27.50,
  "coin": "USDT", "network": "TRC20",
  "confirmations": 18, "minConfirm": 10,
  "blockHeight": 68001234,
  "fromAddress": "TXXX...",
  "toAddress": "TMetoeUSDTWallet..."
}`
  },
  {
    method: 'GET', path: '/payments/usdt/check', title: '前端轮询 USDT 支付状态', auth: true,
    desc: '建议每 3 秒轮询一次，最多 10 分钟（或订单过期前）。返回当前最新确认数 & 支付状态。',
    params: [{ name: 'pay_no', in: 'query', type: 'string', required: true, desc: '支付单号' }]
  },
  {
    method: 'GET', path: '/payments/usdt-confirm', title: '一键模拟 USDT 到账（测试）', auth: false,
    params: [
      { name: 'pay_no', in: 'query', type: 'string', required: true, desc: '支付单号' },
      { name: 'txid', in: 'query', type: 'string', required: false, desc: '可选：自定义 txid' },
      { name: 'amount', in: 'query', type: 'float', required: false, desc: '可选：自定义金额' }
    ]
  }
]

const deployApis = [
  {
    method: 'GET', path: '/deploy-tasks', title: '部署任务列表', auth: true,
    params: [
      { name: 'page', in: 'query', type: 'int', required: false, desc: '' },
      { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '' },
      { name: 'status', in: 'query', type: 'string', required: false, desc: 'pending / running / success / failed' },
      { name: 'order_id', in: 'query', type: 'int', required: false, desc: '' },
      { name: 'server_id', in: 'query', type: 'int', required: false, desc: '' },
      { name: 'all', in: 'query', type: 'string', required: false, desc: '1=全部 (管理员)' }
    ],
    curl: `curl "\${BASE}/deploy-tasks?status=running" -H 'Authorization: Bearer TOKEN'`
  },
  {
    method: 'GET', path: '/deploy-tasks/{taskId}', title: '部署任务详情', auth: true,
    params: [{ name: 'taskId', in: 'path', type: 'int', required: true, desc: '' }]
  },
  {
    method: 'GET', path: '/deploy-tasks/{taskId}/logs', title: '实时部署日志', auth: true,
    desc: '返回逐行字符串数组，可直接渲染为 <pre> 代码块；包含 deploy-init.sh 的真实执行输出 + 错误栈。'
  },
  {
    method: 'POST', path: '/deploy-tasks/{taskId}/retry', title: '重试部署', auth: true,
    desc: '失败时可调用：复用已存在的服务器，重新触发初始化脚本。会生成一条新的 deploy_task 记录。'
  },
  {
    method: 'POST', path: '/internal/deploy/notify', title: '部署结果回调（内部）', auth: false,
    desc: 'deploy-init.sh 脚本执行结束后，由部署节点调用此接口把最终结果（IP / 端口 / 账号 / 密码 / 二维码 / 连接 URL）写回管理后台数据库。',
    body: `{
  "deployTaskId": 77,
  "serverId": 5001,
  "status": "success",
  "exitCode": 0,
  "accessEntries": [
    { "type": "SOCKS5", "ip": "104.28.12.89", "port": 10800, "username": "u_xxx", "password": "p_xxx" },
    { "type": "SSH_RDP", "ip": "104.28.12.89", "port": 22, "username": "root", "password": "root_pwd" }
  ],
  "qrcodes": [ { "label": "扫码连接", "base64": "data:image/png;base64,..." } ],
  "logs": [ "[INFO] vpn.sh v2.4 start", "[OK] Done at 2026-07-20 14:36:01" ],
  "deployDurationSec": 72,
  "hmac": "sha256=xxxxx(由双方约定的 M2M Secret 签名校验)"
}`,
    curl: `curl -X POST \${BASE}/internal/deploy/notify \\
  -H 'Content-Type: application/json' \\
  -H 'X-Internal-Secret: M2M_SECRET_FROM_ENV' \\
  -d '{"deployTaskId":77,"status":"success"}'`
  }
]

const configApis = [
  {
    method: 'GET', path: '/config/customer-service', title: '读取客服信息', auth: false,
    desc: '公开接口，页面所有模块（顶栏/底部/客服抽屉/反馈页）共享。包含站点名、微信/QQ/邮箱/电话/工作时间、二维码图片 Base64。'
  },
  {
    method: 'GET', path: '/config/payment-channels', title: '支付渠道开关 & 详情', auth: false,
    desc: '返回各支付方式是否启用 + USDT 当前汇率 / 钱包地址 / 最小确认数 / 过期分钟 + PayPal 沙盒开关与结算币种。'
  },
  {
    method: 'GET', path: '/config/all', title: '管理员：读取全部系统配置', auth: true,
    desc: '需要 config:view。包含 Lisa 主机 API 凭证、回调域名 baseUrl、充值加赠比例、实名奖励金额等。'
  },
  {
    method: 'POST', path: '/config/save', title: '管理员：保存系统配置', auth: true,
    desc: '需要 config:manage。以 {key: value} 对象批量更新。'
  }
]

const checkApis = [
  {
    method: 'POST', path: '/check/ip', title: 'IP 健康检测（GEO / ASN / RBL）', auth: true,
    desc: '等价于控制台「网络检测中心」：返回 Geo 归属 / ASN 运营商 / RBL 命中数 / AbuseIPDB 计数 / IPQS 评分 / Spur / Scam 综合结论 0-100 分。',
    body: `{
  "ip": "104.28.12.89",
  "checks": ["geo","asn","rbl","abuse","ipqs","scam","spur"]
}`,
    curl: `curl -X POST \${BASE}/check/ip -H 'Authorization: Bearer TOKEN' \\
  -H 'Content-Type: application/json' -d '{"ip":"104.28.12.89"}'`,
    response: `{
  "code": 0,
  "data": {
    "ip": "104.28.12.89",
    "country": "🇺🇸 美国",
    "countryCode": "US",
    "score": 92,
    "conclusion": "PASS",
    "geo": "🇺🇸 美国 · 加利福尼亚州 · 洛杉矶",
    "asn": "AS13335 Cloudflare, Inc.",
    "rblHit": 0,
    "abuseReports": 0,
    "spur": { "crawler": false, "vpn": false },
    "checks": { "geo":"OK", "rbl":"PASS", "ipqs":"GOOD" },
    "checkedAt": "2026-07-20 15:04:56"
  }
}`
  }
]

const fbApis = [
  {
    method: 'POST', path: '/feedbacks', title: '提交反馈工单', auth: true,
    body: `{
  "type": "consult",
  "priority": "normal",
  "title": "关于购买 US 区域接入实例的疑问",
  "content": "请问 US 节点支持的最大带宽是多少？是否有按小时付费选项？",
  "refId": "PO202607200001"
}`,
    params: [],
    curl: `curl -X POST \${BASE}/feedbacks -H 'Authorization: Bearer TOKEN' \\
  -H 'Content-Type: application/json' \\
  -d '{"type":"bug","priority":"high","title":"支付后资源未开通","content":"订单号 PO..."}'`,
    response: `{ "code": 0, "data": { "id": 33, "ticketNo": "TK100033" } }`
  },
  {
    method: 'GET', path: '/feedbacks', title: '工单列表', auth: true,
    params: [{ name: 'status', in: 'query', type: 'string', required: false, desc: 'open / replied / closed' }]
  },
  {
    method: 'GET', path: '/feedbacks/{id}', title: '工单详情（含对话流）', auth: true
  },
  {
    method: 'PUT', path: '/feedbacks/{id}/status', title: '客服：更新工单状态', auth: true,
    desc: '需要 feedback:manage 权限。'
  }
]

const sysApis = [
  { method: 'GET', path: '/system/users', title: '用户列表', auth: true, params: [
    { name: 'page', in: 'query', type: 'int', required: false, desc: '' },
    { name: 'pageSize', in: 'query', type: 'int', required: false, desc: '' },
    { name: 'keyword', in: 'query', type: 'string', required: false, desc: '用户名 / 邮箱 模糊' },
    { name: 'role', in: 'query', type: 'string', required: false, desc: '角色 code 过滤' }
  ]},
  { method: 'POST', path: '/system/users', title: '后台新增用户', auth: true, desc: 'system:users:manage 权限；直接指定角色与初始余额。' },
  { method: 'PUT', path: '/system/users/{id}', title: '修改用户资料 / 状态', auth: true },
  { method: 'POST', path: '/system/users/{id}/recharge', title: '财务：手动充值 / 扣款', auth: true, desc: 'finance / super_admin 角色；写一条 transaction 记录并更新 users.balance。' },
  { method: 'POST', path: '/system/users/{id}/reset-password', title: '重置用户密码', auth: true },
  { method: 'DELETE', path: '/system/users/{id}', title: '删除用户', auth: true, desc: '仅 super_admin；不能删除自己。' },
  { method: 'GET', path: '/system/roles', title: '角色列表', auth: true },
  { method: 'GET', path: '/system/permissions', title: '权限树', auth: true, desc: '前端菜单 / 按钮级权限渲染依据。' },
  { method: 'POST', path: '/system/roles', title: '新增角色', auth: true },
  { method: 'PUT', path: '/system/roles/{code}', title: '修改角色', auth: true },
  { method: 'DELETE', path: '/system/roles/{code}', title: '删除角色', auth: true },
  { method: 'POST', path: '/system/roles/{code}/permissions', title: '保存角色权限', auth: true, desc: '全量覆盖：前端把勾选的 permission_code 一次性提交。' }
]
</script>

<style scoped>
.developer-page { padding: 18px 22px 60px; }

.page-hero {
  display: flex; align-items: center; justify-content: space-between;
  border: 1px solid #eef0f4; border-radius: 14px; padding: 22px 26px;
  background: linear-gradient(135deg, #eff6ff 0%, #ecfdf5 60%, #fdf4ff 100%);
}
.hero-left { display: flex; align-items: center; gap: 18px; }
.hero-icon {
  width: 72px; height: 72px; border-radius: 18px;
  background: linear-gradient(135deg,#6366f1,#10b981); color:#fff;
  display:flex; align-items:center; justify-content:center;
  box-shadow: 0 10px 26px rgba(99,102,241,.26);
}
.hero-title { margin: 0; font-size: 22px; letter-spacing: .3px; }
.hero-desc { margin: 6px 0 0; max-width: 780px; line-height: 1.7; }
.hero-right { display: flex; align-items: center; }
.ml-8 { margin-left: 8px; }

.mt-16 { margin-top: 16px; }
.mt-10 { margin-top: 10px; }
.mt-12 { margin-top: 12px; }
.mt-14 { margin-top: 14px; }
.mt-20 { margin-top: 20px; }

.lhs-wrap { position: sticky; top: 18px; }
.lhs-card { border-radius: 14px; border: 1px solid #eef0f4; }
.lhs-title { margin: 0 0 14px; font-size: 15px; display: flex; align-items: center; gap: 8px; }
.lbl { font-size: 13px; color: #4b5563; font-weight: 500; }
.muted { color: #6b7280; }
.small { font-size: 12px; }
.inline-code { background:#f1f5f9; padding:1px 7px; border-radius:4px; font-size: 12px; color:#0f172a; }

.env-select {
  display:flex; align-items:center; gap:14px;
  background:#f8fafc; border-radius: 10px; padding: 8px 12px; margin-bottom: 12px;
}
.base-url-box {
  display:flex; align-items:center; gap:10px; flex-wrap:wrap;
  border: 1px dashed #cbd5e1; border-radius: 10px; padding: 10px 12px; background: #fafafa;
}
.base-url { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 13px; color: #0f172a; }
.key-input { margin-top: 6px; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }

.log-line { display:flex; align-items:center; gap:8px; }
.method-pill {
  padding: 1px 7px; border-radius: 4px; color:#fff; font-weight: 700; font-size: 11px;
}
.method-pill.get { background:#10b981; } .method-pill.post { background:#2563eb; }
.method-pill.put { background:#f59e0b; } .method-pill.patch { background:#8b5cf6; }
.method-pill.delete { background:#ef4444; }
.log-path { flex: 1; font-family: ui-monospace, Menlo, monospace; }
.log-meta { margin-top: 2px; }
.log-meta b.ok { color:#10b981; } .log-meta b.warn { color:#f59e0b; } .log-meta b.bad { color:#ef4444; }

.sdk-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
.sdk-list li {
  display:flex; align-items:center; gap: 10px; padding: 9px 12px;
  border: 1px solid #eef0f4; border-radius: 9px; font-size: 13px;
}
.sdk-list li .el-button { margin-left: auto; }

.rhs-card { border-radius: 14px; border: 1px solid #eef0f4; }
.api-tabs :deep(.el-tabs__header) { margin: 0; }
.api-tabs :deep(.el-tabs__item) { height: 44px; font-weight: 500; }
.sec-lead { margin: 8px 0 18px; }
.sec-h { margin: 0 0 10px; font-size: 16px; color: #0f172a; }
.doc-section { margin-bottom: 28px; }

/* Code block */
.code-block-wrap { margin-top: 8px; border: 1px solid #e5e7eb; border-radius: 10px; overflow: hidden; }
.cb-header {
  display:flex; align-items:center; justify-content:space-between;
  padding: 7px 12px; background:#f8fafc; border-bottom: 1px solid #eef0f4;
}
.cb-title { font-size: 12px; color: #374151; font-weight: 600; }
.cb-body {
  margin: 0; padding: 14px 16px;
  background: #0b1220; color: #e2e8f0;
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 13px; line-height: 1.7; overflow: auto;
  white-space: pre;
}

/* API catalog */
.api-catalog { display: flex; flex-direction: column; gap: 12px; }
.api-card {
  border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;
  background: #fff;
}
.api-head {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 14px; background: #fafbfc; cursor: pointer;
  transition: background .15s;
}
.api-head:hover { background: #f3f4f6; }
.m-pill {
  min-width: 60px; text-align: center; color:#fff; font-weight: 800;
  padding: 3px 8px; border-radius: 6px; font-size: 12px; letter-spacing: .3px;
}
.m-path {
  font-family: ui-monospace, Menlo, monospace; font-size: 13.5px;
  background: #0b1220; color:#e2e8f0; padding: 3px 8px; border-radius: 6px;
  font-weight: 600;
}
.m-title { flex: 1; color: #111827; font-weight: 600; }
.m-tag { margin-right: 10px; }
.m-arrow { color: #94a3b8; font-size: 10px; }

.api-body { padding: 14px 16px; border-top: 1px solid #eef0f4; background: #fff; }
.api-desc { margin: 0 0 12px; color: #374151; line-height: 1.7; }
.url-row {
  display:flex; align-items:center; gap: 10px; margin-bottom: 14px;
}
.url-input {
  flex:1; padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px;
  font-family: ui-monospace, Menlo, monospace; font-size: 13px; background: #fafafa;
  outline: none;
}
.url-copy {
  display:inline-flex; align-items:center; gap: 6px;
  padding: 9px 14px; border: 1px solid #6366f1; background: #eef2ff; color: #4338ca;
  border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 13px;
}
.url-copy:hover { background: #e0e7ff; }
.api-table { margin-bottom: 10px; }
.red { color: #dc2626; }

.sub-section { margin-top: 14px; }
.sub-title {
  display:flex; align-items:center; gap: 8px; margin-bottom: 8px;
  color: #0f172a; font-weight: 600; font-size: 13.5px;
}
.err-list { margin: 6px 0 0; padding-left: 20px; line-height: 1.9; font-size: 13px; }
</style>
