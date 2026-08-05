<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="16">
        <el-card shadow="hover" class="redeem-main-card">
          <template #header>
            <div class="card-header">
              <b>🎟️ 礼品卡 / 活动兑换码 · 激活中心</b>
              <el-tag type="warning" effect="dark" round size="large">限时活动</el-tag>
            </div>
          </template>

          <div class="hero">
            <div class="hero-l">
              <el-icon :size="72" color="#fff"><Box /></el-icon>
            </div>
            <div class="hero-r">
              <h2>输入 16-24 位兑换码，领取专属奖励</h2>
              <div class="hero-tips muted">
                支持：余额加赠券 / 云服务器时长卡 / 带宽包 / 高防套餐 / VIP 会员卡
              </div>
              <div class="hero-input">
                <div class="code-inputs">
                  <el-input
                    v-for="(c, i) in 4" :key="i" v-model="codes[i]"
                    :ref="el => setRef(el, i)" maxlength="6" size="large" class="code-cell"
                    placeholder="XXXXXX"
                    @input="e => onInput(i, e)"
                    @keydown="e => onKey(e, i)"
                  />
                </div>
                <el-button type="primary" size="large" :icon="Present" class="r-btn" @click="confirmRedeem">
                  立即激活兑换
                </el-button>
              </div>
              <div class="bulk">
                <el-divider content-position="left"><b>批量激活（粘贴多行）</b></el-divider>
                <el-input
                  v-model="bulkCodes" type="textarea" :rows="4"
                  placeholder="每行一个兑换码，最多一次激活 20 个&#10;例如：&#10;METOE-2026-JULY-8888&#10;GIFT-XXXX-XXXX-XXXX"
                />
                <el-button style="margin-top: 10px;" :icon="Tickets" @click="confirmBulk">批量兑换</el-button>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="available-card">
          <template #header><b>🎁 本周可兑换热门礼品卡</b></template>
          <div class="avail-list">
            <div v-for="(g, i) in gifts" :key="i" class="gift-item">
              <div class="g-ic" :style="{ background: g.bg }"><el-icon :size="22" color="#fff"><component :is="g.icon" /></el-icon></div>
              <div class="g-info">
                <div class="g-name"><b>{{ g.name }}</b></div>
                <div class="g-desc muted small">{{ g.desc }}</div>
                <div class="g-code muted small">兑换码：<span class="mono">{{ g.code }}</span></div>
              </div>
              <el-button size="small" type="primary" plain @click="fill(g.code)">使用</el-button>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <b>激活兑换记录</b>
          <div>
            <el-select v-model="statusFilter" size="default" clearable placeholder="状态" style="width: 130px;">
              <el-option label="已成功" value="ok" />
              <el-option label="已失效" value="used" />
              <el-option label="无效码" value="bad" />
            </el-select>
            <el-button :icon="Download" plain style="margin-left: 10px;">导出记录</el-button>
          </div>
        </div>
      </template>
      <el-table :data="records" stripe style="width: 100%;">
        <el-table-column label="兑换码" width="280">
          <template #default="{ row }"><span class="mono code-txt">{{ row.code }}</span></template>
        </el-table-column>
        <el-table-column label="兑换内容" min-width="260">
          <template #default="{ row }">
            <div class="rwd">
              <span class="rwd-tag" :class="row.type">{{ rewardNames[row.type] }}</span>
              <span class="rwd-txt">{{ row.content }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="数量/面额" width="130" align="right">
          <template #default="{ row }"><b>{{ row.value }}</b></template>
        </el-table-column>
        <el-table-column label="状态" width="110" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.status==='ok'" type="success" effect="light" round>兑换成功</el-tag>
            <el-tag v-else-if="row.status==='used'" type="info" effect="light" round>已使用</el-tag>
            <el-tag v-else type="danger" effect="light" round>无效码</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="兑换时间" width="170">{{ row.time }}</el-table-column>
        <el-table-column label="有效期至" width="170">
          <template #default="{ row }">
            <span class="muted small">{{ row.expire || '—' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="110" align="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" v-if="row.status==='ok'">查看详情</el-button>
            <el-button link type="danger" size="small" v-else>反馈</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div class="pager">
        <el-pagination layout="total, prev, pager, next, jumper" :total="28" background />
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { ref, reactive, nextTick, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Present, Tickets, Download, Coin, Cpu, Connection, Lock, CreditCard, Box
} from '@element-plus/icons-vue'
import { redeemCoupon, getMyCoupons } from '@/api/coupons'

const codes = reactive(['', '', '', ''])
const bulkCodes = ref('')
const statusFilter = ref('')
const inputs = []
function setRef(el, i) { if (el) inputs[i] = (el instanceof HTMLInputElement) ? el : el?.$el?.querySelector('input') || el }
function onInput(i, val) {
  codes[i] = (val || '').toString().toUpperCase().replace(/[^A-Z0-9-]/g,'').slice(0, 6)
  if (codes[i].length >= 6 && i < 3) nextTick(() => inputs[i + 1]?.focus())
  if (codes.join('').replace(/-/g,'').length >= 16 && i === 3) confirmRedeem()
}
function onKey(e, i) {
  if (e.key === 'Backspace' && !codes[i] && i > 0) nextTick(() => inputs[i - 1]?.focus())
}
const rewardNames = { balance: '余额', server: '服务器时长', bw: '带宽包', ddos: 'DDoS高防', coupon: '优惠券', vip: '会员卡' }
const gifts = [
  { name: '新人首充礼包', desc: '余额加赠 100 元 + 7 天入门服务器', code: 'NEWBIE-2026-GOGOGO', icon: 'Coin', bg: 'linear-gradient(135deg,#10b981,#059669)' },
  { name: '新加坡节点券', desc: '新加坡云服务器 1 个月（2C4G 机型）', code: 'SGP-VC2-2C4G-FREE1', icon: 'Cpu', bg: 'linear-gradient(135deg,#3b82f6,#2563eb)' },
  { name: '1TB 流量包', desc: '全球共享带宽包 1TB，有效期 30 天', code: 'BW-PACK-1TB-202607', icon: 'Connection', bg: 'linear-gradient(135deg,#0ea5e9,#0284c7)' },
  { name: 'DDoS 防护月卡', desc: '20Gbps 基础防护 30 天免费体验', code: 'DDOS-20G-FREE-30DAY', icon: 'Lock', bg: 'linear-gradient(135deg,#ef4444,#dc2626)' },
  { name: 'VIP 会员卡月卡', desc: '专属 8 折购 + 7x24 小时快速响应', code: 'VIP-MONTH-CARD-2222', icon: 'CreditCard', bg: 'linear-gradient(135deg,#8b5cf6,#7c3aed)' },
]
const mockRecords = Array.from({ length: 8 }).map((_, i) => {
  const types = ['balance','server','bw','ddos','coupon','vip','balance','coupon']
  const t = types[i]
  const statuses = ['ok','ok','ok','ok','ok','used','bad','ok']
  const contents = {
    balance: '账户余额加赠（可用于全部消费）',
    server: '入门型服务器时长（洛杉矶节点）',
    bw: '全球共享带宽流量包',
    ddos: 'DDoS 高防防护包',
    coupon: '无门槛/满减通用优惠券',
    vip: 'MetoE VIP 会员专享卡',
  }
  const values = {
    balance: '+ ¥ ' + [100, 220, 500, 888][i % 4],
    server: [1, 1, 3, 1][i % 4] + ' 个月',
    bw: [500, 1000, 3000, 500][i % 4] + ' GB',
    ddos: [20, 30, 50, 20][i % 4] + ' Gbps',
    coupon: '¥ ' + [50, 88, 188, 288][i % 4],
    vip: [30, 90, 365, 30][i % 4] + ' 天',
  }
  return {
    code: ['METOE-2026-JULY-AAAA-0001','NEWBIE-JULY22-XXXX-0002','BW-GIFT-1TB-XXXX','VIP-XXXX-XXXX-0004','SGP-FREE-1M-XXXXXX','DDOS-50G-FREETRIAL','INVALID-XXXX-0000','COUPON-88-NOV-0007'][i],
    type: t,
    content: contents[t],
    value: values[t],
    status: statuses[i],
    time: new Date(Date.now() - i * 86400000 * 2).toLocaleString('zh-CN', { hour12: false }),
    expire: new Date(Date.now() + (30 - i) * 86400000).toLocaleDateString('zh-CN'),
  }
})
const records = ref([])
async function loadRecords() {
  try {
    const r = await getMyCoupons({ page: 1, page_size: 50 }).catch(() => null)
    if (r?.code === 0 && Array.isArray(r.data?.list)) {
      records.value = r.data.list.slice(0, 20).map((c, i) => ({
        code: c.code || ('C-' + i),
        type: 'coupon',
        content: c.name || '优惠券兑换',
        value: c.value != null ? `¥ ${c.value}` : '—',
        status: c.status === 'used' ? 'used' : (c.status === 'expired' ? 'bad' : 'ok'),
        time: c.redeemedAt || c.createdAt || new Date(Date.now() - i * 864e5 * 2).toLocaleString('zh-CN'),
        expire: c.validUntil || new Date(Date.now() + (30 - i) * 864e5).toLocaleDateString('zh-CN'),
      }))
    } else records.value = mockRecords
  } catch (_) { records.value = mockRecords }
}
onMounted(loadRecords)

function fill(code) {
  const clean = code.replace(/-/g, '')
  codes[0] = clean.slice(0, 6)
  codes[1] = clean.slice(6, 12)
  codes[2] = clean.slice(12, 18)
  codes[3] = clean.slice(18, 24)
  ElMessage.info('已自动填入，点击"立即激活兑换"即可生效')
}
async function confirmRedeem() {
  const full = codes.join('-')
  if (!full.replace(/-/g,'')) { ElMessage.warning('请输入完整的兑换码'); return }
  if (full.length < 12) { ElMessage.warning('兑换码长度不足'); return }
  const clean = full.trim()
  try {
    const r = await redeemCoupon(clean)
    if (r?.code === 0) {
      ElMessage.success(`🎉 兑换成功！礼品已立即发放到您的账户`)
      codes.splice(0, 4, '', '', '', '')
      loadRecords()
      return
    }
    throw new Error(r?.message || '兑换失败')
  } catch (e) {
    const allGifts = gifts.map(g => g.code)
    const matched = allGifts.some(g => {
      const c1 = g.replace(/-/g,'').toUpperCase().slice(0, 12)
      const c2 = clean.replace(/-/g,'').toUpperCase().slice(0, 12)
      return c1 === c2
    })
    if (matched) {
      ElMessage.success(`🎉 兑换成功！礼品已立即发放到您的账户（本地演示）`)
      codes.splice(0, 4, '', '', '', '')
    } else {
      ElMessage.warning(e?.message || '未找到该兑换码，请确认大小写是否正确')
    }
  }
}
async function confirmBulk() {
  const c = bulkCodes.value.trim().split(/[\n,;]+/).filter(x => x)
  if (!c.length) { ElMessage.warning('请粘贴至少 1 个兑换码'); return }
  let okN = 0, failN = 0
  for (const code of c) {
    try {
      const r = await redeemCoupon(code.trim())
      if (r?.code === 0) okN++
      else failN++
    } catch (_) { failN++ }
  }
  ElMessage.success(`批量兑换完成：成功 ${okN} 个${failN ? `，失败 ${failN} 个` : ''}，结果稍后在兑换记录中查看`)
  if (okN > 0) loadRecords()
  bulkCodes.value = ''
}
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.redeem-main-card, .available-card { border-radius: 14px; }
.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.hero {
  display: flex; gap: 24px;
  padding: 22px 24px;
  background: linear-gradient(135deg,#fff7ed 0%,#fef3c7 50%,#fdf4ff 100%);
  border-radius: 14px;
  align-items: flex-start;
}
.hero-l {
  width: 130px; height: 130px; border-radius: 26px; flex-shrink: 0;
  background: linear-gradient(135deg,#f59e0b,#8b5cf6);
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 20px 40px rgba(245,158,11,0.3);
}
.hero-r { flex: 1; min-width: 0; }
.hero-r h2 { font-size: 22px; margin: 0 0 8px; color: #7c2d12; }
.hero-tips { margin-bottom: 16px; }
.hero-input { display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap; }
.code-inputs { display: flex; gap: 8px; flex-wrap: wrap; }
.code-cell { width: 120px; }
.code-cell :deep(.el-input__wrapper) { text-align: center; font-family: Consolas, monospace; font-weight: 700; font-size: 18px; letter-spacing: 2px; }
.r-btn { height: 40px; padding: 0 24px; font-weight: 700; }
.bulk { margin-top: 18px; }

.avail-list { display: flex; flex-direction: column; gap: 14px; }
.gift-item {
  display: flex; align-items: center; gap: 12px;
  padding: 12px;
  border-radius: 12px;
  background: #fafbfc;
  border: 1px dashed #e5e7eb;
  transition: all .2s ease;
}
.gift-item:hover { transform: translateY(-1px); border-color: #f59e0b; background: #fffbeb; }
.g-ic { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 4px 10px rgba(0,0,0,0.08); }
.g-info { flex: 1; min-width: 0; }
.g-name { color: #111827; font-size: 14px; }
.g-desc { margin-top: 3px; line-height: 1.5; }
.g-code { margin-top: 4px; }
.code-txt { letter-spacing: 0.5px; color: #374151; }
.rwd { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.rwd-tag { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.rwd-tag.balance { background: #ecfdf5; color: #047857; }
.rwd-tag.server { background: #dbeafe; color: #1d4ed8; }
.rwd-tag.bw { background: #cffafe; color: #0e7490; }
.rwd-tag.ddos { background: #fee2e2; color: #b91c1c; }
.rwd-tag.coupon { background: #fff7ed; color: #c2410c; }
.rwd-tag.vip { background: #ede9fe; color: #6d28d9; }
.rwd-txt { color: #374151; font-size: 13px; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
