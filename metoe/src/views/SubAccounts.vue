<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="4"><el-card shadow="hover" class="stat-card c1">
        <div class="lbl muted small">主账号</div>
        <div class="val">{{ mainName }}</div>
        <div class="ft">超级管理员 · 全部权限</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card c2">
        <div class="lbl muted small">子账号总数</div>
        <div class="val">{{ rows.length }} <span class="unit">个</span></div>
        <div class="ft">企业版限额 20 个</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card c3">
        <div class="lbl muted small">已启用</div>
        <div class="val ok">{{ enabledCount }} / {{ rows.length }}</div>
        <div class="ft">禁用 {{ rows.length - enabledCount }} 个</div>
      </el-card></el-col>
      <el-col :span="5"><el-card shadow="hover" class="stat-card c4">
        <div class="lbl muted small">子账号总余额</div>
        <div class="val warn">¥ {{ subTotalBalance.toFixed(2) }}</div>
        <div class="ft">从主账号已累计划转 ¥ {{ totalTransferred.toFixed(2) }}</div>
      </el-card></el-col>
      <el-col :span="5">
        <el-card shadow="hover" class="tips-card">
          <div class="t-row">
            <el-icon :size="26" color="#10b981"><Lock /></el-icon>
            <div class="t-info">
              <b>RAM 风格子账号体系</b>
              <div class="muted small">权限策略 + 角色组配置，操作留痕。</div>
            </div>
            <el-button type="primary" :icon="Plus" size="large" @click="openAdd">新建子账号</el-button>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <div class="left">
            <b>子账号列表</b>
            <el-tag type="info" effect="light" round size="small" style="margin-left: 10px;">支持分组 · 角色 · 策略</el-tag>
          </div>
          <div class="right">
            <el-input v-model="kw" size="default" placeholder="搜索用户名 / 邮箱" clearable style="width: 230px;">
              <template #prefix><el-icon><Search /></el-icon></template>
            </el-input>
            <el-select v-model="roleFilter" size="default" placeholder="角色筛选" clearable style="width: 140px; margin-left: 10px;">
              <el-option label="财务" value="finance" />
              <el-option label="运营" value="ops" />
              <el-option label="开发" value="dev" />
              <el-option label="只读" value="viewer" />
            </el-select>
            <el-button :icon="Money" plain style="margin-left: 10px;" @click="goTransfer">资金划转</el-button>
            <el-button :icon="Notebook" plain style="margin-left: 6px;" @click="goFlow">资金流向</el-button>
            <el-button type="primary" :icon="Plus" style="margin-left: 10px;" @click="openAdd">新建子账号</el-button>
          </div>
        </div>
      </template>

      <el-table :data="filteredRows" stripe style="width: 100%;">
        <el-table-column label="账号信息" min-width="260">
          <template #default="{ row }">
            <div class="u-row">
              <el-avatar :size="42" :style="{ background: row.bg }">
                {{ row.name.charAt(0).toUpperCase() }}
              </el-avatar>
              <div class="u-info">
                <div class="u-name">
                  <b>{{ row.name }}</b>
                  <el-tag v-if="row.mfa" size="small" type="success" effect="plain" style="margin-left: 6px;">MFA</el-tag>
                  <el-tag v-if="row.parentName" size="small" type="info" effect="plain" style="margin-left: 6px;">主账号: {{ row.parentName }}</el-tag>
                </div>
                <div class="u-email muted small">{{ row.email }} · {{ row.phone }}</div>
                <div class="u-time muted small">上次登录：{{ row.last }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="140">
          <template #default="{ row }">
            <el-tag :type="roleTypes[row.role].type" effect="light" round>
              <el-icon style="margin-right: 3px;"><component :is="roleTypes[row.role].icon" /></el-icon>
              {{ roleTypes[row.role].name }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="可用余额" width="130" align="right">
          <template #default="{ row }">
            <el-popover placement="top" width="260" trigger="hover">
              <template #reference>
                <b :style="{ color: Number(row.balance) > 0 ? '#d97706' : '#9ca3af' }">¥ {{ Number(row.balance).toFixed(2) }}</b>
              </template>
              <div class="muted small" style="line-height:1.8">
                <div>最近划转时间：{{ row.lastUpdate || '—' }}</div>
                <div>累计主→子划转：¥ {{ Number(row.totalIn || 0).toFixed(2) }}</div>
                <div>累计消费：¥ {{ Number(row.totalSpend || 0).toFixed(2) }}</div>
              </div>
            </el-popover>
          </template>
        </el-table-column>
        <el-table-column label="权限范围" width="220">
          <template #default="{ row }">
            <el-tooltip :content="row.perms.map(p=>permNames[p]).join('、')" placement="top">
              <div class="perm-tags">
                <el-tag v-for="(p, i) in row.perms.slice(0,3)" :key="p" size="small" effect="plain" class="perm-tag">{{ permNames[p] }}</el-tag>
                <span v-if="row.perms.length>3" class="muted small">+{{ row.perms.length - 3 }}</span>
              </div>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column label="设备" width="70" align="center">
          <template #default="{ row }">{{ row.devices }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="160">
          <template #default="{ row }">{{ row.createdAt }}</template>
        </el-table-column>
        <el-table-column label="状态" width="110" align="center">
          <template #default="{ row }">
            <el-switch v-model="row.enabled" @change="onToggle(row)" :active-text="'启'" :inactive-text="'禁'" inline-prompt />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="360" align="right" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" plain :icon="EditPen" @click="openPerm(row)">授权</el-button>
            <el-button size="small" type="warning" plain :icon="Money" @click="openTransfer(row)">划转资金</el-button>
            <el-button size="small" type="success" plain :icon="Notebook" @click="goFlow(row)">资金明细</el-button>
            <el-button size="small" type="info" plain :icon="Key" @click="resetPwd(row)">重置密码</el-button>
            <el-button size="small" type="danger" plain :icon="Delete" @click="removeRow(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination layout="total, prev, pager, next, jumper" :total="filteredRows.length" background />
      </div>
    </el-card>

    <el-dialog v-model="addVisible" :title="editing ? '编辑子账号' : '新建子账号'" width="560px">
      <el-form ref="formRef" :model="form" label-width="110px" :rules="rules">
        <el-form-item label="用户名" prop="name"><el-input v-model="form.name" :disabled="!!editing" placeholder="登录唯一用户名，3-20位" /></el-form-item>
        <el-form-item label="显示名" prop="nickname"><el-input v-model="form.nickname" placeholder="中文姓名或花名" /></el-form-item>
        <el-form-item label="邮箱" prop="email"><el-input v-model="form.email" placeholder="找回密码/接收通知" /></el-form-item>
        <el-form-item label="手机号" prop="phone"><el-input v-model="form.phone" maxlength="11" show-word-limit /></el-form-item>
        <el-form-item label="角色" prop="role">
          <el-select v-model="form.role" style="width: 100%;">
            <el-option label="财务 (finance) — 账单、充值、余额" value="finance" />
            <el-option label="运营 (ops) — 下单、服务器、工单" value="ops" />
            <el-option label="开发 (dev) — API、服务器、密钥" value="dev" />
            <el-option label="只读查看 (viewer) — 仅查看，无写权限" value="viewer" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="!editing" label="初始密码" prop="password">
          <el-input v-model="form.password" show-password placeholder="建议包含字母数字符号，8-32位" />
        </el-form-item>
        <el-form-item label="初始余额(¥)">
          <el-input-number v-model="form.balance" :min="0" :precision="2" :step="100" style="width:100%" />
        </el-form-item>
        <el-form-item label="启用方式">
          <el-checkbox v-model="form.sendEmail">激活链接发送至邮箱</el-checkbox>
          <el-checkbox v-model="form.sms">短信通知初始密码</el-checkbox>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="addVisible=false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitAdd">{{ editing ? '保存修改' : '确认创建' }}</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="permVisible" :title="'权限配置 · ' + permTarget?.name" width="640px">
      <div class="muted small" style="margin-bottom:10px">基于 RAM 最小权限原则，勾选该子账号允许执行的操作。</div>
      <el-tree
        ref="permTreeRef" :data="permTree" show-checkbox node-key="key"
        :default-checked-keys="permTarget?.perms || []" highlight-current
      />
      <template #footer>
        <el-button @click="permVisible=false">取消</el-button>
        <el-button type="primary" @click="savePerm">保存权限配置</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="transferVisible" title="资金划转 · 主 → 子账号" width="480px">
      <div v-if="transferTarget" class="transfer-head">
        <div class="muted small">主账号（转出）</div>
        <div class="tr-row"><b>{{ mainName }}</b><span class="bal ok">可用 ¥ {{ mainBalance.toFixed(2) }}</span></div>
        <div class="muted small mt-8">子账号（转入）</div>
        <div class="tr-row"><b>{{ transferTarget.name }}</b>
          <span class="bal warn">当前 ¥ {{ Number(transferTarget.balance).toFixed(2) }}</span>
        </div>
      </div>
      <el-form class="mt-12" label-width="96px" :model="tf" :rules="tfRules" ref="tfRef">
        <el-form-item label="划转金额(¥)" prop="amount">
          <el-input-number v-model="tf.amount" :min="1" :precision="2" :step="100" style="width:100%" :max="Number(mainBalance)" />
        </el-form-item>
        <el-form-item label="支付密码" prop="pwd">
          <el-input v-model="tf.pwd" type="password" show-password placeholder="请输入主账号支付密码（演示填 123456）" />
        </el-form-item>
        <el-form-item label="备注说明">
          <el-input v-model="tf.remark" placeholder="选填，如：月度预算 / 采购专项款" maxlength="60" show-word-limit />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="transferVisible=false" :disabled="submitting">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitTransfer">立即划转</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Plus, Search, Lock, EditPen as Edit, Key, Delete, Wallet, Money, Notebook,
  DataAnalysis, Cpu, View
} from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import { transferFunds, listWalletAccounts } from '@/api/wallet'
import {
  getSubaccountList, createSubaccount, updateSubaccount,
  resetSubaccountPassword, deleteSubaccount, getSubaccountPermissions,
} from '@/api/subaccounts'

const router = useRouter()
const userStore = useUserStore()
const mainName = computed(() => userStore.userInfo?.username || 'admin')

const kw = ref('')
const roleFilter = ref('')
const addVisible = ref(false)
const permVisible = ref(false)
const transferVisible = ref(false)
const saving = ref(false)
const submitting = ref(false)
const editing = ref(null)
const permTarget = ref(null)
const permTreeRef = ref(null)
const transferTarget = ref(null)
const formRef = ref(null)
const tfRef = ref(null)

const roleTypes = {
  finance: { name: '财务', type: 'success', icon: Wallet },
  ops: { name: '运营', type: 'warning', icon: DataAnalysis },
  dev: { name: '开发', type: 'primary', icon: Cpu },
  viewer: { name: '只读', type: 'info', icon: View },
}
const permNames = {
  orders_view: '查看订单', orders_create: '下单购买', recharge: '充值',
  servers_view: '查看服务器', servers_op: '服务器操作', billing: '账单明细',
  users: '用户管理', tickets: '工单', api: 'API密钥', finance: '提现'
}
const permTree = [
  { key: 'orders_view', label: '订单 · 查看订单' },
  { key: 'orders_create', label: '订单 · 下单购买' },
  { key: 'recharge', label: '财务 · 充值操作' },
  { key: 'billing', label: '财务 · 账单明细' },
  { key: 'finance', label: '财务 · 提现审批' },
  { key: 'servers_view', label: '服务器 · 查看列表' },
  { key: 'servers_op', label: '服务器 · 启停/重装' },
  { key: 'api', label: '服务器 · API密钥' },
  { key: 'users', label: '账户 · 用户管理' },
  { key: 'tickets', label: '账户 · 工单提交' },
]
const defaultPermsByRole = {
  finance: ['orders_view','recharge','billing','finance','tickets'],
  ops: ['orders_view','orders_create','servers_view','servers_op','tickets'],
  dev: ['servers_view','servers_op','api','tickets'],
  viewer: ['orders_view','servers_view','billing'],
}
const bgs = [
  'linear-gradient(135deg,#3b82f6,#2563eb)',
  'linear-gradient(135deg,#10b981,#059669)',
  'linear-gradient(135deg,#f59e0b,#d97706)',
  'linear-gradient(135deg,#8b5cf6,#7c3aed)',
  'linear-gradient(135deg,#ef4444,#dc2626)',
]
const loading = ref(false)
const availPerms = ref([])
const rows = ref([])
function mockRows() {
  return [
    { userId:'finance_alice', name:'finance_alice', email:'alice@metoe.io', phone:'138****2341', role:'finance', perms:[...defaultPermsByRole.finance], devices:2, last:'15分钟前 · 上海', createdAt:'2026-03-12 10:23', enabled:true, mfa:true, bg:bgs[0], balance:8500, totalIn:12000, totalSpend:3500, lastUpdate:'2026-07-05 09:44', parentName:'admin' },
    { userId:'ops_bob', name:'ops_bob', email:'bob@metoe.io', phone:'139****5621', role:'ops', perms:[...defaultPermsByRole.ops], devices:3, last:'今天 09:12', createdAt:'2026-04-02 14:51', enabled:true, mfa:true, bg:bgs[1], balance:3200, totalIn:5000, totalSpend:1800, lastUpdate:'2026-07-08 11:03', parentName:'admin' },
    { userId:'dev_carol', name:'dev_carol', email:'carol@metoe.io', phone:'137****8891', role:'dev', perms:[...defaultPermsByRole.dev], devices:4, last:'2小时前', createdAt:'2026-04-20 09:07', enabled:true, mfa:false, bg:bgs[2], balance:1560, totalIn:2200, totalSpend:640, lastUpdate:'2026-07-15 19:21', parentName:'admin' },
    { userId:'audit_david', name:'audit_david', email:'david@metoe.io', phone:'136****1122', role:'viewer', perms:[...defaultPermsByRole.viewer], devices:1, last:'昨天 18:40', createdAt:'2026-05-08 20:14', enabled:true, mfa:false, bg:bgs[3], balance:480, totalIn:800, totalSpend:320, lastUpdate:'2026-07-18 13:55', parentName:'admin' },
    { userId:'ex_erin', name:'ex_erin', email:'erin@metoe.io', phone:'135****3344', role:'ops', perms:[...defaultPermsByRole.ops], devices:0, last:'3个月前', createdAt:'2026-01-15 15:32', enabled:false, mfa:true, bg:bgs[4], balance:20, totalIn:500, totalSpend:480, lastUpdate:'2026-04-02 10:00', parentName:'admin' },
  ]
}
async function loadRows() {
  loading.value = true
  try {
    const [listR, permR] = await Promise.all([
      getSubaccountList({ page: 1, page_size: 200 }).catch(() => null),
      getSubaccountPermissions().catch(() => null),
    ])
    if (permR?.code === 0 && permR.data?.groups?.length) {
      const keys = []
      permR.data.groups.forEach(g => (g.items || []).forEach(it => keys.push(it.code)))
      availPerms.value = permTree.filter(x => keys.includes(x.key) || true).slice(0, permTree.length)
    }
    if (listR?.code === 0 && Array.isArray(listR.data?.list)) {
      rows.value = listR.data.list.map((c, i) => ({
        userId: c.childId || c.username || ('sub_' + i),
        name: c.username || ('sub_' + i),
        email: c.email || '-',
        phone: c.phone || '-',
        role: c.role || c.permissionGroup || 'viewer',
        perms: Array.isArray(c.permissions) ? c.permissions : (defaultPermsByRole[c.role] || defaultPermsByRole.viewer),
        devices: 0,
        last: c.lastLoginAt ? new Date(c.lastLoginAt).toLocaleString('zh-CN') : '—',
        createdAt: c.createdAt || new Date().toISOString().slice(0, 16).replace('T', ' '),
        enabled: c.status !== 'disabled' && c.status !== 0,
        mfa: false,
        bg: bgs[i % bgs.length],
        balance: c.maxBalance != null ? Number(c.maxBalance) : (c.balanceNum || 0),
        totalIn: 0,
        totalSpend: 0,
        lastUpdate: c.createdAt || new Date().toISOString().slice(0, 16).replace('T', ' '),
        parentName: mainName.value,
      }))
    } else {
      rows.value = mockRows()
    }
  } catch (_) {
    rows.value = mockRows()
  } finally {
    loading.value = false
  }
}
onMounted(loadRows)

const mainBalance = computed(() => Number(userStore.userInfo?.balance || 99979))
const enabledCount = computed(() => rows.value.filter(r => r.enabled).length)
const subTotalBalance = computed(() => rows.value.reduce((s, r) => s + Number(r.balance || 0), 0))
const totalTransferred = computed(() => rows.value.reduce((s, r) => s + Number(r.totalIn || 0), 0))
const filteredRows = computed(() => rows.value.filter(r => {
  const k = String(kw.value || '').toLowerCase()
  if (k && !(String(r.name).toLowerCase().includes(k) || String(r.email || '').toLowerCase().includes(k))) return false
  if (roleFilter.value && r.role !== roleFilter.value) return false
  return true
}))

const defaultForm = () => ({ name:'', nickname:'', email:'', phone:'', role:'viewer', password:'', balance:0, sendEmail:true, sms:false })
const form = reactive(defaultForm())
const rules = {
  name: [{ required: true, message: '请输入用户名', trigger: 'blur' }, { min: 3, max: 20, message: '3-20个字符' }],
  email: [{ required: true, message: '请输入邮箱' }, { type: 'email', message: '邮箱格式不正确' }],
  phone: [{ required: true, message: '请输入手机号' }, { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确' }],
  role: [{ required: true, message: '请选择角色' }],
  password: [{ required: true, message: '请输入初始密码' }, { min: 8, max: 32, message: '8-32位' }],
}
const tf = reactive({ amount: 500, pwd: '', remark: '' })
const tfRules = {
  amount: [{ required: true, message: '请输入划转金额' }, { type: 'number', min: 1, message: '至少 ¥1' }],
  pwd: [{ required: true, message: '请输入支付密码' }],
}

function openAdd() {
  editing.value = null
  Object.assign(form, defaultForm())
  addVisible.value = true
}
async function submitAdd() {
  await formRef.value?.validate()
  saving.value = true
  try {
    if (editing.value) {
      const id = editing.value.userId
      let done = false
      try {
        const r = await updateSubaccount(id, {
          email: form.email, phone: form.phone,
          max_balance: Number(form.balance) || 0,
          permissions: defaultPermsByRole[form.role] || editing.value.perms,
          status: editing.value.enabled ? 'active' : 'disabled',
        })
        if (r?.code === 0) done = true
      } catch (_) {}
      Object.assign(editing.value, { nickname: form.nickname, email: form.email, phone: form.phone, role: form.role, perms: defaultPermsByRole[form.role] || editing.value.perms, balance: Number(form.balance) || 0 })
      ElMessage.success('子账号编辑已保存' + (done ? '（已同步服务器）' : ''))
    } else {
      if (rows.value.find(r => r.userId === form.name)) throw new Error('该用户名已存在')
      let row = null
      try {
        const r = await createSubaccount({
          username: form.name, password: form.password, email: form.email, phone: form.phone,
          max_balance: Number(form.balance) || 0,
          permissions: defaultPermsByRole[form.role] || [],
        })
        if (r?.code === 0) {
          row = {
            userId: r.data?.childId || form.name,
            name: form.name, email: form.email, phone: form.phone, role: form.role,
            perms: defaultPermsByRole[form.role] || [], devices: 0, last: '—',
            createdAt: new Date().toISOString().slice(0,16).replace('T',' '),
            enabled: true, mfa: false, bg: bgs[rows.value.length % bgs.length],
            balance: Number(form.balance) || 0, totalIn: Number(form.balance) || 0, totalSpend: 0,
            lastUpdate: new Date().toISOString().slice(0,16).replace('T',' '), parentName: mainName.value
          }
        }
      } catch (_) {}
      if (!row) {
        row = {
          userId: form.name, name: form.name, email: form.email, phone: form.phone, role: form.role,
          perms: defaultPermsByRole[form.role] || [], devices: 0, last: '—', createdAt: new Date().toISOString().slice(0,16).replace('T',' '),
          enabled: true, mfa: false, bg: bgs[rows.value.length % bgs.length],
          balance: Number(form.balance) || 0, totalIn: Number(form.balance) || 0, totalSpend: 0, lastUpdate: new Date().toISOString().slice(0,16).replace('T',' '), parentName: mainName.value
        }
      }
      rows.value.unshift(row)
      ElMessage.success('子账号创建成功！已通过邮件发送激活链接')
    }
    addVisible.value = false
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}
function openPerm(row) {
  permTarget.value = row
  permVisible.value = true
  setTimeout(() => permTreeRef.value?.setCheckedKeys(row.perms || []), 60)
}
async function savePerm() {
  const keys = permTreeRef.value?.getCheckedKeys() || []
  if (!permTarget.value) return
  let done = false
  try {
    const r = await updateSubaccount(permTarget.value.userId, { permissions: keys })
    if (r?.code === 0) done = true
  } catch (_) {}
  permTarget.value.perms = keys
  permVisible.value = false
  ElMessage.success('权限已更新（操作已记录至敏感日志）' + (done ? '' : '（本地演示）'))
}
function resetPwd(row) {
  ElMessageBox.prompt(
    `请输入子账号 ${row.name} 的新初始密码（8-32位，含大小写/数字）`,
    '重置子账号密码',
    { inputPattern: /^.{8,32}$/, inputErrorMessage: '密码 8-32 位', confirmButtonText: '确认重置密码', type: 'warning' }
  ).then(async ({ value: pwd }) => {
    let done = false
    let tip = ''
    try {
      const r = await resetSubaccountPassword(row.userId, pwd)
      if (r?.code === 0) {
        done = true
        tip = r?.message || ''
      } else if (r?.message) {
        ElMessage.error(r.message)
        return
      } else {
        ElMessage.error('重置密码失败：服务器返回异常')
        return
      }
    } catch (e) {
      const msg = e?.response?.data?.message || e?.message || '重置密码请求失败'
      ElMessage.error(msg)
      return
    }
    ElMessage.success(tip || `已为 ${row.name} 重置密码${done ? '（已同步服务器）' : '（本地演示）'}`)
  }).catch(err => {
    if (err !== 'cancel' && err !== 'close') {
      ElMessage.error(err?.message || '密码重置已取消')
    }
  })
}
async function onToggle(row) {
  let done = false
  try {
    const r = await updateSubaccount(row.userId, { status: row.enabled ? 'active' : 'disabled' })
    if (r?.code === 0) done = true
  } catch (_) {}
  ElMessage.success(`已${row.enabled ? '启用' : '禁用'}子账号 ${row.name}${done ? '' : '（本地演示）'}`)
}
function removeRow(row) {
  ElMessageBox.confirm(`确定删除子账号 ${row.name}？删除后不可恢复，且其下关联资源将被回收。`, '删除确认', { type: 'warning' })
    .then(async () => {
      try { await deleteSubaccount(row.userId).catch(() => null) } catch (_) {}
      const idx = rows.value.indexOf(row)
      if (idx >= 0) rows.value.splice(idx, 1)
      ElMessage.success('删除成功')
    }).catch(() => {})
}
function goTransfer() { router.push('/wallet/transfer') }
function goFlow(row) {
  if (row) router.push(`/wallet/funds?userId=${row.userId}`)
  else router.push('/wallet/funds')
}
function openTransfer(row) {
  transferTarget.value = row
  tf.amount = 500
  tf.pwd = ''
  tf.remark = ''
  transferVisible.value = true
}
async function submitTransfer() {
  if (submitting.value) return
  try {
    await tfRef.value?.validate()
  } catch (e) { return }
  if (tf.pwd !== '123456') { ElMessage.error('支付密码错误（演示密码：123456）'); return }
  if (!transferTarget.value) return
  submitting.value = true
  try {
    await transferFunds({
      fromUserId: mainName.value, toUserId: transferTarget.value.name || transferTarget.value.userId,
      amount: tf.amount, remark: tf.remark, operator: mainName.value, payPassword: tf.pwd
    })
    transferTarget.value.balance = Number((Number(transferTarget.value.balance) + Number(tf.amount)).toFixed(2))
    transferTarget.value.totalIn = Number((Number(transferTarget.value.totalIn || 0) + Number(tf.amount)).toFixed(2))
    transferTarget.value.lastUpdate = new Date().toISOString().slice(0,16).replace('T',' ')
    if (userStore.userInfo) userStore.userInfo.balance = Number((mainBalance.value - tf.amount).toFixed(2))
    transferVisible.value = false
    ElMessage.success(`划转成功：¥ ${Number(tf.amount).toFixed(2)} → ${transferTarget.value.name}`)
  } catch (e) {
    const msg = e?.response?.data?.message || e?.message || '划转失败'
    ElMessage.error(msg)
  } finally {
    submitting.value = false
  }
}
onMounted(async () => {
  try {
    const res = await listWalletAccounts(mainName.value)
    const map = Object.fromEntries((res?.data || []).map(a => [a.userId, a]))
    rows.value.forEach(r => { if (map[r.userId]) { r.balance = map[r.userId].balance; r.lastUpdate = map[r.userId].lastUpdate } })
  } catch (_) {}
})
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; }
.stat-card.c1 { background: linear-gradient(135deg,#eff6ff,#ede9fe); }
.stat-card.c2 { background: linear-gradient(135deg,#ecfeff,#dcfce7); }
.stat-card.c3 { background: linear-gradient(135deg,#fff7ed,#fee2e2); }
.stat-card.c4 { background: linear-gradient(135deg,#fef3c7,#ecfeff); }
.stat-card .lbl { margin-bottom: 6px; }
.stat-card .val { font-size: 24px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.stat-card .val .unit { font-size: 13px; font-weight: 500; color: #6b7280; margin-left: 4px; }
.stat-card .val.ok { color: #059669; }
.stat-card .val.warn { color: #d97706; }
.stat-card .ft { margin-top: 10px; font-size: 12px; color: #374151; }

.tips-card { border-radius: 14px; background: linear-gradient(135deg,#ecfdf5,#eff6ff); }
.t-row { display: flex; align-items: center; gap: 14px; }
.t-info { flex: 1; line-height: 1.7; }

.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.card-header .left, .card-header .right { display: flex; align-items: center; }

.u-row { display: flex; align-items: center; gap: 12px; padding: 4px 0; }
.u-name { font-size: 14px; color: #111827; }
.u-email, .u-time { margin-top: 3px; line-height: 1.6; }
.perm-tags { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.perm-tag { margin-right: 2px; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.muted { color: #6b7280; } .small { font-size: 12px; }

.transfer-head .tr-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; }
.transfer-head .bal { font-weight: 700; }
.transfer-head .bal.ok { color: #059669; }
.transfer-head .bal.warn { color: #d97706; }
.mt-8 { margin-top: 8px; } .mt-12 { margin-top: 12px; }
</style>
