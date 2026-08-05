<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="16">
        <el-card shadow="hover" class="main-card">
          <template #header>
            <div class="card-header">
              <b>实名认证 · KYC 审核</b>
              <el-tag v-if="status==='none'" type="info" effect="plain" round size="large">未认证</el-tag>
              <el-tag v-else-if="status==='pending'" type="warning" effect="light" round size="large">审核中</el-tag>
              <el-tag v-else-if="status==='passed'" type="success" effect="dark" round size="large">已认证</el-tag>
              <el-tag v-else-if="status==='rejected'" type="danger" effect="dark" round size="large">认证失败</el-tag>
              <span v-if="lastRecord" class="muted small">DB 记录 #{{ lastRecord.id }} · 提交于 {{ lastRecord.submittedAt }}</span>
            </div>
          </template>

          <div v-if="status==='passed'" class="passed">
            <el-icon :size="52" color="#10b981"><CircleCheckFilled /></el-icon>
            <div class="p-title">🎉 恭喜，实名认证已通过！</div>
            <div class="p-sub muted">
              实名信息：<b>{{ (lastRecord?.type==='company'?'企业':'个人') }}</b>
              · <b>{{ lastRecord?.type==='company' ? lastRecord.company : lastRecord.nameMasked }}</b>
              <template v-if="lastRecord?.type==='person'">
                · 身份证 <b>{{ lastRecord.idcardMasked }}</b>
                · 手机 <b>{{ lastRecord.phoneMasked }}</b>
              </template>
              <template v-else>
                · 统一社会信用代码 <b>{{ lastRecord.usccMasked }}</b>
                · 法人 <b>{{ lastRecord.legalNameMasked }}</b>
              </template>
            </div>
            <div class="p-sub muted" style="margin-top:4px">审核通过于：{{ lastRecord?.reviewedAt || lastRecord?.updatedAt || '—' }}</div>
          </div>
          <div v-else>
            <div class="stepper">
              <el-steps :active="stepperIdx" finish-status="success" align-center>
                <el-step title="选择类型" description="个人/企业" />
                <el-step title="提交资料" description="证件 + 人脸识别" />
                <el-step title="官方审核" description="约 3 秒 ~ 1 个工作日" />
                <el-step title="权益解锁" description="双倍奖励 + 额度" />
              </el-steps>
            </div>

            <el-alert v-if="status==='rejected' && lastRecord?.rejectReason" type="error"
              :closable="false" show-icon class="mt-8 mb-12"
              :title="'审核被驳回：' + lastRecord.rejectReason"
              description="请修正资料后重新提交" />

            <el-tabs v-model="type" size="large" class="type-tabs">
              <el-tab-pane label="🪪 个人实名认证" name="person">
                <el-form :model="form" label-width="120px" class="k-form">
                  <el-row :gutter="16">
                    <el-col :span="12">
                      <el-form-item label="真实姓名">
                        <el-input v-model="form.name" placeholder="请输入身份证上的真实姓名" size="large" :disabled="readonly" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="身份证号">
                        <el-input v-model="form.idcard" placeholder="18 位身份证号，支持 X" size="large" :disabled="readonly" maxlength="18" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="手机号">
                        <el-input v-model="form.phone" size="large" :disabled="readonly" maxlength="11">
                          <template #append>
                            <el-button :disabled="sending||readonly" @click="sendSms">{{ sending ? `${cd}s 后重发` : '获取验证码' }}</el-button>
                          </template>
                        </el-input>
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="短信验证码">
                        <el-input v-model="form.sms" size="large" maxlength="6" placeholder="默认 123456" :disabled="readonly" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="24">
                      <el-form-item label="证件照片">
                        <div class="upload-group">
                          <el-upload drag :auto-upload="false" class="up-box" :disabled="readonly"
                            :on-change="(_)=>form.id_front_url='mock://id-front-uploaded'">
                            <el-icon :size="26" color="#909399" v-if="!form.id_front_url"><Plus /></el-icon>
                            <div v-else style="color:#10b981;font-weight:600">已上传 ✔</div>
                            <div class="up-hint muted small">人像面（身份证正面）</div>
                          </el-upload>
                          <el-upload drag :auto-upload="false" class="up-box" :disabled="readonly"
                            :on-change="(_)=>form.id_back_url='mock://id-back-uploaded'">
                            <el-icon :size="26" color="#909399" v-if="!form.id_back_url"><Plus /></el-icon>
                            <div v-else style="color:#10b981;font-weight:600">已上传 ✔</div>
                            <div class="up-hint muted small">国徽面（身份证背面）</div>
                          </el-upload>
                          <el-upload drag :auto-upload="false" class="up-box face" :disabled="readonly"
                            :on-change="(_)=>form.face_url='mock://face-uploaded'">
                            <el-icon :size="26" color="#909399" v-if="!form.face_url"><Camera /></el-icon>
                            <div v-else style="color:#10b981;font-weight:600">已认证 ✔</div>
                            <div class="up-hint muted small">人脸活体检测</div>
                          </el-upload>
                        </div>
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>

              <el-tab-pane label="🏢 企业实名认证" name="company">
                <el-form :model="cform" label-width="120px" class="k-form">
                  <el-row :gutter="16">
                    <el-col :span="12">
                      <el-form-item label="企业名称"><el-input v-model="cform.company" size="large" :disabled="readonly" /></el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="统一社会信用代码"><el-input v-model="cform.uscc" size="large" :disabled="readonly" maxlength="18" /></el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="法人姓名"><el-input v-model="cform.legal" size="large" :disabled="readonly" /></el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="法人身份证"><el-input v-model="cform.legalId" size="large" :disabled="readonly" maxlength="18" /></el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="对公账户"><el-input v-model="cform.bank" size="large" placeholder="开户行 + 账号" :disabled="readonly" /></el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="联系人邮箱"><el-input v-model="cform.email" size="large" :disabled="readonly" /></el-form-item>
                    </el-col>
                    <el-col :span="24">
                      <el-form-item label="营业执照">
                        <el-upload drag :auto-upload="false" class="up-box wide" :disabled="readonly"
                          :on-change="(_)=>cform.license_url='mock://license-uploaded'">
                          <el-icon :size="26" color="#909399" v-if="!cform.license_url"><PictureFilled /></el-icon>
                          <div v-else style="color:#10b981;font-weight:600">已上传 ✔</div>
                          <div class="up-hint muted small">营业执照彩色扫描件（PDF/JPG/PNG）</div>
                        </el-upload>
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>
            </el-tabs>

            <div class="form-actions">
              <el-checkbox v-model="agree" :disabled="readonly">
                我已阅读并同意 <a class="link" href="javascript:;">《实名认证用户协议》</a> 及
                <a class="link" href="javascript:;">《隐私政策》</a>
              </el-checkbox>
              <div>
                <el-button v-if="status==='pending'" type="info" plain size="large" :loading="demoPassing" @click="doDemoPass">
                  演示：模拟审核通过（3秒自动走）
                </el-button>
                <el-button type="primary" size="large" :icon="CircleCheckFilled" :loading="submitting" :disabled="readonly" @click="submit">
                  {{ readonly ? '资料已提交，等待官方审核…' : '立即提交认证（约 3 秒起）' }}
                </el-button>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>

      <el-col :span="8">
        <el-card shadow="hover" class="benefits-card">
          <template #header><b>🎁 认证通过立享权益</b></template>
          <div class="b-list">
            <div v-for="(b, i) in benefits" :key="i" class="b-item">
              <div class="b-ic" :style="{ background: b.bg }"><el-icon :size="20" color="#fff"><component :is="b.icon" /></el-icon></div>
              <div class="b-info">
                <div class="b-title"><b>{{ b.title }}</b></div>
                <div class="b-desc muted small">{{ b.desc }}</div>
              </div>
            </div>
          </div>
          <el-divider />
          <el-alert
            title="隐私保护承诺" type="success" :closable="false" show-icon
            description="所有证件资料采用 AES-256 加密存储，仅用于实名认证核验，严格遵守《个人信息保护法》，绝不外泄。"
          />
        </el-card>

        <el-card shadow="hover" style="margin-top: 16px; border-radius: 14px;" v-if="status==='pending'">
          <template #header><b>⏳ 当前审核进度</b></template>
          <el-steps :active="2" direction="vertical" finish-status="success">
            <el-step title="资料已提交并保存到数据库" :description="'ID #' + (lastRecord?.id||'?') + ' · ' + (lastRecord?.submittedAt||'')" />
            <el-step title="证件 OCR 识别 + 格式校验" description="姓名/身份证号/统一信用代码校验通过" />
            <el-step title="人工/系统复核" description="演示环境点「模拟审核通过」立即通过，生产环境预计 1 个工作日内完成" />
          </el-steps>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { ElMessage } from 'element-plus'
import {
  CircleCheckFilled, Plus, Camera, PictureFilled,
  Wallet, Cpu, Coin, Tickets, UserFilled, Phone
} from '@element-plus/icons-vue'
import {
  getMyKycStatus, submitPersonKyc, submitCompanyKyc, demoAutoPass
} from '@/api/verify'

const status = ref('none')  // none | pending | passed | rejected
const lastRecord = ref(null)
const type = ref('person')
const agree = ref(false)
const submitting = ref(false)
const demoPassing = ref(false)
const sending = ref(false)
const cd = ref(0)
let _t = null
let _pollTimer = null

const form = reactive({
  name: '', idcard: '', phone: '', sms: '',
  id_front_url: '', id_back_url: '', face_url: ''
})
const cform = reactive({
  company: '', uscc: '', legal: '', legalId: '', bank: '', email: '',
  license_url: ''
})

const readonly = computed(() => status.value === 'pending')
const stepperIdx = computed(() => {
  if (status.value === 'passed') return 4
  if (status.value === 'pending') return 2
  if (submitting.value) return 1
  return 0
})

const benefits = [
  { title: '双倍活动奖励', desc: '所有充值加赠 ×2，如 22% → 44%，单月上限 2000 元', icon: 'Coin', bg: 'linear-gradient(135deg,#f59e0b,#d97706)' },
  { title: '购买额度提升', desc: '由 5 台 → 100 台，企业用户 1000 台，解除风控限额', icon: 'Cpu', bg: 'linear-gradient(135deg,#10b981,#059669)' },
  { title: '余额提现权限', desc: '支持原路退回 / 银行卡 / 支付宝提现，T+1 到账', icon: 'Wallet', bg: 'linear-gradient(135deg,#3b82f6,#2563eb)' },
  { title: '免费 DDoS 基础防护', desc: '每台服务器 20Gbps DDoS 防护 + 5Gbps CC 防护', icon: 'Tickets', bg: 'linear-gradient(135deg,#8b5cf6,#7c3aed)' },
  { title: '7x24 专属客服', desc: '金牌客服响应，工单 ≤ 5 分钟，电话直连', icon: 'Phone', bg: 'linear-gradient(135deg,#0ea5e9,#0284c7)' },
  { title: '增值税专票', desc: '企业用户开具 6% 增值税专票，合同 / 审计支持', icon: 'UserFilled', bg: 'linear-gradient(135deg,#ef4444,#dc2626)' },
]

function sendSms() {
  if (!/^1[3-9]\d{9}$/.test(form.phone)) { ElMessage.warning('请输入正确的手机号'); return }
  sending.value = true
  cd.value = 60
  _t = setInterval(() => {
    cd.value--
    if (cd.value <= 0) { sending.value = false; clearInterval(_t) }
  }, 1000)
  ElMessage.success('验证码已发送，测试代码：123456')
}

async function submit() {
  if (!agree.value) { ElMessage.warning('请先阅读并同意相关协议'); return }
  submitting.value = true
  try {
    let res
    if (type.value === 'person') {
      res = await submitPersonKyc({
        name: form.name, idcard: form.idcard, phone: form.phone, sms: form.sms,
        id_front_url: form.id_front_url, id_back_url: form.id_back_url, face_url: form.face_url,
        agree: true
      })
    } else {
      res = await submitCompanyKyc({
        company: cform.company, uscc: cform.uscc, legal_name: cform.legal, legal_idcard: cform.legalId,
        bank_account: cform.bank, contact_email: cform.email, license_url: cform.license_url,
        agree: true
      })
    }
    if (res?.code === 0) {
      ElMessage.success(res.message || '资料已提交，进入审核队列')
      status.value = 'pending'
      lastRecord.value = {
        ...(lastRecord.value||{}), id: res.data?.id, submittedAt: new Date().toLocaleString('sv-SE').replace('T',' ')
      }
      // 启动轮询，看看是否有自动审核
      startPolling()
    } else {
      ElMessage.error(res?.message || '提交失败')
    }
  } catch (e) {
    ElMessage.error('提交异常：' + (e?.message || e))
  } finally {
    submitting.value = false
  }
}

async function doDemoPass() {
  demoPassing.value = true
  try {
    const r = await demoAutoPass()
    if (r?.code === 0) {
      ElMessage.success(r.message || '已模拟审核通过，3秒后刷新…')
      setTimeout(() => loadStatus(), 1200)
    } else {
      ElMessage.error(r?.message || '操作失败')
    }
  } catch (e) { ElMessage.error('异常：'+(e?.message||e)) }
  finally { demoPassing.value = false }
}

async function loadStatus() {
  try {
    const r = await getMyKycStatus()
    if (r?.code === 0) {
      status.value = r.data?.status || 'none'
      lastRecord.value = r.data?.record || null
      // 回填表单（脱敏显示）
      const rec = r.data?.record
      if (rec) {
        if (rec.type === 'person') {
          type.value = 'person'
          form.name = rec.name || ''
          if (!form.idcard) form.idcard = rec.idcardMasked ? '' : ''  // 不回填完整身份证号
          if (!form.phone)  form.phone  = rec.phoneMasked ? '' : ''
          if (rec.idFrontUrl) form.id_front_url = rec.idFrontUrl
          if (rec.idBackUrl)  form.id_back_url  = rec.idBackUrl
          if (rec.faceUrl)    form.face_url     = rec.faceUrl
        } else {
          type.value = 'company'
          if (!cform.company) cform.company = rec.company || ''
          cform.legal = rec.legalName || ''
        }
      }
    }
  } catch (e) { console.warn('loadStatus fail:', e) }
}

function startPolling() {
  if (_pollTimer) return
  _pollTimer = setInterval(async () => {
    if (status.value !== 'pending') { clearInterval(_pollTimer); _pollTimer = null; return }
    const before = status.value
    await loadStatus()
    if (status.value !== before) {
      clearInterval(_pollTimer); _pollTimer = null
      if (status.value === 'passed') ElMessage.success('🎉 系统自动审核通过！所有权益已解锁')
      else if (status.value === 'rejected') ElMessage.warning('审核被驳回，请查看原因后重新提交')
    }
  }, 2000)
}

onMounted(() => {
  loadStatus()
})
onBeforeUnmount(() => {
  if (_t) clearInterval(_t)
  if (_pollTimer) { clearInterval(_pollTimer); _pollTimer = null }
})
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.main-card, .benefits-card { border-radius: 14px; }
.card-header { display: flex; justify-content: space-between; align-items: center; gap: 10px; flex-wrap: wrap; }
.stepper { margin: 14px 0 22px; padding: 0 10px; }
.passed {
  text-align: center; padding: 18px 20px;
  background: linear-gradient(135deg,#ecfdf5,#dbeafe); border-radius: 12px;
  margin-bottom: 16px;
}
.p-title { font-size: 22px; font-weight: 800; color: #065f46; margin-top: 8px; }
.p-sub { margin-top: 4px; line-height: 1.7; }
.type-tabs { margin-top: 10px; }
.k-form { padding: 8px 4px 0; }
.upload-group { display: flex; gap: 12px; flex-wrap: wrap; }
.up-box {
  width: 230px; border: 2px dashed #d1d5db; border-radius: 12px;
  background: #fafbfc;
}
.up-box :deep(.el-upload-dragger) { padding: 22px 10px; background: transparent; border: none; }
.up-box.face { background: linear-gradient(135deg,#f0f9ff,#eff6ff); border-color: #93c5fd; }
.up-box.wide { width: 100%; }
.up-hint { margin-top: 6px; }
.mt-8 { margin-top: 8px; } .mb-12 { margin-bottom: 12px; }

.form-actions { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; padding-top: 18px; border-top: 1px dashed #e5e7eb; margin-top: 6px; }
.form-actions .link { color: #409eff; }
.b-list { display: flex; flex-direction: column; gap: 14px; }
.b-item { display: flex; gap: 12px; align-items: center; }
.b-ic { width: 42px; height: 42px; border-radius: 11px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 4px 10px rgba(0,0,0,0.08); }
.b-info { flex: 1; }
.b-title { color: #111827; font-size: 14px; }
.b-desc { margin-top: 2px; line-height: 1.6; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
