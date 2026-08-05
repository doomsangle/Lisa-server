<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="16">
        <el-card shadow="hover" class="recharge-card">
          <template #header>
            <div class="card-header">
              <b>充值金额</b>
              <el-tag type="danger" effect="dark" round size="large" class="event-tag">
                <el-icon><BellFilled /></el-icon>
                限时活动：充值任意金额享 <b>加赠 22%</b>
              </el-tag>
            </div>
          </template>

          <div class="balance-row">
            <div>
              <div class="lbl muted small">当前账户余额</div>
              <div class="bal">¥ {{ userStore.userInfo?.balance || '45320.88' }}</div>
            </div>
            <el-button type="success" size="small" plain round @click="showOrders">查看充值记录 →</el-button>
          </div>

          <div class="amounts">
            <div
              v-for="(a, i) in amounts" :key="i" class="amount-card"
              :class="{ active: sel === i, hot: a.hot }"
              @click="sel = i"
            >
              <div class="am-val">¥ {{ a.val }}</div>
              <div v-if="a.bonus" class="am-bonus">加赠 +¥ {{ a.bonus }}</div>
              <div v-else class="am-bonus empty">无加赠</div>
              <div class="am-tag" v-if="a.hot">🔥 推荐</div>
              <div class="am-tag first" v-else-if="a.first">🎉 首充礼</div>
            </div>
            <div class="amount-card custom" :class="{ active: sel===-1 }" @click="sel=-1; focusCustom()">
              <div class="cu-label muted small">自定义金额</div>
              <div class="cu-input">
                <span class="cny">¥</span>
                <el-input-number
                  v-model="custom" :min="50" :max="1000000" :step="100" :controls="false"
                  size="large" class="cu-num" placeholder="请输入" @change="sel=-1"
                />
              </div>
              <div class="am-bonus">加赠 +¥ {{ (custom * 0.22).toFixed(2) }}</div>
            </div>
          </div>

          <el-divider content-position="left"><b>支付方式</b></el-divider>
          <div class="pays">
            <div v-for="(p, i) in pays" :key="i" class="pay-card" :class="{ active: paySel===i }" @click="paySel=i">
              <div class="pay-ic" :class="p.key">
                <el-icon :size="22" color="#fff"><component :is="p.icon" /></el-icon>
              </div>
              <div class="pay-info">
                <div class="pay-name">{{ p.name }}</div>
                <div class="pay-desc muted small">{{ p.desc }}</div>
              </div>
              <el-radio :model-value="paySel" :label="i" />
            </div>
          </div>

          <div class="coupon-row">
            <el-select v-model="coupon" size="large" placeholder="请选择或输入优惠券码" clearable style="width: 100%;">
              <el-option value="C_NEW50" label="🎁 新人优惠券：满 500 减 50" />
              <el-option value="C_FANS88" label="🎊 粉丝特惠券：满 1000 减 88" />
              <el-option value="C_VIP188" label="💎 VIP专享券：满 5000 减 188" />
            </el-select>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="order-card">
          <template #header><b>订单摘要</b></template>
          <div class="summary-row">
            <span class="k">充值本金</span>
            <span class="v">¥ {{ totalAmount.toFixed(2) }}</span>
          </div>
          <div class="summary-row">
            <span class="k">活动加赠 (22%)</span>
            <span class="v bonus">+ ¥ {{ bonusAmount.toFixed(2) }}</span>
          </div>
          <div class="summary-row">
            <span class="k">优惠券抵扣</span>
            <span class="v coupon">- ¥ {{ couponAmount.toFixed(2) }}</span>
          </div>
          <div class="summary-row">
            <span class="k">支付方式</span>
            <span class="v">{{ pays[paySel]?.name }}</span>
          </div>
          <el-divider />
          <div class="summary-row total">
            <span class="k">应付金额</span>
            <span class="v">¥ {{ payAmount.toFixed(2) }}</span>
          </div>
          <div class="summary-row arrive">
            <span class="k muted small">充值后实际到账余额</span>
            <span class="v arrive-val">
              <b>¥ {{ (parseFloat(userStore.userInfo?.balance || 0) + totalAmount + bonusAmount).toFixed(2) }}</b>
            </span>
          </div>

          <el-button type="success" size="large" class="pay-btn" @click="confirmPay">
            <el-icon :size="18"><CreditCard /></el-icon>
            立即充值 ¥ {{ payAmount.toFixed(2) }}
          </el-button>

          <div class="terms muted small">
            <el-checkbox v-model="agree">我已阅读并同意</el-checkbox>
            <a class="link" href="javascript:;">《充值服务条款》</a>
            与
            <a class="link" href="javascript:;">《账户余额使用说明》</a>
          </div>

          <el-divider />
          <div class="tips muted small">
            <div>💡 充值说明：</div>
            <div>1. 充值成功后余额实时到账，可用于消费全部产品和服务；</div>
            <div>2. 加赠金额有效期 1 年，本金永久有效；</div>
            <div>3. 余额如需提现请联系客服，仅支持原路退回。</div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
<script setup>
import { ref, reactive, computed, nextTick, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/stores/user'
import {
  BellFilled, CreditCard, ChatLineSquare, CircleCheckFilled, Coin, Wallet
} from '@element-plus/icons-vue'
import { createRecharge, getRechargeOptions } from '@/api/wallet_real'
import { redeemCoupon } from '@/api/coupons'

const router = useRouter()
const userStore = useUserStore()
const sel = ref(3)
const custom = ref(1000)
const paySel = ref(0)
const coupon = ref('')
const agree = ref(true)
const amounts = ref([
  { val: 100, bonus: 22, hot: false, first: false },
  { val: 500, bonus: 110, hot: false, first: true },
  { val: 1000, bonus: 220, hot: false, first: false },
  { val: 3000, bonus: 660, hot: true, first: false },
  { val: 5000, bonus: 1100, hot: false, first: false },
  { val: 10000, bonus: 2200, hot: false, first: false },
])
const pays = ref([
  { key: 'wechat', name: '微信支付', desc: '扫码支付 · 即时到账', icon: 'ChatLineSquare' },
  { key: 'alipay', name: '支付宝', desc: '企业/个人账户 · 推荐大额', icon: 'CircleCheckFilled' },
  { key: 'paypal', name: 'PayPal', desc: '国际信用卡 · 支持港币/美元', icon: 'CreditCard' },
  { key: 'usdt', name: 'USDT TRC20', desc: '数字货币 · 无汇率损失', icon: 'Coin' },
  { key: 'bank', name: '对公转账', desc: '企业用户 · 开具增值税专票', icon: 'Wallet' },
])
const loading = ref(false)

onMounted(async () => {
  try {
    const r = await getRechargeOptions()
    if (r?.code === 0 && r.data?.amounts?.length) {
      const bonusRate = Number(r.data.bonusRate || 0) || 0.22
      amounts.value = r.data.amounts.map((v, i) => ({
        val: v,
        bonus: Math.round(v * bonusRate),
        hot: i === 3 || (r.data.hotAmount === v),
        first: i === 1,
      }))
    }
    if (r?.code === 0 && r.data?.channels?.length) {
      const keyMap = { wechat: 0, alipay: 1, paypal: 2, usdt: 3, bank: 4 }
      pays.value = r.data.channels.filter(c => keyMap[c.key] != null).map(c => {
        const base = pays.value[keyMap[c.key]]
        return base ? { ...base, ...c } : c
      })
    }
  } catch (_) {}
})

const selectedAmount = computed(() => sel.value >= 0 ? amounts.value[sel.value]?.val : (custom.value || 0))
const totalAmount = computed(() => Math.max(0, parseFloat(selectedAmount.value) || 0))
const bonusAmount = computed(() => totalAmount.value * 0.22)
const couponAmount = computed(() => {
  if (coupon.value === 'C_NEW50' && totalAmount.value >= 500) return 50
  if (coupon.value === 'C_FANS88' && totalAmount.value >= 1000) return 88
  if (coupon.value === 'C_VIP188' && totalAmount.value >= 5000) return 188
  return 0
})
const payAmount = computed(() => Math.max(0, totalAmount.value - couponAmount.value))

function focusCustom() {
  nextTick(() => {
    const el = document.querySelector('.cu-num input')
    if (el) el.focus()
  })
}
async function applyCoupon() {
  if (!coupon.value) return ElMessage.warning('请输入优惠券码')
  try {
    const r = await redeemCoupon(coupon.value.trim())
    if (r?.code === 0) ElMessage.success(`优惠券领取成功：${r.data?.coupon?.name || coupon.value}`)
    else ElMessage.warning(r?.message || '优惠券无效')
  } catch (e) {
    ElMessage.warning(e.message || '优惠券无效')
  }
}
async function confirmPay() {
  if (payAmount.value <= 0) { ElMessage.warning('请输入有效的充值金额'); return }
  if (!agree.value) { ElMessage.warning('请先阅读并同意相关条款'); return }
  const ch = pays.value[paySel.value]?.key
  if (!ch) { ElMessage.warning('请选择支付方式'); return }
  loading.value = true
  try {
    const r = await createRecharge({
      amount: Number(totalAmount.value),
      pay_channel: ch,
      coupon_code: coupon.value?.trim() || undefined,
    })
    if (r?.code !== 0) throw new Error(r?.message || '下单失败')
    const data = r.data
    if (data.status === 'paid') {
      ElMessage.success(`充值成功：金额 ¥${(data.amountNum || totalAmount.value).toFixed(2)} 已到账，单号 ${data.orderNo}`)
    } else {
      const tipMap = {
        wechat: '请用微信扫一扫付款二维码', alipay: '请在支付宝中完成支付',
        usdt: '请向系统分配的TRC20地址转账 USDT',
        paypal: '请在 PayPal 页面完成支付', bank: '请在网银中完成对公转账，转账后自动或人工到账',
      }
      await ElMessageBox.alert(
        `订单号：${data.orderNo}\n需支付金额：¥${(data.amountNum || totalAmount.value).toFixed(2)}\n\n${tipMap[ch] || '请在第三方页面完成支付'}\n支付成功后系统将自动到账（约3-15分钟）。`,
        `待支付 · ${pays.value[paySel.value].name}`,
        { confirmButtonText: '我已完成支付', type: 'info' }
      )
      ElMessage.success(`已提交充值订单 ${data.orderNo}，我们将尽快核验并为您到账`)
    }
    try { await userStore.fetchProfile() } catch (_) {}
  } catch (e) {
    ElMessage.error(e.message || '充值下单失败，请稍后重试')
  } finally {
    loading.value = false
  }
}
function showOrders() { router.push('/recharges') }
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.recharge-card, .order-card { border-radius: 14px; }
.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.event-tag { font-weight: 600; }

.balance-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: 16px 18px; background: linear-gradient(135deg,#fffbeb,#ecfeff);
  border-radius: 12px; margin-bottom: 20px; border: 1px dashed #fcd34d;
}
.bal { font-size: 26px; font-weight: 800; color: #92400e; margin-top: 4px; }

.amounts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-bottom: 6px; }
.amount-card {
  position: relative;
  padding: 22px 14px 18px;
  border: 2px solid #e5e7eb;
  border-radius: 14px;
  background: #fff;
  cursor: pointer;
  transition: all .2s ease;
  text-align: center;
}
.amount-card:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(0,0,0,0.08); }
.amount-card.active {
  border-color: #10b981;
  background: linear-gradient(135deg,#ecfdf5,#d1fae5);
  box-shadow: 0 8px 22px rgba(16,185,129,0.2);
}
.amount-card.hot { border-color: #ff7a45; }
.am-val { font-size: 24px; font-weight: 800; color: #111827; }
.am-bonus { margin-top: 4px; color: #059669; font-weight: 600; font-size: 13px; }
.am-bonus.empty { color: #9ca3af; font-weight: 500; }
.am-tag {
  position: absolute; top: -8px; right: 8px;
  background: linear-gradient(135deg,#ff7a45,#f56c6c); color: #fff;
  font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 700;
}
.am-tag.first { background: linear-gradient(135deg,#8b5cf6,#d946ef); }

.amount-card.custom { text-align: left; padding: 16px; }
.cu-label { margin-bottom: 6px; }
.cu-input { display: flex; align-items: center; gap: 6px; }
.cny { font-size: 20px; font-weight: 700; color: #10b981; }
.cu-num { width: calc(100% - 30px); }

.pays { display: flex; flex-direction: column; gap: 10px; }
.pay-card {
  display: flex; align-items: center; gap: 14px;
  padding: 14px 16px;
  border: 2px solid #eef0f3;
  border-radius: 12px;
  cursor: pointer;
  transition: all .2s ease;
}
.pay-card:hover { background: #f9fafb; }
.pay-card.active { border-color: #409eff; background: #eff6ff; }
.pay-ic {
  width: 42px; height: 42px; border-radius: 11px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.pay-ic.wechat { background: linear-gradient(135deg,#07c160,#10b981); }
.pay-ic.alipay { background: linear-gradient(135deg,#2080f0,#3b82f6); }
.pay-ic.paypal { background: linear-gradient(135deg,#722ed1,#8b5cf6); }
.pay-ic.usdt { background: linear-gradient(135deg,#22c55e,#10b981); }
.pay-ic.bank { background: linear-gradient(135deg,#64748b,#475569); }
.pay-info { flex: 1; }
.pay-name { font-weight: 600; color: #111827; }
.pay-desc { margin-top: 2px; }

.coupon-row { margin-top: 20px; }
.summary-row { display: flex; justify-content: space-between; padding: 8px 0; font-size: 14px; }
.summary-row .k { color: #6b7280; }
.summary-row .v { color: #111827; font-weight: 600; }
.summary-row .v.bonus { color: #059669; }
.summary-row .v.coupon { color: #ef4444; }
.summary-row.total { font-size: 16px; }
.summary-row.total .v { color: #f56c6c; font-size: 26px; font-weight: 800; }
.summary-row.arrive { padding: 6px 0 14px; }
.arrive-val { color: #10b981; font-size: 18px; }
.pay-btn { width: 100%; height: 50px; font-size: 16px; font-weight: 700; border-radius: 12px; }
.terms { margin-top: 14px; text-align: center; }
.terms .link { color: #409eff; }
.tips { line-height: 1.9; background: #fafbfc; padding: 12px 14px; border-radius: 8px; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
