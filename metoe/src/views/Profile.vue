<template>
  <div class="settings-page">
    <div class="page-head">
      <div class="head-main">
        <h2 class="title">个人设置中心</h2>
        <p class="desc">在这里管理你的账户信息、账号安全、消息通知、显示偏好、资金安全与第三方绑定。</p>
      </div>
      <el-button class="back-btn" type="primary" plain :icon="Back" @click="$router.back()">返回上页</el-button>
    </div>

    <div class="profile-card" v-if="userStore.userInfo">
      <div class="left">
        <el-avatar :size="76" style="background:linear-gradient(135deg,#409eff,#10b981);font-size:30px">
          {{ (userStore.userInfo?.username || 'U').charAt(0).toUpperCase() }}
        </el-avatar>
        <div class="info">
          <div class="name-line">
            <span class="username">{{ userStore.userInfo?.username }}</span>
            <el-tag v-for="r in userStore.roles" :key="r" size="small" class="role-tag"
              :type="r==='super_admin'?'danger':(r==='admin'?'warning':'info')">{{ roleNames[r] || r }}</el-tag>
          </div>
          <div class="sub-line">
            <span>用户ID #{{ userStore.userInfo?.id }}</span>
            <span class="sep">·</span>
            <span>余额 <b style="color:#f59e0b">¥{{ userStore.userInfo?.balance || '0.00' }}</b></span>
            <span class="sep">·</span>
            <span>注册：{{ userStore.userInfo?.createdAt || '-' }}</span>
            <span class="sep">·</span>
            <span>最近登录：{{ userStore.userInfo?.lastLoginAt || '-' }}</span>
          </div>
        </div>
      </div>
      <div class="right-stats">
        <el-statistic title="已绑定渠道" :value="boundCount" style="color:#10b981" />
        <el-statistic title="安全分" :value="securityScore" :precision="0" style="color:#409eff" />
      </div>
    </div>

    <div class="tabs-wrap">
      <el-tabs v-model="activeTab" type="card">
        <!-- Tab 1: 基本信息 -->
        <el-tab-pane name="profile">
          <template #label><el-icon><User /></el-icon>&nbsp;基本信息</template>
          <div class="card-body">
            <el-form :model="form" :rules="rules" ref="formRef" label-width="120px">
              <el-row :gutter="20">
                <el-col :span="12">
                  <el-form-item label="用户名"><el-input :value="userStore.userInfo?.username" disabled /></el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="邮箱" prop="email">
                    <el-input v-model="form.email" placeholder="name@example.com">
                      <template #append>
                        <el-tag :type="bindings.email?.verified?'success':'warning'" effect="plain" size="small">
                          {{ bindings.email?.verified ? '已验证' : '未验证' }}
                        </el-tag>
                      </template>
                    </el-input>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="手机号" prop="phone">
                    <el-input v-model="form.phone" placeholder="国内手机号 11 位">
                      <template #append>
                        <el-tag :type="bindings.phone?.verified?'success':'warning'" effect="plain" size="small">
                          {{ bindings.phone?.verified ? '已验证' : '未验证' }}
                        </el-tag>
                      </template>
                    </el-input>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="微信号"><el-input v-model="form.wechat" placeholder="用于账单/异常通知" /></el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="QQ号"><el-input v-model="form.qq" placeholder="备用联系方式" /></el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="默认登录地">
                    <el-input :value="lastLoginFrom" disabled placeholder="系统自动记录" />
                  </el-form-item>
                </el-col>
              </el-row>
              <div class="form-actions">
                <el-button @click="loadProfileInfo"><el-icon><Refresh /></el-icon> 还原</el-button>
                <el-button type="primary" :loading="savingProfile" @click="saveProfile"><el-icon><CircleCheckFilled /></el-icon> 保存资料</el-button>
              </div>
            </el-form>
          </div>
        </el-tab-pane>

        <!-- Tab 2: 账号安全 -->
        <el-tab-pane name="security">
          <template #label><el-icon><Lock /></el-icon>&nbsp;账号安全</template>
          <div class="card-body">
            <el-alert type="info" show-icon :closable="false" class="mb-16">
              建议开启所有安全项以获得更高的安全评分。若启用支付密码后遗忘，请联系管理员手动重置。
            </el-alert>
            <el-table :data="secRows" border size="default">
              <el-table-column prop="name" label="安全项" width="180" />
              <el-table-column prop="desc" label="说明" min-width="220" />
              <el-table-column label="状态" width="120">
                <template #default="{row}">
                  <el-tag :type="row.on?'success':'danger'" effect="plain">{{ row.on ? '已开启' : '未开启' }}</el-tag>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="260" align="right">
                <template #default="{row}">
                  <el-button size="small" :type="row.on?'warning':'primary'" @click="row.action()" :icon="row.icon">
                    {{ row.btn }}
                  </el-button>
                </template>
              </el-table-column>
            </el-table>

            <h4 class="sec-title mt-20"><el-icon><Clock /></el-icon>&nbsp;最近登录记录</h4>
            <el-table :data="loginRecords" size="default" border empty-text="暂无登录记录">
              <el-table-column label="时间" prop="createdAt" width="200" />
              <el-table-column label="IP地址" prop="ip" width="160" />
              <el-table-column label="设备" prop="device" width="120" />
              <el-table-column label="说明" prop="summary" min-width="280" />
            </el-table>
            <div class="form-actions mt-8">
              <el-pagination small background layout="prev, pager, next, total"
                :total="loginTotal" :page-size="10" :current-page="loginPage" @current-change="loadLoginRecords" />
            </div>
          </div>
        </el-tab-pane>

        <!-- Tab 3: 消息通知 -->
        <el-tab-pane name="notify">
          <template #label><el-icon><Bell /></el-icon>&nbsp;消息通知</template>
          <div class="card-body">
            <h4 class="sec-title"><el-icon><Promotion /></el-icon>&nbsp;通知渠道（按偏好开关）</h4>
            <el-form label-width="180px">
              <el-form-item label="邮件通知"><el-switch v-model="notifyPrefs.notifyEmail" />
                <span class="hint">收到订单支付、扣费异常等邮件提醒</span></el-form-item>
              <el-form-item label="短信通知"><el-switch v-model="notifyPrefs.notifySms" />
                <span class="hint">短信下发需绑定已验证的手机号，欠费告警专用</span></el-form-item>
              <el-form-item label="微信公众号推送"><el-switch v-model="notifyPrefs.notifyWechat" />
                <span class="hint">需要先绑定微信号，支持每日账单汇总推送</span></el-form-item>
              <el-form-item label="站内信铃声"><el-switch v-model="notifyPrefs.notifyInappSound" />
                <span class="hint">浏览器内收到新通知时播放提示音</span></el-form-item>
              <el-form-item label="仅重要通知"><el-switch v-model="notifyPrefs.notifyImportantOnly" />
                <span class="hint">过滤营销/活动类推送，仅保留安全告警、订单失败类通知</span></el-form-item>
            </el-form>
            <el-divider />
            <div class="form-actions">
              <el-button @click="loadSettings"><el-icon><Refresh /></el-icon> 还原</el-button>
              <el-button type="primary" :loading="savingNotify" @click="saveNotify"><el-icon><CircleCheckFilled /></el-icon> 保存通知设置</el-button>
            </div>
          </div>
        </el-tab-pane>

        <!-- Tab 4: 显示偏好 -->
        <el-tab-pane name="display">
          <template #label><el-icon><Brush /></el-icon>&nbsp;显示偏好</template>
          <div class="card-body">
            <el-form label-width="160px">
              <el-row :gutter="20">
                <el-col :span="12">
                  <el-form-item label="界面语言">
                    <el-select v-model="display.lang" style="width:100%">
                      <el-option label="简体中文" value="zh-CN" />
                      <el-option label="繁體中文" value="zh-HK" />
                      <el-option label="English" value="en-US" />
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="主题模式">
                    <el-radio-group v-model="display.theme">
                      <el-radio-button label="light">浅色</el-radio-button>
                      <el-radio-button label="dark">深色</el-radio-button>
                      <el-radio-button label="auto">跟随系统</el-radio-button>
                    </el-radio-group>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="时区">
                    <el-select v-model="display.timezone" style="width:100%">
                      <el-option v-for="tz in TZ_OPTS" :key="tz.v" :label="tz.l" :value="tz.v" />
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="显示密度">
                    <el-radio-group v-model="display.density">
                      <el-radio-button label="compact">紧凑</el-radio-button>
                      <el-radio-button label="default">默认</el-radio-button>
                      <el-radio-button label="loose">宽松</el-radio-button>
                    </el-radio-group>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="列表默认条数">
                    <el-select v-model="display.pageSize" style="width:100%">
                      <el-option :value="10" label="10 条 / 页" />
                      <el-option :value="20" label="20 条 / 页" />
                      <el-option :value="50" label="50 条 / 页" />
                      <el-option :value="100" label="100 条 / 页" />
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="金额显示小数位数">
                    <el-input-number v-model="display.decimals" :min="0" :max="6" :step="1" style="width:100%" />
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="金额展示币种">
                    <el-select v-model="display.currency" style="width:100%">
                      <el-option label="人民币 ¥ CNY" value="CNY" />
                      <el-option label="美元 $ USD" value="USD" />
                      <el-option label="港币 HK$ HKD" value="HKD" />
                    </el-select>
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="登录后默认首页">
                    <el-select v-model="display.homeDefault" style="width:100%">
                      <el-option label="控制台 Dashboard" value="/dashboard" />
                      <el-option label="已购服务器" value="/servers" />
                      <el-option label="我的订单" value="/orders" />
                      <el-option label="充值中心" value="/recharge" />
                      <el-option label="子账号管理" value="/subaccounts" />
                    </el-select>
                  </el-form-item>
                </el-col>
              </el-row>
              <el-divider />
              <el-form-item label="侧边栏折叠"><el-switch v-model="display.sidebarCollapsed" /></el-form-item>
              <el-form-item label="隐藏 0 余额子账号"><el-switch v-model="display.hideZeroBalance" /></el-form-item>
            </el-form>
            <div class="form-actions">
              <el-button @click="loadSettings"><el-icon><Refresh /></el-icon> 还原</el-button>
              <el-button type="primary" :loading="savingDisplay" @click="saveDisplay"><el-icon><CircleCheckFilled /></el-icon> 保存显示偏好</el-button>
            </div>
          </div>
        </el-tab-pane>

        <!-- Tab 5: 资金安全 -->
        <el-tab-pane name="finance">
          <template #label><el-icon><Money /></el-icon>&nbsp;资金安全</template>
          <div class="card-body">
            <h4 class="sec-title">支付密码</h4>
            <el-descriptions :column="2" border size="default" class="mb-16">
              <el-descriptions-item label="支付密码状态">
                <el-tag :type="safety.payPassword?'success':'warning'" effect="plain">{{ safety.payPassword ? '已设置' : '未设置' }}</el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="上次修改登录密码">{{ safety.lastPwdChangedAt || '从未' }}</el-descriptions-item>
              <el-descriptions-item label="消费二次确认">
                <el-switch v-model="finPrefs.payConfirmEnable" />
                <span class="hint">订单支付、资金划转前必须再确认一次（建议开启）</span>
              </el-descriptions-item>
              <el-descriptions-item label="账户余额">¥ {{ userStore.userInfo?.balance || '0.00' }}</el-descriptions-item>
            </el-descriptions>
            <el-form :model="payPwd" :rules="payRules" ref="payRef" label-width="140px">
              <el-row :gutter="20">
                <el-col :span="8">
                  <el-form-item :label="safety.payPassword?'原支付密码':'新支付密码'" prop="oldPwd">
                    <el-input v-model="payPwd.oldPwd" type="password" show-password
                      :placeholder="safety.payPassword?'请输入原支付密码':'6-32 位字母数字符号'" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item v-if="safety.payPassword" label="新支付密码" prop="password">
                    <el-input v-model="payPwd.password" type="password" show-password placeholder="6-32 位字母数字符号" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item v-if="safety.payPassword" label="确认新支付密码" prop="confirm">
                    <el-input v-model="payPwd.confirm" type="password" show-password placeholder="再次输入新支付密码" />
                  </el-form-item>
                </el-col>
              </el-row>
              <div class="form-actions">
                <el-button type="primary" :loading="savingPay" @click="savePayPwd">
                  <el-icon><Lock /></el-icon>&nbsp;{{ safety.payPassword ? '修改支付密码' : '立即设置支付密码' }}
                </el-button>
              </div>
            </el-form>
            <el-divider />
            <h4 class="sec-title">自动续费（低余额自动充值）</h4>
            <el-form label-width="200px">
              <el-form-item label="启用自动续费">
                <el-switch v-model="finPrefs.autoRechargeEnable" />
                <span class="hint">当账户余额低于阈值时，自动从默认付款方式补充资金（Demo：仅保存策略，需配合支付渠道回调启用）</span>
              </el-form-item>
              <el-row :gutter="20">
                <el-col :span="12">
                  <el-form-item label="触发阈值（¥）">
                    <el-input-number v-model="finPrefs.autoRechargeThreshold" :min="0" :max="999999" :step="10" style="width:100%" />
                  </el-form-item>
                </el-col>
                <el-col :span="12">
                  <el-form-item label="每次充值金额（¥）">
                    <el-input-number v-model="finPrefs.autoRechargeAmount" :min="1" :max="999999" :step="50" style="width:100%" />
                  </el-form-item>
                </el-col>
              </el-row>
            </el-form>
            <div class="form-actions">
              <el-button @click="loadSettings"><el-icon><Refresh /></el-icon> 还原</el-button>
              <el-button type="primary" :loading="savingFin" @click="saveFin"><el-icon><CircleCheckFilled /></el-icon> 保存资金安全策略</el-button>
            </div>
          </div>
        </el-tab-pane>

        <!-- Tab 6: 绑定状态 -->
        <el-tab-pane name="bind">
          <template #label><el-icon><Connection /></el-icon>&nbsp;绑定与验证</template>
          <div class="card-body">
            <el-alert title="演示环境说明" type="warning" show-icon :closable="false" class="mb-16">
              发送验证码功能对接三方前以 Demo 模式运行：统一使用万用验证码 <b>CODE000000</b> 验证。
            </el-alert>
            <el-table :data="bindRows" border size="default">
              <el-table-column label="渠道" width="120">
                <template #default="{row}">
                  <span style="font-weight:600"><el-icon style="vertical-align:-2px;margin-right:4px"><component :is="row.icon" /></el-icon>{{ row.name }}</span>
                </template>
              </el-table-column>
              <el-table-column label="当前绑定值" prop="value">
                <template #default="{row}">{{ row.value || '尚未填写' }}</template>
              </el-table-column>
              <el-table-column label="验证状态" width="130">
                <template #default="{row}">
                  <el-tag :type="row.verified?'success':'info'" effect="plain">
                    {{ row.supportVerify ? (row.verified ? '已验证' : '未验证') : '无需验证' }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="280" align="right">
                <template #default="{row}">
                  <el-button size="small" type="primary" plain @click="openBindDialog(row)" :icon="row.verified ? Refresh : Plus">
                    {{ row.verified ? '换绑' : (row.value ? '去验证' : '去绑定') }}
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 绑定对话框 -->
    <el-dialog v-model="bindDlg.visible" :title="'绑定 / 验证 ' + (bindDlg.row?.name || '')" width="520px">
      <el-form :model="bindDlg" label-width="100px">
        <el-form-item label="目标值" v-if="bindDlg.row?.inputTarget">
          <el-input v-model="bindDlg.target" :placeholder="bindDlg.row?.ph" />
        </el-form-item>
        <el-form-item label="目标值" v-else>
          <el-input :value="bindDlg.row?.value || '-' " disabled />
        </el-form-item>
        <el-form-item label="验证码">
          <el-input v-model="bindDlg.code" placeholder="请输入验证码（演示 CODE000000）">
            <template #append>
              <el-button :disabled="bindDlg.countdown > 0" type="primary" plain @click="sendCode">
                {{ bindDlg.countdown > 0 ? bindDlg.countdown + 's' : '获取验证码' }}
              </el-button>
            </template>
          </el-input>
        </el-form-item>
        <el-form-item label="提示">
          <el-tag size="small" type="warning" effect="plain">演示环境统一使用 CODE000000 作为验证码</el-tag>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="bindDlg.visible=false">取消</el-button>
        <el-button type="primary" :loading="bindDlg.submitting" @click="submitBind">确认验证</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  User, Lock, Bell, Brush, Money, Connection, Back, Refresh,
  CircleCheckFilled, Promotion, Clock, Plus, Iphone, Message, Monitor
} from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import {
  getProfile, updateProfile, changePassword, resetApiKey,
  getSettings, updateSettings, getBindings, sendBindingCode, verifyBinding,
  setPayPassword, getLoginRecords,
} from '@/api/auth'
import { useRouter } from 'vue-router'

const router = useRouter()
const userStore = useUserStore()
const activeTab = ref('profile')
const formRef = ref()
const payRef = ref()

const TZ_OPTS = [
  { l: '(UTC+08:00) 亚洲/上海  Asia/Shanghai', v: 'Asia/Shanghai' },
  { l: '(UTC+09:00) 亚洲/东京  Asia/Tokyo', v: 'Asia/Tokyo' },
  { l: '(UTC+08:00) 亚洲/香港  Asia/Hong_Kong', v: 'Asia/Hong_Kong' },
  { l: '(UTC+00:00) 伦敦 GMT', v: 'Europe/London' },
  { l: '(UTC-04:00) 纽约  America/New_York', v: 'America/New_York' },
  { l: '(UTC-07:00) 洛杉矶 America/Los_Angeles', v: 'America/Los_Angeles' },
  { l: '(UTC+01:00) 柏林 Europe/Berlin', v: 'Europe/Berlin' },
  { l: '(UTC+10:00) 悉尼 Australia/Sydney', v: 'Australia/Sydney' },
]

const form = reactive({ email: '', phone: '', wechat: '', qq: '' })
const rules = {
  email: [
    { required: true, message: '邮箱不能为空' },
    { type: 'email', message: '邮箱格式错误' },
  ],
}
const pwdForm = reactive({ old: '', password: '', confirm: '' })
const pwdRules = {
  old: [{ required: true, message: '请输入原密码' }],
  password: [
    { required: true, message: '请输入新密码' },
    { min: 6, message: '新密码至少 6 位' },
  ],
  confirm: [{ validator: (_r, v, cb) => v === pwdForm.password ? cb() : cb(new Error('两次新密码不一致')), trigger: 'blur' }],
}
const payPwd = reactive({ oldPwd: '', password: '', confirm: '' })
const payRules = {
  oldPwd: [{ required: true, message: '请输入支付密码' }, { min: 6, max: 32, message: '6-32 位' }],
  password: [{ required: true, message: '请输入新支付密码' }, { min: 6, max: 32, message: '6-32 位' }],
  confirm: [{ validator: (_r, v, cb) => v === payPwd.password ? cb() : cb(new Error('两次新支付密码不一致')), trigger: 'blur' }],
}
const display = reactive({
  lang: 'zh-CN', theme: 'light', timezone: 'Asia/Shanghai', density: 'default',
  pageSize: 20, currency: 'CNY', decimals: 2, homeDefault: '/dashboard',
  sidebarCollapsed: false, hideZeroBalance: false,
})
const notifyPrefs = reactive({
  notifySms: false, notifyEmail: true, notifyWechat: false, notifyInappSound: true, notifyImportantOnly: false,
})
const finPrefs = reactive({
  payConfirmEnable: true, autoRechargeEnable: false, autoRechargeThreshold: 100, autoRechargeAmount: 500,
})

const bindings = reactive({ email: {}, phone: {}, wechat: {}, qq: {} })
const safety = reactive({ apiKey: false, payPassword: false, totpEnabled: false, lastPwdChangedAt: '' })
const savingProfile = ref(false)
const savingDisplay = ref(false)
const savingNotify = ref(false)
const savingFin = ref(false)
const savingPay = ref(false)
const resettingKey = ref(false)
const resettingPwd = ref(false)

const bindRows = ref([])
const bindDlg = reactive({
  visible: false, submitting: false, countdown: 0,
  row: null, channel: '', target: '', code: '',
})

const loginRecords = ref([])
const loginTotal = ref(0)
const loginPage = ref(1)
const lastLoginFrom = ref('-')

const roleNames = {
  super_admin: '超级管理员', admin: '管理员', finance: '财务', support: '客服', user: '普通用户',
}

const boundCount = computed(() => {
  let cnt = 0
  for (const k of ['email', 'phone', 'wechat', 'qq']) if (bindings[k]?.value) cnt++
  if (safety.apiKey) cnt++
  if (safety.payPassword) cnt++
  if (safety.totpEnabled) cnt++
  return cnt
})

const securityScore = computed(() => {
  let score = 40
  if (bindings.email?.verified) score += 10
  if (bindings.phone?.verified) score += 10
  if (safety.payPassword) score += 10
  if (safety.apiKey) score += 10
  if (safety.totpEnabled) score += 10
  if (finPrefs.payConfirmEnable) score += 5
  if (notifyPrefs.notifyEmail) score += 5
  return Math.min(100, score)
})

const secRows = computed(() => [
  { name: '登录密码', desc: '用于登录平台账户，建议 90 天更换', on: true, btn: '修改密码', icon: Lock, action: () => openResetPwd() },
  { name: '支付密码', desc: '用于订单支付、资金划转二次校验', on: safety.payPassword, btn: safety.payPassword ? '修改' : '立即设置', icon: Money, action: () => { activeTab.value = 'finance' } },
  { name: 'API Key', desc: '开放平台开发者凭证，遗忘不可恢复', on: safety.apiKey, btn: safety.apiKey ? '重置 Key' : '立即生成', icon: Lock, action: () => doResetApiKey() },
  { name: '两步验证（TOTP）', desc: '基于时间的动态口令，Demo 版预留开关', on: safety.totpEnabled, btn: '（演示中，暂不支持）', icon: Lock, action: () => ElMessage.warning('演示环境未启用 TOTP') },
  { name: '消费二次确认', desc: '消费前必须再次确认避免误操作', on: finPrefs.payConfirmEnable, btn: finPrefs.payConfirmEnable ? '去关闭' : '去开启', icon: CircleCheckFilled, action: () => { activeTab.value = 'finance' } },
  { name: '邮箱验证', desc: '用于安全告警、密码找回邮件', on: bindings.email?.verified, btn: bindings.email?.verified ? '换绑' : '去验证', icon: Message, action: () => openBindDialog(findBindRow('email')) },
  { name: '手机号验证', desc: '欠费/异常告警短信下发', on: bindings.phone?.verified, btn: bindings.phone?.verified ? '换绑' : '去验证', icon: Iphone, action: () => openBindDialog(findBindRow('phone')) },
])

function findBindRow(ch) { return bindRows.value.find(r => r.channel === ch) }

function reloadBindRows() {
  bindRows.value = [
    { channel: 'email', name: '邮箱', value: bindings.email?.value || '', verified: !!bindings.email?.verified,
      inputTarget: true, supportVerify: true, ph: 'name@example.com', icon: Message },
    { channel: 'phone', name: '手机号', value: bindings.phone?.value || '', verified: !!bindings.phone?.verified,
      inputTarget: true, supportVerify: true, ph: '11 位中国手机号', icon: Iphone },
    { channel: 'wechat', name: '微信号', value: bindings.wechat?.value || '', verified: !!bindings.wechat?.verified,
      inputTarget: true, supportVerify: false, ph: '绑定微信用于每日账单推送', icon: Monitor },
    { channel: 'qq', name: 'QQ号', value: bindings.qq?.value || '', verified: !!bindings.qq?.verified,
      inputTarget: true, supportVerify: false, ph: '备用联系方式', icon: Monitor },
    { channel: 'totp', name: 'TOTP 两步验证', value: safety.totpEnabled ? '已配置' : '未配置', verified: safety.totpEnabled,
      inputTarget: false, supportVerify: false, icon: Lock },
    { channel: 'payPassword', name: '支付密码', value: safety.payPassword ? '已设置' : '未设置', verified: safety.payPassword,
      inputTarget: false, supportVerify: false, icon: Money },
    { channel: 'apiKey', name: 'API Key', value: safety.apiKey ? '已生成' : '未生成', verified: safety.apiKey,
      inputTarget: false, supportVerify: false, icon: Lock },
  ]
}

function loadProfileInfo() {
  const u = userStore.userInfo || {}
  form.email = u.email || ''
  form.phone = u.phone || ''
  form.wechat = u.wechat || ''
  form.qq = u.qq || ''
}

async function loadAll() {
  try {
    const prof = await getProfile()
    userStore.userInfo = prof.user
    userStore.roles = prof.roles || []
    userStore.permissions = prof.permissions || []
    try { localStorage.setItem('metoe_user', JSON.stringify(prof.user)) } catch {}
    Object.assign(bindings, prof.bindings || {})
    Object.assign(safety, prof.safety || {})
    Object.assign(display, {
      lang: prof.settings?.lang || 'zh-CN',
      theme: prof.settings?.theme || 'light',
      timezone: prof.settings?.timezone || 'Asia/Shanghai',
      density: prof.settings?.density || 'default',
      pageSize: prof.settings?.pageSize || 20,
      decimals: prof.settings?.decimals ?? 2,
      currency: prof.settings?.currency || 'CNY',
      homeDefault: prof.settings?.homeDefault || '/dashboard',
      sidebarCollapsed: !!prof.settings?.sidebarCollapsed,
      hideZeroBalance: !!prof.settings?.hideZeroBalance,
    })
    Object.assign(notifyPrefs, {
      notifySms: !!prof.settings?.notifySms,
      notifyEmail: prof.settings?.notifyEmail !== false,
      notifyWechat: !!prof.settings?.notifyWechat,
      notifyInappSound: prof.settings?.notifyInappSound !== false,
      notifyImportantOnly: !!prof.settings?.notifyImportantOnly,
    })
    Object.assign(finPrefs, {
      payConfirmEnable: prof.settings?.payConfirmEnable !== false,
      autoRechargeEnable: !!prof.settings?.autoRechargeEnable,
      autoRechargeThreshold: prof.settings?.autoRechargeThreshold ?? 100,
      autoRechargeAmount: prof.settings?.autoRechargeAmount ?? 500,
    })
    loadProfileInfo()
    reloadBindRows()
  } catch (e) {
    ElMessage.error(e?.message || '加载个人信息失败')
  }
}

async function loadSettings() {
  try {
    const s = await getSettings()
    Object.assign(display, {
      lang: s.lang || 'zh-CN', theme: s.theme || 'light',
      timezone: s.timezone || 'Asia/Shanghai', density: s.density || 'default',
      pageSize: s.pageSize || 20, decimals: s.decimals ?? 2,
      currency: s.currency || 'CNY', homeDefault: s.homeDefault || '/dashboard',
      sidebarCollapsed: !!s.sidebarCollapsed, hideZeroBalance: !!s.hideZeroBalance,
    })
    Object.assign(notifyPrefs, {
      notifySms: !!s.notifySms, notifyEmail: s.notifyEmail !== false, notifyWechat: !!s.notifyWechat,
      notifyInappSound: s.notifyInappSound !== false, notifyImportantOnly: !!s.notifyImportantOnly,
    })
    Object.assign(finPrefs, {
      payConfirmEnable: s.payConfirmEnable !== false,
      autoRechargeEnable: !!s.autoRechargeEnable,
      autoRechargeThreshold: s.autoRechargeThreshold ?? 100,
      autoRechargeAmount: s.autoRechargeAmount ?? 500,
    })
  } catch (e) {
    ElMessage.error(e?.message || '加载设置失败')
  }
}

async function loadBindings() {
  try {
    const b = await getBindings()
    Object.assign(bindings, b || {})
    reloadBindRows()
  } catch (_) {}
}

async function loadLoginRecords(p = 1) {
  loginPage.value = p
  try {
    const r = await getLoginRecords({ page: p, page_size: 10 })
    loginRecords.value = r.list || []
    loginTotal.value = r.total || 0
    if (loginRecords.value[0]?.ip) lastLoginFrom.value = loginRecords.value[0].ip
  } catch (_) {}
}

async function saveProfile() {
  try { await formRef.value.validate() } catch { return }
  savingProfile.value = true
  try {
    await updateProfile({ email: form.email, phone: form.phone || null, wechat: form.wechat || null, qq: form.qq || null })
    ElMessage.success('个人资料已更新')
    await userStore.fetchProfile()
    loadProfileInfo()
    await loadBindings()
    reloadBindRows()
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { savingProfile.value = false }
}

function openResetPwd() {
  ElMessageBox.prompt('请先输入当前登录密码，再点击确定进行密码修改引导', '修改登录密码（步骤 1/2）', {
    confirmButtonText: '下一步', cancelButtonText: '取消', type: 'warning', inputType: 'password',
    inputValidator: v => (v && v.length >= 6) || '至少 6 位'
  }).then(({ value: oldV }) => {
    pwdForm.old = oldV
    ElMessageBox.prompt('请输入新的登录密码（至少 6 位）', '修改登录密码（步骤 2/2）', {
      confirmButtonText: '确认修改', cancelButtonText: '取消', type: 'warning', inputType: 'password',
      inputValidator: v => (v && v.length >= 6) || '至少 6 位'
    }).then(({ value: newV }) => {
      pwdForm.password = newV
      doChangePwd()
    }).catch(() => {})
  }).catch(() => {})
}

async function doChangePwd() {
  resettingPwd.value = true
  try {
    await changePassword({ old: pwdForm.old, password: pwdForm.password })
    ElMessage.success('密码已更新，请重新登录')
    pwdForm.old = ''; pwdForm.password = ''; pwdForm.confirm = ''
    setTimeout(() => userStore.logout(true), 600)
  } catch (e) { ElMessage.error(e?.message || '密码修改失败') }
  finally { resettingPwd.value = false }
}

async function doResetApiKey() {
  try {
    await ElMessageBox.confirm(
      `重置 API Key 会立即使旧 Key 失效。${safety.apiKey ? '确认继续？' : '立即生成新的开发者 Key？'}`,
      '确认操作', { type: 'warning' }
    )
  } catch { return }
  resettingKey.value = true
  try {
    const r = await resetApiKey()
    const newKey = r?.apiKey
    await userStore.fetchProfile()
    await loadAll()
    if (newKey) {
      await ElMessageBox.alert(
        `新的 API Key：<br/><b style="font-family:monospace; font-size:13px">${newKey}</b><br/><br/>此 Key 仅显示一次，关闭后无法再查看完整值！`,
        'API Key 已生成', { dangerouslyUseHTMLString: true, type: 'success', confirmButtonText: '我已保存' }
      )
    }
    ElMessage.success('操作完成')
  } catch (e) { ElMessage.error(e?.message || '重置失败') }
  finally { resettingKey.value = false }
}

async function saveNotify() {
  savingNotify.value = true
  try {
    const payload = {
      notify_sms: notifyPrefs.notifySms ? 1 : 0,
      notify_email: notifyPrefs.notifyEmail ? 1 : 0,
      notify_wechat: notifyPrefs.notifyWechat ? 1 : 0,
      notify_inapp_sound: notifyPrefs.notifyInappSound ? 1 : 0,
      notify_important_only: notifyPrefs.notifyImportantOnly ? 1 : 0,
    }
    await updateSettings(payload)
    ElMessage.success('通知设置已保存')
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { savingNotify.value = false }
}

async function saveDisplay() {
  savingDisplay.value = true
  try {
    const payload = {
      lang: display.lang, theme: display.theme, timezone: display.timezone,
      density: display.density, page_size: display.pageSize,
      sidebar_collapsed: display.sidebarCollapsed ? 1 : 0,
      currency: display.currency, home_default: display.homeDefault,
      hide_zero_balance: display.hideZeroBalance ? 1 : 0,
      decimals: display.decimals,
    }
    await updateSettings(payload)
    ElMessage.success('显示偏好已保存')
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { savingDisplay.value = false }
}

async function saveFin() {
  savingFin.value = true
  try {
    const payload = {
      pay_confirm_enable: finPrefs.payConfirmEnable ? 1 : 0,
      auto_recharge_enable: finPrefs.autoRechargeEnable ? 1 : 0,
      auto_recharge_threshold: finPrefs.autoRechargeEnable ? Number(finPrefs.autoRechargeThreshold) : null,
      auto_recharge_amount: finPrefs.autoRechargeEnable ? Number(finPrefs.autoRechargeAmount) : null,
    }
    await updateSettings(payload)
    ElMessage.success('资金安全策略已保存')
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { savingFin.value = false }
}

async function savePayPwd() {
  try { await payRef.value.validate() } catch { return }
  if (safety.payPassword && payPwd.password !== payPwd.confirm) {
    ElMessage.error('两次输入的新支付密码不一致'); return
  }
  savingPay.value = true
  try {
    const payload = safety.payPassword
      ? { old_password: payPwd.oldPwd, password: payPwd.password }
      : { password: payPwd.oldPwd || payPwd.password }
    await setPayPassword(payload)
    ElMessage.success(safety.payPassword ? '支付密码已修改' : '支付密码设置成功')
    payPwd.oldPwd = ''; payPwd.password = ''; payPwd.confirm = ''
    await loadAll()
  } catch (e) { ElMessage.error(e?.message || '保存失败') }
  finally { savingPay.value = false }
}

function openBindDialog(row) {
  if (!row) return
  activeTab.value = 'bind'
  bindDlg.channel = row.channel
  bindDlg.row = row
  bindDlg.target = row.value || ''
  bindDlg.code = ''
  bindDlg.countdown = 0
  bindDlg.submitting = false
  bindDlg.visible = true
}

async function sendCode() {
  if (['totp', 'payPassword', 'apiKey', 'qq'].includes(bindDlg.channel) || !bindDlg.row?.supportVerify) {
    ElMessage.info('该渠道无需验证码，直接保存即可（或走相应 Tab 操作）')
    bindDlg.visible = false
    return
  }
  try {
    await sendBindingCode({ channel: bindDlg.channel, target: bindDlg.target || undefined })
    ElMessage.success('验证码已发送，演示环境使用 CODE000000')
    bindDlg.countdown = 60
    const t = setInterval(() => {
      bindDlg.countdown--
      if (bindDlg.countdown <= 0) clearInterval(t)
    }, 1000)
  } catch (e) { ElMessage.error(e?.message || '发送失败') }
}

async function submitBind() {
  if (['totp', 'payPassword', 'apiKey', 'qq'].includes(bindDlg.channel) || !bindDlg.row?.supportVerify) {
    // 非验证类渠道：直接按 profile 信息保存
    try {
      const up = {}
      if (bindDlg.channel === 'wechat') up.wechat = bindDlg.target || null
      if (bindDlg.channel === 'qq') up.qq = bindDlg.target || null
      if (Object.keys(up).length) { await updateProfile(up); ElMessage.success('已保存绑定信息') }
      bindDlg.visible = false
      await loadAll()
    } catch (e) { ElMessage.error(e?.message || '保存失败') }
    return
  }
  if (!bindDlg.code) { ElMessage.warning('请输入验证码'); return }
  bindDlg.submitting = true
  try {
    await verifyBinding({ channel: bindDlg.channel, target: bindDlg.target || undefined, code: bindDlg.code })
    ElMessage.success(`${bindDlg.row.name} 已绑定并验证`)
    bindDlg.visible = false
    await loadAll()
  } catch (e) { ElMessage.error(e?.message || '验证失败') }
  finally { bindDlg.submitting = false }
}

onMounted(async () => {
  try { await userStore.fetchProfile() } catch {}
  await loadAll()
  await loadLoginRecords(1)
})
</script>

<style scoped>
.settings-page { padding: 6px 4px 40px; }
.page-head { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:16px; }
.page-head .head-main .title { margin: 0; font-size: 22px; }
.page-head .head-main .desc { margin: 6px 0 0; color:#6b7280; font-size:13px; }
.profile-card { display:flex; justify-content:space-between; align-items:center; background:#fff; border-radius:10px; padding:18px 22px; box-shadow:0 2px 12px rgba(15,23,42,.05); margin-bottom: 18px; border:1px solid #eef2f7; }
.profile-card .left { display:flex; align-items:center; gap:16px; }
.profile-card .name-line { display:flex; align-items:center; gap:8px; }
.profile-card .username { font-size:18px; font-weight:700; color:#0f172a; }
.profile-card .role-tag { margin-right: 6px; }
.profile-card .sub-line { margin-top: 6px; color:#475569; font-size:13px; }
.profile-card .sub-line .sep { margin: 0 8px; color:#cbd5e1; }
.profile-card .right-stats { display:flex; gap: 28px; }
.tabs-wrap { background:#fff; border-radius:10px; padding: 6px 22px 10px; box-shadow:0 2px 12px rgba(15,23,42,.05); border:1px solid #eef2f7; }
.card-body { padding: 10px 4px 20px; }
.form-actions { display:flex; justify-content:flex-end; gap:10px; }
.mb-16 { margin-bottom:16px; }
.mt-8 { margin-top:8px; }
.mt-16 { margin-top:16px; }
.mt-20 { margin-top:20px; }
.sec-title { margin: 0 0 12px; padding-left: 8px; border-left:3px solid #10b981; font-size: 15px; color:#0f172a; }
.hint { color:#64748b; margin-left:10px; font-size:12px; }
</style>
