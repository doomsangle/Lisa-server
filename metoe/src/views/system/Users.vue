<template>
  <div class="users-page">
    <div class="page-card">
      <div class="stat-row">
        <div class="s-card c1">
          <div class="s-label muted small">用户总数</div>
          <div class="s-val">{{ totalCount }}</div>
          <div class="s-ft muted small">主账号 {{ mainCount }} · 子账号 {{ subCount }} · 管理员 {{ adminCount }}</div>
        </div>
        <div class="s-card c2">
          <div class="s-label muted small">账户总余额</div>
          <div class="s-val warn">¥ {{ totalBalance.toFixed(2) }}</div>
          <div class="s-ft muted small">其中子账号余额 ¥ {{ subBalance.toFixed(2) }}</div>
        </div>
        <div class="s-card c3">
          <div class="s-label muted small">本月活跃登录</div>
          <div class="s-val ok">{{ activeThisMonth }}</div>
          <div class="s-ft muted small">近 30 天有访问记录</div>
        </div>
        <div class="s-card c4">
          <div class="s-label muted small">实名认证</div>
          <div class="s-val">{{ verifiedCount }}/{{ totalCount }}</div>
          <div class="s-ft muted small">已认证 {{ Math.round(verifiedCount * 100 / Math.max(1,totalCount)) }}%</div>
        </div>
      </div>

      <el-tabs v-model="tab" class="user-tabs" @tab-change="onTabChange">
        <el-tab-pane label="全部用户" name="all" />
        <el-tab-pane label="主账号" name="main" />
        <el-tab-pane label="子账号" name="sub" />
        <el-tab-pane label="管理员" name="admin" />
        <el-tab-pane label="已禁用" name="disabled" />
      </el-tabs>

      <div class="flex-between filter-bar">
        <div>
          <el-input v-model="filters.keyword" placeholder="搜索用户名 / 邮箱 / 手机号" style="width: 260px" clearable>
            <template #prefix><el-icon><Search /></el-icon></template>
          </el-input>
          <el-select v-model="filters.role" placeholder="角色筛选" style="width: 140px; margin-left: 10px" clearable>
            <el-option label="超级管理员" value="super_admin" />
            <el-option label="管理员" value="admin" />
            <el-option label="主账号" value="main" />
            <el-option label="财务子账号" value="finance" />
            <el-option label="运营子账号" value="ops" />
            <el-option label="开发子账号" value="dev" />
            <el-option label="只读子账号" value="viewer" />
          </el-select>
          <el-select v-model="filters.parentId" placeholder="归属主账号" style="width: 160px; margin-left: 10px" clearable>
            <el-option v-for="m in mainUsers" :key="m.id" :label="m.username" :value="m.username" />
          </el-select>
          <el-select v-model="filters.status" placeholder="状态" style="width: 120px; margin-left: 10px" clearable>
            <el-option label="正常" value="active" />
            <el-option label="禁用" value="disabled" />
            <el-option label="待审核" value="pending" />
          </el-select>
          <el-button type="primary" class="ml-8" @click="loadData">查询</el-button>
          <el-button @click="resetFilters">重置</el-button>
        </div>
        <div>
          <el-button :icon="Money" plain @click="goTransfer">资金划转</el-button>
          <el-button :icon="Notebook" plain style="margin-left:6px" @click="goFlow">资金流向</el-button>
          <el-button :icon="UserFilled" plain style="margin-left:6px" @click="goSubAccounts">子账号管理</el-button>
          <el-button type="primary" :icon="Plus" style="margin-left:10px" @click="openEdit(null)">{{ isAdmin ? '新增用户' : '创建子账号' }}</el-button>
        </div>
      </div>

      <el-table :data="filteredList" v-loading="loading" border stripe style="margin-top: 12px;">
        <el-table-column type="index" label="#" width="60" />
        <el-table-column label="用户信息" min-width="240">
          <template #default="{ row }">
            <div class="flex-row">
              <el-avatar :size="40" :style="{ background: row.bg }">
                {{ row.username.charAt(0).toUpperCase() }}
              </el-avatar>
              <div style="margin-left: 10px">
                <div class="name"><b>{{ row.username }}</b>
                  <el-tag v-if="row.userType === 'admin'" type="danger" size="small" effect="dark" style="margin-left:6px">平台管理员</el-tag>
                  <el-tag v-else-if="row.userType === 'main'" type="primary" size="small" style="margin-left:6px">主账号</el-tag>
                  <el-tag v-else type="warning" size="small" effect="plain" style="margin-left:6px">子账号</el-tag>
                  <el-tag v-if="row.verified" size="small" effect="dark" type="success" style="margin-left:4px">已实名</el-tag>
                </div>
                <div class="muted small">{{ row.email }} · {{ row.phone }}</div>
                <div v-if="row.parentId" class="muted small" style="margin-top:2px">
                  <el-icon><User /></el-icon> 归属主账号：<b>{{ row.parentId }}</b>
                </div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="账号类型" width="110" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.userType==='admin'" type="danger" effect="dark" round size="small">管理员</el-tag>
            <el-tag v-else-if="row.userType==='main'" type="primary" round size="small">主账号</el-tag>
            <el-tag v-else type="warning" effect="light" round size="small">子账号</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="余额" width="120" align="right">
          <template #default="{ row }">
            <el-popover placement="top" width="220" trigger="hover">
              <template #reference>
                <b :style="{ color: Number(row.balance) > 0 ? '#d97706' : '#9ca3af' }">¥ {{ Number(row.balance).toFixed(2) }}</b>
              </template>
              <div class="muted small" style="line-height:1.8">
                <div>累计充值：¥ {{ Number(row.totalRecharge||0).toFixed(2) }}</div>
                <div>累计消费：¥ {{ Number(row.totalSpend||0).toFixed(2) }}</div>
                <div>累计划转：¥ {{ Number(row.totalTransferred||0).toFixed(2) }}</div>
                <div>更新时间：{{ row.balanceUpdate || '—' }}</div>
              </div>
            </el-popover>
          </template>
        </el-table-column>
        <el-table-column label="角色权限" width="180">
          <template #default="{ row }">
            <el-tag v-for="(r,i) in (row.roleNames||[]).slice(0,2)" :key="r" size="small" style="margin:0 4px 4px 0">{{ r }}</el-tag>
            <el-tooltip v-if="(row.roleNames||[]).length>2" :content="row.roleNames.join('、')">
              <span class="muted small">+{{ row.roleNames.length-2 }}</span>
            </el-tooltip>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110" align="center">
          <template #default="{ row }">
            <el-switch v-model="row.statusSwitch" @change="e => toggleStatus(row, e)"
              :active-value="'active'" :inactive-value="'disabled'" />
          </template>
        </el-table-column>
        <el-table-column prop="lastLoginAt" label="最近登录" width="170" />
        <el-table-column prop="createdAt" label="创建时间" width="170" />
        <el-table-column label="操作" width="360" fixed="right" align="right">
          <template #default="{ row }">
            <el-button link size="small" type="primary" :icon="Edit" @click="openEdit(row)">编辑</el-button>
            <el-button link size="small" type="success" :icon="Money" v-if="row.userType !== 'admin'" @click="openRecharge(row)">充值</el-button>
            <el-button link size="small" type="warning" :icon="Wallet" v-if="row.userType !== 'admin'" @click="openTransfer(row)">划转资金</el-button>
            <el-button link size="small" type="info" :icon="Notebook" v-if="row.userType !== 'admin'" @click="goFlow(row)">资金明细</el-button>
            <el-button link size="small" :icon="Key" @click="resetPwd(row)">重置密码</el-button>
            <el-button link size="small" type="danger" :icon="Delete" @click="remove(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrap">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="filteredList.length"
          @current-change="loadData"
        />
      </div>
    </div>

    <el-dialog v-model="editVisible" :title="editing ? '编辑用户' : (isAdmin ? '新增用户' : '创建子账号')" width="560px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="100px">
        <el-form-item label="账号类型" v-if="!editing">
          <el-radio-group v-model="form.userType" :disabled="!isAdmin">
            <el-radio value="main" v-if="isAdmin">主账号（平台注册客户）</el-radio>
            <el-radio value="sub">子账号（归属某主账号）</el-radio>
            <el-radio value="admin" v-if="isSuperAdmin">平台管理员</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" :disabled="!!editing" placeholder="3-20位字母数字下划线" />
        </el-form-item>
        <el-form-item v-if="!editing" label="初始密码" prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="6-32位" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email"><el-input v-model="form.email" /></el-form-item>
        <el-form-item label="手机号" prop="phone"><el-input v-model="form.phone" maxlength="11" /></el-form-item>
        <el-form-item label="归属主账号" v-if="form.userType === 'sub'">
          <el-select v-model="form.parentId" placeholder="请选择所属的主账号" style="width:100%">
            <el-option v-for="m in mainUsers" :key="m.username" :label="m.username" :value="m.username" />
          </el-select>
        </el-form-item>
        <el-form-item label="分配角色" prop="roles">
          <el-select v-model="form.roles" multiple collapse-tags collapse-tags-tooltip style="width:100%">
            <el-option v-for="r in roleOptions" :key="r.code" :label="r.name" :value="r.code" />
          </el-select>
        </el-form-item>
        <el-form-item label="余额(¥)">
          <el-input-number v-model="form.balance" :min="0" :precision="2" :step="100" style="width:100%" />
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio value="active">启用</el-radio>
            <el-radio value="disabled">禁用</el-radio>
            <el-radio value="pending" v-if="isAdmin">待审核</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editVisible=false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveForm">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rechargeVisible" title="为用户充值" width="440px">
      <div class="recharge-info">
        <div>用户：<b>{{ recharging?.username }}</b>（{{ recharging?.userType === 'main' ? '主账号' : '子账号' }}）</div>
        <div class="mt-8">当前余额：<b style="color:#e6a23c">¥ {{ Number(recharging?.balance||0).toFixed(2) }}</b></div>
        <div class="mt-8">操作前：主账号可用余额 <b style="color:#059669">¥ {{ mainBalance.toFixed(2) }}</b></div>
      </div>
      <el-form class="mt-16" label-width="96px" :model="rcForm" :rules="rcRules" ref="rcRef">
        <el-form-item label="充值金额(¥)" prop="amount">
          <el-input-number v-model="rcForm.amount" :min="1" :precision="2" :step="50" style="width:100%" />
        </el-form-item>
        <el-form-item label="支付密码" prop="pwd">
          <el-input v-model="rcForm.pwd" type="password" show-password placeholder="演示填 123456" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="rcForm.remark" placeholder="选填，赠礼/促销/活动加赠等" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rechargeVisible=false">取消</el-button>
        <el-button type="success" @click="submitRecharge">确认充值</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="transferVisible" :title="'资金划转 · ' + (transferTarget?.username||'')" width="480px">
      <el-tabs v-model="tfTab">
        <el-tab-pane label="主 → 该账号" name="in" />
        <el-tab-pane label="该账号 → 主" name="out" />
      </el-tabs>
      <div v-if="transferTarget" class="transfer-head">
        <div class="tr-row"><span>主账号可用：</span><b class="ok">¥ {{ mainBalance.toFixed(2) }}</b></div>
        <div class="tr-row"><span>{{ transferTarget.username }} 当前：</span><b class="warn">¥ {{ Number(transferTarget.balance).toFixed(2) }}</b></div>
      </div>
      <el-form class="mt-12" label-width="96px" :model="tf" :rules="tfRules" ref="tfRef">
        <el-form-item label="划转金额(¥)" prop="amount">
          <el-input-number v-model="tf.amount" :min="1" :precision="2" :step="100" style="width:100%" />
        </el-form-item>
        <el-form-item label="支付密码" prop="pwd">
          <el-input v-model="tf.pwd" type="password" show-password placeholder="演示填 123456" />
        </el-form-item>
        <el-form-item label="备注"><el-input v-model="tf.remark" placeholder="选填，如月度预算" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="transferVisible=false">取消</el-button>
        <el-button type="primary" @click="submitTransfer">{{ tfTab === 'in' ? '立即划转' : '立即归集' }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Search, Plus, Edit, Money, Wallet, Notebook, Key, Delete, User, UserFilled
} from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import {
  getUserList, createUser, updateUser, deleteUser,
  rechargeUser, resetUserPassword
} from '@/api/system'
import { transferFunds, collectFunds, listWalletAccounts } from '@/api/wallet'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const isSuperAdmin = computed(() => userStore.roles.includes('super_admin'))
const isAdmin = computed(() => isSuperAdmin.value || userStore.roles.includes('admin'))
const mainName = computed(() => userStore.userInfo?.username || 'admin')
const mainBalance = computed(() => Number(userStore.userInfo?.balance || 99979))

const tab = ref('all')
const loading = ref(false)
const saving = ref(false)
const filters = reactive({ keyword: '', role: '', status: '', parentId: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })
const editVisible = ref(false)
const rechargeVisible = ref(false)
const transferVisible = ref(false)
const tfTab = ref('in')
const editing = ref(null)
const recharging = ref(null)
const transferTarget = ref(null)
const formRef = ref(null)
const rcRef = ref(null)
const tfRef = ref(null)

const roleOptions = ref([
  { code: 'super_admin', name: '超级管理员' },
  { code: 'admin', name: '平台管理员' },
  { code: 'finance', name: '财务' },
  { code: 'ops', name: '运营' },
  { code: 'dev', name: '开发' },
  { code: 'viewer', name: '只读' },
  { code: 'user', name: '普通用户' },
])
const bgs = [
  'linear-gradient(135deg,#3b82f6,#2563eb)',
  'linear-gradient(135deg,#10b981,#059669)',
  'linear-gradient(135deg,#f59e0b,#d97706)',
  'linear-gradient(135deg,#8b5cf6,#7c3aed)',
  'linear-gradient(135deg,#ef4444,#dc2626)',
  'linear-gradient(135deg,#14b8a6,#0d9488)',
  'linear-gradient(135deg,#6366f1,#4338ca)',
  'linear-gradient(135deg,#ec4899,#db2777)',
]
const rawList = ref([])

function buildInitialList() {
  const mainUsers = [
    { id: 1, username: 'lisa_cloud', userType: 'main', parentId: null, roles: ['user'], roleNames: ['主账号-全部权限'], email: 'lisa@metoe.io', phone: '138****8821', balance: 45320.88, totalRecharge: 60000, totalSpend: 14679.12, totalTransferred: 8000, status: 'active', verified: true, lastLoginAt: '今天 10:08', createdAt: '2025-12-18 09:30', bg: bgs[0], balanceUpdate: '2026-07-19 15:22' },
    { id: 2, username: 'global_ecom', userType: 'main', parentId: null, roles: ['user'], roleNames: ['主账号-全部权限'], email: 'ecom@metoe.io', phone: '139****6612', balance: 12580.50, totalRecharge: 20000, totalSpend: 7419.50, totalTransferred: 3000, status: 'active', verified: true, lastLoginAt: '今天 08:32', createdAt: '2026-01-22 16:12', bg: bgs[1], balanceUpdate: '2026-07-18 09:11' },
    { id: 3, username: 'hk_trade', userType: 'main', parentId: null, roles: ['user'], roleNames: ['主账号-全部权限'], email: 'trade@metoe.io', phone: '137****4408', balance: 2180.00, totalRecharge: 8000, totalSpend: 5820, totalTransferred: 0, status: 'active', verified: true, lastLoginAt: '昨天 17:20', createdAt: '2026-02-10 12:04', bg: bgs[2], balanceUpdate: '2026-07-12 14:55' },
    { id: 4, username: 'startup_x', userType: 'main', parentId: null, roles: ['user'], roleNames: ['主账号-全部权限'], email: 'startup@metoe.io', phone: '135****3377', balance: 560.00, totalRecharge: 3000, totalSpend: 2440, totalTransferred: 500, status: 'pending', verified: false, lastLoginAt: '3天前', createdAt: '2026-05-14 11:50', bg: bgs[3], balanceUpdate: '2026-07-01 10:00' },
  ]
  const adminUsers = [
    { id: 90, username: 'platform_root', userType: 'admin', parentId: null, roles: ['super_admin'], roleNames: ['超级管理员'], email: 'root@metoe.io', phone: '186****0001', balance: 999999, totalRecharge: 0, totalSpend: 0, totalTransferred: 0, status: 'active', verified: true, lastLoginAt: '刚刚', createdAt: '2025-06-01 00:00', bg: bgs[6], balanceUpdate: '—' },
    { id: 91, username: 'admin_lily', userType: 'admin', parentId: null, roles: ['admin'], roleNames: ['运营管理员'], email: 'lily@metoe.io', phone: '186****0002', balance: 0, totalRecharge: 0, totalSpend: 0, totalTransferred: 0, status: 'active', verified: true, lastLoginAt: '今天 09:20', createdAt: '2025-09-10 10:00', bg: bgs[7], balanceUpdate: '—' },
    { id: 92, username: 'security_ops', userType: 'admin', parentId: null, roles: ['admin'], roleNames: ['安全管理员'], email: 'sec@metoe.io', phone: '186****0003', balance: 0, totalRecharge: 0, totalSpend: 0, totalTransferred: 0, status: 'disabled', verified: true, lastLoginAt: '7天前', createdAt: '2025-10-15 10:00', bg: bgs[4], balanceUpdate: '—' },
  ]
  const subUsers = [
    { id: 101, username: 'finance_alice', userType: 'sub', parentId: 'admin', roles: ['finance'], roleNames: ['财务'], email: 'alice@metoe.io', phone: '138****2341', balance: 8500, totalRecharge: 0, totalSpend: 3500, totalTransferred: 12000, status: 'active', verified: false, lastLoginAt: '15分钟前 · 上海', createdAt: '2026-03-12 10:23', bg: bgs[0], balanceUpdate: '2026-07-05 09:44' },
    { id: 102, username: 'ops_bob', userType: 'sub', parentId: 'admin', roles: ['ops'], roleNames: ['运营'], email: 'bob@metoe.io', phone: '139****5621', balance: 3200, totalRecharge: 0, totalSpend: 1800, totalTransferred: 5000, status: 'active', verified: false, lastLoginAt: '今天 09:12', createdAt: '2026-04-02 14:51', bg: bgs[1], balanceUpdate: '2026-07-08 11:03' },
    { id: 103, username: 'dev_carol', userType: 'sub', parentId: 'admin', roles: ['dev'], roleNames: ['开发'], email: 'carol@metoe.io', phone: '137****8891', balance: 1560, totalRecharge: 0, totalSpend: 640, totalTransferred: 2200, status: 'active', verified: false, lastLoginAt: '2小时前', createdAt: '2026-04-20 09:07', bg: bgs[2], balanceUpdate: '2026-07-15 19:21' },
    { id: 104, username: 'audit_david', userType: 'sub', parentId: 'admin', roles: ['viewer'], roleNames: ['只读'], email: 'david@metoe.io', phone: '136****1122', balance: 480, totalRecharge: 0, totalSpend: 320, totalTransferred: 800, status: 'active', verified: false, lastLoginAt: '昨天 18:40', createdAt: '2026-05-08 20:14', bg: bgs[3], balanceUpdate: '2026-07-18 13:55' },
    { id: 105, username: 'ex_erin', userType: 'sub', parentId: 'admin', roles: ['ops'], roleNames: ['运营'], email: 'erin@metoe.io', phone: '135****3344', balance: 20, totalRecharge: 0, totalSpend: 480, totalTransferred: 500, status: 'disabled', verified: false, lastLoginAt: '3个月前', createdAt: '2026-01-15 15:32', bg: bgs[4], balanceUpdate: '2026-04-02 10:00' },
    { id: 106, username: 'ecom_market', userType: 'sub', parentId: 'global_ecom', roles: ['ops'], roleNames: ['运营'], email: 'market@global.io', phone: '139****9900', balance: 1200, totalRecharge: 0, totalSpend: 1800, totalTransferred: 3000, status: 'active', verified: false, lastLoginAt: '今天 09:55', createdAt: '2026-03-03 08:12', bg: bgs[5], balanceUpdate: '2026-07-10 12:00' },
  ]
  return [...adminUsers, ...mainUsers, ...subUsers]
}

const mainUsers = computed(() => rawList.value.filter(u => u.userType === 'main'))
const totalCount = computed(() => rawList.value.length)
const mainCount = computed(() => rawList.value.filter(u => u.userType === 'main').length)
const subCount = computed(() => rawList.value.filter(u => u.userType === 'sub').length)
const adminCount = computed(() => rawList.value.filter(u => u.userType === 'admin').length)
const verifiedCount = computed(() => rawList.value.filter(u => u.verified).length)
const totalBalance = computed(() => rawList.value.reduce((s, u) => s + Number(u.balance || 0), 0))
const subBalance = computed(() => rawList.value.filter(u => u.userType === 'sub').reduce((s, u) => s + Number(u.balance || 0), 0))
const activeThisMonth = computed(() => rawList.value.filter(u => u.status === 'active' && !String(u.lastLoginAt || '').includes('个月前')).length)

const filteredList = computed(() => {
  let arr = [...rawList.value]
  if (tab.value === 'main') arr = arr.filter(u => u.userType === 'main')
  else if (tab.value === 'sub') arr = arr.filter(u => u.userType === 'sub')
  else if (tab.value === 'admin') arr = arr.filter(u => u.userType === 'admin')
  else if (tab.value === 'disabled') arr = arr.filter(u => u.status === 'disabled')

  if (!isAdmin.value) {
    arr = arr.filter(u => u.username === mainName.value || u.parentId === mainName.value)
  }
  const k = String(filters.keyword || '').toLowerCase()
  if (k) arr = arr.filter(u =>
    String(u.username).toLowerCase().includes(k) ||
    String(u.email || '').toLowerCase().includes(k) ||
    String(u.phone || '').toLowerCase().includes(k)
  )
  if (filters.role) {
    const r = filters.role
    arr = arr.filter(u => {
      if (r === 'main') return u.userType === 'main'
      if (['super_admin','admin'].includes(r)) return u.roles?.includes(r)
      return u.userType === 'sub' && u.roles?.includes(r)
    })
  }
  if (filters.parentId) arr = arr.filter(u => u.parentId === filters.parentId || u.username === filters.parentId)
  if (filters.status) arr = arr.filter(u => u.status === filters.status)
  pagination.total = arr.length
  return arr
})

function onTabChange() { pagination.page = 1 }
function resetFilters() { Object.assign(filters, { keyword:'', role:'', status:'', parentId:'' }); pagination.page = 1 }
async function loadData() {
  loading.value = true
  try {
    const res = await getUserList({ page: pagination.page, pageSize: pagination.pageSize, ...filters }).catch(() => null)
    if (res?.data?.list?.length) {
      rawList.value = res.data.list.map(u => ({ ...u, statusSwitch: u.status === 'active', bg: bgs[Math.abs(u.id||0) % bgs.length] }))
      pagination.total = res.data.total
    } else {
      rawList.value = buildInitialList().map(u => ({ ...u, statusSwitch: u.status === 'active' }))
    }
  } catch (_) {
    rawList.value = buildInitialList().map(u => ({ ...u, statusSwitch: u.status === 'active' }))
  } finally { loading.value = false }
}

const defaultForm = () => ({ userType: 'sub', username: '', password: '', email: '', phone: '', parentId: mainName.value, roles: [], balance: 0, status: 'active' })
const form = reactive(defaultForm())
const rules = {
  username: [{ required: true, message: '请输入用户名' }, { min: 3, max: 20, message: '3-20位' }],
  password: [{ required: true, message: '请输入初始密码' }, { min: 6, max: 32, message: '6-32位' }],
  email: [{ required: true, message: '请输入邮箱' }, { type: 'email', message: '邮箱格式不正确' }],
  phone: [{ required: true, message: '请输入手机号' }, { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确' }],
  roles: [{ required: true, message: '请分配至少一个角色' }],
}
function openEdit(row) {
  editing.value = row
  if (row) {
    Object.assign(form, {
      userType: row.userType,
      username: row.username,
      email: row.email,
      phone: row.phone,
      parentId: row.parentId || '',
      roles: [...(row.roles || [])],
      balance: Number(row.balance || 0),
      status: row.status,
    })
  } else {
    Object.assign(form, defaultForm())
    form.parentId = mainName.value
    if (!isAdmin.value) { form.userType = 'sub'; form.roles = ['viewer'] }
  }
  editVisible.value = true
}
async function saveForm() {
  await formRef.value?.validate()
  saving.value = true
  try {
    if (editing.value) {
      await updateUser(editing.value.id, { ...form }).catch(() => null)
      Object.assign(editing.value, {
        email: form.email, phone: form.phone, roles: form.roles, roleNames: (form.roles||[]).map(r => roleOptions.value.find(o => o.code === r)?.name || r),
        balance: Number(form.balance), status: form.status, statusSwitch: form.status === 'active'
      })
      ElMessage.success('编辑已保存')
    } else {
      const payload = { ...form }
      let resId = Date.now()
      try {
        const res = await createUser(payload); if (res?.data?.id) resId = res.data.id
      } catch (_) {}
      const row = {
        id: resId, username: form.username, userType: form.userType, parentId: form.userType === 'sub' ? form.parentId : null,
        roles: [...form.roles], roleNames: form.roles.map(r => roleOptions.value.find(o => o.code === r)?.name || r),
        email: form.email, phone: form.phone, balance: Number(form.balance),
        totalRecharge: 0, totalSpend: 0, totalTransferred: 0, status: form.status, verified: false,
        lastLoginAt: '—', createdAt: new Date().toISOString().slice(0,16).replace('T',' '),
        bg: bgs[rawList.value.length % bgs.length], statusSwitch: form.status === 'active', balanceUpdate: new Date().toISOString().slice(0,16).replace('T',' ')
      }
      rawList.value.unshift(row)
      ElMessage.success('创建成功')
    }
    editVisible.value = false
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { saving.value = false }
}

function toggleStatus(row, val) {
  row.status = val
  ElMessage.success(`已${val === 'active' ? '启用' : '禁用'}用户 ${row.username}`)
}
function remove(row) {
  ElMessageBox.confirm(`确定删除用户 ${row.username}？删除后其下关联资源将被回收，操作不可撤销。`, '删除确认', { type: 'warning' })
    .then(async () => {
      await deleteUser(row.id).catch(() => null)
      const i = rawList.value.indexOf(row)
      if (i >= 0) rawList.value.splice(i, 1)
      ElMessage.success('删除成功')
    }).catch(() => { row.statusSwitch = row.status === 'active' })
}
async function resetPwd(row) {
  try {
    await resetUserPassword(row.id, { newPassword: 'Abc@123456' }).catch(() => null)
    ElMessage.success(`已重置 ${row.username} 的密码，并邮件发送新密码至 ${row.email}`)
  } catch (e) { ElMessage.error(e?.message || '重置失败') }
}

const rcForm = reactive({ amount: 500, pwd: '', remark: '' })
const rcRules = {
  amount: [{ required: true, type: 'number', min: 1, message: '请输入充值金额' }],
  pwd: [{ required: true, message: '请输入支付密码' }],
}
function openRecharge(row) { recharging.value = row; rcForm.amount = 500; rcForm.pwd = ''; rcForm.remark = ''; rechargeVisible.value = true }
async function submitRecharge() {
  await rcRef.value?.validate()
  if (rcForm.pwd !== '123456') { ElMessage.error('支付密码错误（演示密码：123456）'); return }
  try {
    await rechargeUser(recharging.value.id, { amount: rcForm.amount, remark: rcForm.remark }).catch(() => null)
    recharging.value.balance = Number((Number(recharging.value.balance) + Number(rcForm.amount)).toFixed(2))
    recharging.value.totalRecharge = Number((Number(recharging.value.totalRecharge) + Number(rcForm.amount)).toFixed(2))
    recharging.value.balanceUpdate = new Date().toISOString().slice(0,16).replace('T',' ')
    rechargeVisible.value = false
    ElMessage.success(`充值成功：¥${Number(rcForm.amount).toFixed(2)} → ${recharging.value.username}`)
  } catch (e) { ElMessage.error(e?.message || '充值失败') }
}

const tf = reactive({ amount: 500, pwd: '', remark: '' })
const tfRules = {
  amount: [{ required: true, type: 'number', min: 1, message: '请输入划转金额' }],
  pwd: [{ required: true, message: '请输入支付密码' }],
}
function openTransfer(row) {
  transferTarget.value = row
  tfTab.value = 'in'
  tf.amount = 500; tf.pwd = ''; tf.remark = ''
  transferVisible.value = true
}
async function submitTransfer() {
  await tfRef.value?.validate()
  if (tf.pwd !== '123456') { ElMessage.error('支付密码错误（演示密码：123456）'); return }
  try {
    const amt = Number(tf.amount)
    if (tfTab.value === 'in') {
      if (mainBalance.value < amt) throw new Error('主账号余额不足')
      await transferFunds({ fromUserId: mainName.value, toUserId: transferTarget.value.username, amount: amt, remark: tf.remark, operator: mainName.value })
      transferTarget.value.balance = Number((Number(transferTarget.value.balance) + amt).toFixed(2))
      transferTarget.value.totalTransferred = Number((Number(transferTarget.value.totalTransferred||0) + amt).toFixed(2))
      if (userStore.userInfo) userStore.userInfo.balance = Number((mainBalance.value - amt).toFixed(2))
      ElMessage.success(`划转到账：¥${amt.toFixed(2)} → ${transferTarget.value.username}`)
    } else {
      if (Number(transferTarget.value.balance) < amt) throw new Error(`${transferTarget.value.username} 余额不足`)
      await collectFunds({ fromUserId: transferTarget.value.username, toUserId: mainName.value, amount: amt, remark: tf.remark || '子账号余额归集', operator: mainName.value })
      transferTarget.value.balance = Number((Number(transferTarget.value.balance) - amt).toFixed(2))
      if (userStore.userInfo) userStore.userInfo.balance = Number((mainBalance.value + amt).toFixed(2))
      ElMessage.success(`归集成功：¥${amt.toFixed(2)} ← ${transferTarget.value.username}`)
    }
    transferTarget.value.balanceUpdate = new Date().toISOString().slice(0,16).replace('T',' ')
    transferVisible.value = false
  } catch (e) { ElMessage.error(e?.message || '划转失败') }
}
function goTransfer() { router.push('/wallet/transfer') }
function goFlow(row) {
  router.push(row ? `/wallet/funds?userId=${row.username}` : '/wallet/funds')
}
function goSubAccounts() { router.push('/subaccounts') }

onMounted(async () => {
  await loadData()
  try {
    const res = await listWalletAccounts(mainName.value)
    const map = Object.fromEntries((res?.data || []).map(a => [a.userId, a]))
    rawList.value.forEach(u => { if (map[u.username]) { u.balance = map[u.username].balance; u.balanceUpdate = map[u.username].lastUpdate } })
  } catch (_) {}
  if (route.query.userId) {
    const u = rawList.value.find(x => x.username === route.query.userId)
    if (u?.userType === 'sub') {
      tab.value = 'sub'
      filters.parentId = u.parentId
    }
  }
})
</script>
<style scoped>
.users-page { padding: 4px 2px 20px; }
.page-card { background: #fff; padding: 22px 22px 20px; border-radius: 14px; border: 1px solid #eef0f4; }
.stat-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 18px; }
.s-card { border-radius: 14px; padding: 18px 18px 16px; transition: transform .2s ease, box-shadow .2s ease; }
.s-card:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(0,0,0,.08); }
.s-card.c1 { background: linear-gradient(135deg,#eff6ff,#ede9fe); }
.s-card.c2 { background: linear-gradient(135deg,#ecfeff,#ecfdf5); }
.s-card.c3 { background: linear-gradient(135deg,#fff7ed,#fee2e2); }
.s-card.c4 { background: linear-gradient(135deg,#fef3c7,#ecfeff); }
.s-label { margin-bottom: 4px; }
.s-val { font-size: 28px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.s-val.ok { color: #059669; }
.s-val.warn { color: #d97706; }
.s-ft { margin-top: 8px; }

.user-tabs { margin-bottom: 12px; }
.user-tabs :deep(.el-tabs__item) { font-size: 14px; font-weight: 600; }
.user-tabs :deep(.el-tabs__active-bar) { background: #10b981; height: 3px; border-radius: 2px; }
.user-tabs :deep(.el-tabs__item.is-active) { color: #10b981; }

.flex-between { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.flex-row { display: flex; align-items: center; gap: 10px; }
.ml-8 { margin-left: 8px; }
.filter-bar { padding: 6px 2px 10px; border-bottom: 1px dashed #e5e7eb; margin-bottom: 6px; }
.name { font-size: 14px; color: #111827; }
.muted { color: #6b7280; } .small { font-size: 12px; }
.pagination-wrap { margin-top: 16px; display: flex; justify-content: flex-end; }

.transfer-head .tr-row { display: flex; justify-content: space-between; padding: 6px 0; }
.tr-row .ok { color: #059669; font-weight: 700; }
.tr-row .warn { color: #d97706; font-weight: 700; }
.mt-8 { margin-top: 8px; } .mt-12 { margin-top: 12px; } .mt-16 { margin-top: 16px; }
</style>
