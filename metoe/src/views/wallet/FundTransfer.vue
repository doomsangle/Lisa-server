<template>
  <div class="page-wrap">
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6">
        <div class="stat-card stat-green">
          <div class="stat-icon">
            <el-icon :size="28"><Wallet /></el-icon>
          </div>
          <div class="stat-content">
            <div class="stat-label">主账号可用余额</div>
            <div class="stat-value">¥ {{ formatMoney(stats.mainBalance) }}</div>
          </div>
        </div>
      </el-col>
      <el-col :span="6">
        <div class="stat-card stat-blue">
          <div class="stat-icon">
            <el-icon :size="28"><Coin /></el-icon>
          </div>
          <div class="stat-content">
            <div class="stat-label">子账号总余额</div>
            <div class="stat-value">¥ {{ formatMoney(stats.subTotal) }}</div>
          </div>
        </div>
      </el-col>
      <el-col :span="6">
        <div class="stat-card stat-orange">
          <div class="stat-icon">
            <el-icon :size="28"><Money /></el-icon>
          </div>
          <div class="stat-content">
            <div class="stat-label">今日已划转金额</div>
            <div class="stat-value">¥ {{ formatMoney(stats.monthTransferOut) }} / ¥ 100,000</div>
          </div>
        </div>
      </el-col>
      <el-col :span="6">
        <div class="stat-card stat-red">
          <div class="stat-icon">
            <el-icon :size="28"><Refresh /></el-icon>
          </div>
          <div class="stat-content">
            <div class="stat-label">待归集子账号余额</div>
            <div class="stat-value">¥ {{ formatMoney(pendingCollectAmount) }}</div>
          </div>
        </div>
      </el-col>
    </el-row>

    <el-card shadow="hover" class="main-card">
      <template #header>
        <div class="card-header">
          <b style="font-size: 16px;">
            <el-icon style="vertical-align: -3px; margin-right: 6px;"><Transfer /></el-icon>
            资金划转操作
          </b>
        </div>
      </template>

      <el-tabs v-model="activeTab" class="op-tabs">
        <el-tab-pane label="主账号 → 子账号 划转" name="transfer">
          <el-form :model="transferForm" label-width="120px" class="op-form">
            <el-form-item label="转出账号">
              <div class="account-box">
                <el-tag type="success" effect="dark" size="large" round>
                  <el-icon style="margin-right: 4px;"><Check /></el-icon>
                  {{ mainAccountName }}
                </el-tag>
                <span class="balance-tag">可用余额：¥ {{ formatMoney(transferForm.fromBalance) }}</span>
              </div>
            </el-form-item>
            <el-form-item label="接收子账号">
              <el-select v-model="transferForm.toUserId" placeholder="请选择接收子账号" style="width: 360px;" size="large">
                <el-option
                  v-for="acc in subAccounts"
                  :key="acc.userId"
                  :label="`${acc.name}（余额：¥${formatMoney(acc.balance)}）`"
                  :value="acc.userId"
                />
              </el-select>
            </el-form-item>
            <el-form-item label="划转金额">
              <el-input-number
                v-model="transferForm.amount"
                :min="1"
                :max="transferForm.fromBalance"
                :step="100"
                size="large"
                style="width: 360px;"
                controls-position="right"
                placeholder="请输入划转金额"
              />
              <span class="unit-tag">元</span>
              <div class="quick-amounts">
                <el-button
                  v-for="q in quickAmounts"
                  :key="q"
                  size="small"
                  type="primary"
                  plain
                  @click="transferForm.amount = Math.min(q, transferForm.fromBalance)"
                >
                  ¥ {{ q.toLocaleString() }}
                </el-button>
                <el-button size="small" type="primary" plain @click="transferForm.amount = transferForm.fromBalance">
                  全部余额
                </el-button>
              </div>
            </el-form-item>
            <el-form-item label="支付密码">
              <el-input
                v-model="transferForm.payPassword"
                type="password"
                placeholder="请输入支付密码（演示：123456）"
                size="large"
                style="width: 360px;"
                show-password
              />
            </el-form-item>
            <el-form-item label="备注">
              <el-input
                v-model="transferForm.remark"
                type="textarea"
                :rows="2"
                maxlength="100"
                show-word-limit
                placeholder="请输入划转备注（可选）"
                style="width: 360px;"
              />
            </el-form-item>
            <el-form-item>
              <el-button
                type="primary"
                size="large"
                class="transfer-btn"
                :loading="transferLoading"
                @click="doTransfer"
              >
                <el-icon style="margin-right: 6px;"><ArrowRight /></el-icon>
                立即划转
              </el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>

        <el-tab-pane label="子账号 → 主账号 归集" name="collect">
          <el-form :model="collectForm" label-width="120px" class="op-form">
            <el-form-item label="归集子账号">
              <el-select
                v-model="collectForm.fromUserId"
                placeholder="请选择要归集的子账号"
                style="width: 360px;"
                size="large"
                @change="onCollectAccountChange"
              >
                <el-option
                  v-for="acc in subAccounts"
                  :key="acc.userId"
                  :label="`${acc.name}（余额：¥${formatMoney(acc.balance)}）`"
                  :value="acc.userId"
                />
              </el-select>
              <div v-if="selectedCollectAccount" class="collect-info">
                <el-tag type="info" size="small">当前余额：¥ {{ formatMoney(selectedCollectAccount.balance) }}</el-tag>
                <el-tag type="warning" size="small" style="margin-left: 8px;">可归集最大金额：¥ {{ formatMoney(selectedCollectAccount.balance) }}</el-tag>
              </div>
            </el-form-item>
            <el-form-item label="归集方式">
              <el-radio-group v-model="collectForm.mode" size="large">
                <el-radio-button value="all">全部归集</el-radio-button>
                <el-radio-button value="custom">指定金额</el-radio-button>
              </el-radio-group>
            </el-form-item>
            <el-form-item v-if="collectForm.mode === 'custom'" label="归集金额">
              <el-input-number
                v-model="collectForm.amount"
                :min="1"
                :max="selectedCollectAccount?.balance || 0"
                :step="100"
                size="large"
                style="width: 360px;"
                controls-position="right"
                placeholder="请输入归集金额"
              />
              <span class="unit-tag">元</span>
            </el-form-item>
            <el-form-item label="安全密码">
              <el-input
                v-model="collectForm.payPassword"
                type="password"
                placeholder="请输入安全密码（演示：123456）"
                size="large"
                style="width: 360px;"
                show-password
              />
            </el-form-item>
            <el-form-item>
              <el-button
                type="primary"
                size="large"
                class="collect-btn"
                :loading="collectLoading"
                @click="doCollect"
              >
                <el-icon style="margin-right: 6px;"><Notebook /></el-icon>
                立即归集
              </el-button>
            </el-form-item>
          </el-form>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-card shadow="hover" class="table-card">
      <template #header>
        <div class="card-header flex-between">
          <b style="font-size: 16px;">
            <el-icon style="vertical-align: -3px; margin-right: 6px;"><Notebook /></el-icon>
            最近划转记录
          </b>
          <el-button type="primary" size="small" @click="goFunds">
            查看完整资金流向
            <el-icon style="margin-left: 4px;"><ArrowRight /></el-icon>
          </el-button>
        </div>
      </template>

      <el-table :data="recentFlow" stripe style="width: 100%;">
        <el-table-column prop="flowNo" label="流水号" width="200" show-overflow-tooltip />
        <el-table-column prop="time" label="时间" width="170" />
        <el-table-column label="类型" width="110">
          <template #default="{ row }">
            <el-tag v-if="row.type === 'transfer_out'" type="danger" effect="light" size="small">划转出</el-tag>
            <el-tag v-else-if="row.type === 'transfer_in'" type="success" effect="light" size="small">转入</el-tag>
            <el-tag v-else-if="row.type === 'recharge'" type="primary" effect="light" size="small">充值</el-tag>
            <el-tag v-else-if="row.type === 'spend'" type="warning" effect="light" size="small">消费</el-tag>
            <el-tag v-else-if="row.type === 'refund'" type="info" effect="light" size="small">退款</el-tag>
            <el-tag v-else size="small">{{ row.type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="金额" width="130" align="right">
          <template #default="{ row }">
            <span :class="Number(row.amount) >= 0 ? 'amount-in' : 'amount-out'">
              {{ Number(row.amount) >= 0 ? '+' : '' }}¥ {{ formatMoney(row.amount) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="operator" label="操作账号" width="140" />
        <el-table-column prop="counterparty" label="对手账号" width="140" />
        <el-table-column prop="remark" label="备注" show-overflow-tooltip />
        <el-table-column label="状态" width="80" align="center">
          <template #default>
            <el-tag type="success" effect="plain" size="small">成功</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'
import {
  Wallet, Coin, Money, Transfer, ArrowRight, Notebook, Refresh, Check
} from '@element-plus/icons-vue'
import {
  transferFunds, collectFunds, listWalletAccounts, getWalletStats, getFundFlow
} from '@/api/wallet'

const router = useRouter()
const userStore = useUserStore()

const activeTab = ref('transfer')
const stats = reactive({
  mainBalance: 99979,
  subTotal: 0,
  monthTransferOut: 0,
  monthTransferIn: 0
})
const subAccounts = ref([])
const recentFlow = ref([])
const transferLoading = ref(false)
const collectLoading = ref(false)
const quickAmounts = [100, 500, 1000, 5000]

const mainAccountName = computed(() => {
  return userStore.userInfo?.nickname || userStore.userInfo?.name || userStore.userInfo?.username || 'admin (主账号)'
})

const pendingCollectAmount = computed(() => {
  return subAccounts.value.reduce((s, a) => s + (Number(a.balance) > 0 ? Number(a.balance) : 0), 0)
})

const selectedCollectAccount = computed(() => {
  return subAccounts.value.find(a => a.userId === collectForm.fromUserId)
})

const transferForm = reactive({
  fromUserId: 'admin',
  fromBalance: 99979,
  toUserId: '',
  amount: 100,
  payPassword: '',
  remark: ''
})

const collectForm = reactive({
  fromUserId: '',
  mode: 'all',
  amount: 100,
  payPassword: '',
  remark: '余额归集'
})

function formatMoney(val) {
  const n = Number(val) || 0
  return n.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

async function loadStats() {
  try {
    const res = await getWalletStats()
    if (res.code === 0) {
      Object.assign(stats, res.data)
      transferForm.fromBalance = res.data.mainBalance || 0
    }
  } catch (e) {
    console.error(e)
  }
}

async function loadAccounts() {
  try {
    const res = await listWalletAccounts()
    if (res.code === 0) {
      const all = res.data || []
      const mainAcc = all.find(a => a.userId === 'admin')
      if (mainAcc) {
        transferForm.fromBalance = Number(mainAcc.balance) || 0
        stats.mainBalance = transferForm.fromBalance
      }
      subAccounts.value = all.filter(a => a.role === 'sub' && a.parentId === 'admin')
      stats.subTotal = subAccounts.value.reduce((s, a) => s + Number(a.balance || 0), 0)
    }
  } catch (e) {
    console.error(e)
  }
}

async function loadRecentFlow() {
  try {
    const res = await getFundFlow({ pageSize: 20 })
    if (res.code === 0) {
      recentFlow.value = (res.data?.list || []).slice(0, 20)
    }
  } catch (e) {
    console.error(e)
  }
}

function onCollectAccountChange() {
  if (collectForm.mode === 'custom' && selectedCollectAccount.value) {
    if (Number(collectForm.amount) > Number(selectedCollectAccount.value.balance)) {
      collectForm.amount = Number(selectedCollectAccount.value.balance)
    }
  }
}

async function doTransfer() {
  if (!transferForm.toUserId) {
    ElMessage.warning('请选择接收子账号')
    return
  }
  const amt = Number(transferForm.amount) || 0
  if (amt <= 0) {
    ElMessage.warning('划转金额必须大于 0')
    return
  }
  if (amt > Number(transferForm.fromBalance)) {
    ElMessage.warning('主账号余额不足')
    return
  }
  if (!transferForm.payPassword) {
    ElMessage.warning('请输入支付密码')
    return
  }
  if (transferForm.payPassword !== '123456') {
    ElMessage.error('支付密码错误（演示密码：123456）')
    return
  }
  transferLoading.value = true
  try {
    const res = await transferFunds({
      fromUserId: transferForm.fromUserId,
      toUserId: transferForm.toUserId,
      amount: amt,
      remark: transferForm.remark,
      operator: userStore.userInfo?.username || 'admin',
      payPassword: transferForm.payPassword
    })
    if (res.code === 0) {
      ElMessage.success(`划转成功：已向 ${transferForm.toUserId} 划转 ¥${formatMoney(amt)}`)
      transferForm.payPassword = ''
      transferForm.remark = ''
      transferForm.amount = 100
      transferForm.toUserId = ''
      await syncAfterChange()
    }
  } catch (e) {
    ElMessage.error(e.message || '划转失败')
  } finally {
    transferLoading.value = false
  }
}

async function doCollect() {
  if (!collectForm.fromUserId) {
    ElMessage.warning('请选择归集子账号')
    return
  }
  let amt
  if (collectForm.mode === 'all') {
    amt = Number(selectedCollectAccount.value?.balance) || 0
  } else {
    amt = Number(collectForm.amount) || 0
  }
  if (amt <= 0) {
    ElMessage.warning('归集金额必须大于 0')
    return
  }
  if (amt > Number(selectedCollectAccount.value?.balance || 0)) {
    ElMessage.warning('子账号余额不足')
    return
  }
  if (!collectForm.payPassword) {
    ElMessage.warning('请输入安全密码')
    return
  }
  if (collectForm.payPassword !== '123456') {
    ElMessage.error('安全密码错误（演示密码：123456）')
    return
  }
  collectLoading.value = true
  try {
    const res = await collectFunds({
      fromUserId: collectForm.fromUserId,
      toUserId: 'admin',
      amount: amt,
      operator: userStore.userInfo?.username || 'admin',
      remark: collectForm.remark
    })
    if (res.code === 0) {
      ElMessage.success(`归集成功：已从 ${collectForm.fromUserId} 归集 ¥${formatMoney(amt)} 至主账号`)
      collectForm.payPassword = ''
      collectForm.amount = 100
      collectForm.fromUserId = ''
      collectForm.mode = 'all'
      await syncAfterChange()
    }
  } catch (e) {
    ElMessage.error(e.message || '归集失败')
  } finally {
    collectLoading.value = false
  }
}

async function syncAfterChange() {
  await loadAccounts()
  await loadStats()
  await loadRecentFlow()
  if (userStore.userInfo) {
    userStore.userInfo.balance = transferForm.fromBalance
    try { localStorage.setItem('metoe_user', JSON.stringify(userStore.userInfo)) } catch (_) {}
  }
}

function goFunds() {
  router.push('/wallet/funds')
}

onMounted(async () => {
  await Promise.all([loadStats(), loadAccounts(), loadRecentFlow()])
})
</script>

<style scoped>
.page-wrap {
  padding: 16px;
}

.stats-row {
  margin-bottom: 16px;
}

.stat-card {
  border-radius: 14px;
  padding: 20px;
  color: #fff;
  display: flex;
  align-items: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  transition: all 0.3s ease;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.stat-card::after {
  content: '';
  position: absolute;
  top: -50%;
  right: -20%;
  width: 200px;
  height: 200px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 50%;
  transition: all 0.4s ease;
}

.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
}

.stat-card:hover::after {
  transform: scale(1.2);
}

.stat-green {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
}

.stat-blue {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.stat-orange {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.stat-red {
  background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16px;
  backdrop-filter: blur(4px);
}

.stat-content {
  flex: 1;
  z-index: 1;
}

.stat-label {
  font-size: 13px;
  opacity: 0.9;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

.main-card {
  border-radius: 14px;
  margin-bottom: 16px;
}

.main-card :deep(.el-card__header) {
  border-radius: 14px 14px 0 0;
}

.card-header {
  display: flex;
  align-items: center;
}

.flex-between {
  justify-content: space-between;
}

.op-tabs {
  margin-top: 4px;
}

.op-tabs :deep(.el-tabs__item) {
  font-size: 15px;
  height: 48px;
  line-height: 48px;
  font-weight: 500;
}

.op-tabs :deep(.el-tabs__active-bar) {
  height: 3px;
  border-radius: 2px;
}

.op-form {
  padding: 12px 8px 0;
}

.account-box {
  display: flex;
  align-items: center;
  gap: 12px;
}

.balance-tag {
  font-size: 13px;
  color: #67c23a;
  font-weight: 500;
}

.unit-tag {
  margin-left: 8px;
  color: #909399;
  font-size: 14px;
}

.quick-amounts {
  margin-top: 10px;
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.collect-info {
  margin-top: 10px;
}

.transfer-btn {
  background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
  border: none;
  padding: 0 36px;
  font-size: 15px;
  font-weight: 600;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(67, 233, 123, 0.35);
  transition: all 0.3s ease;
}

.transfer-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(67, 233, 123, 0.45);
}

.collect-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
  padding: 0 36px;
  font-size: 15px;
  font-weight: 600;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.35);
  transition: all 0.3s ease;
}

.collect-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(102, 126, 234, 0.45);
}

.table-card {
  border-radius: 14px;
}

.table-card :deep(.el-card__header) {
  border-radius: 14px 14px 0 0;
}

.amount-in {
  color: #67c23a;
  font-weight: 600;
}

.amount-out {
  color: #f56c6c;
  font-weight: 600;
}
</style>
