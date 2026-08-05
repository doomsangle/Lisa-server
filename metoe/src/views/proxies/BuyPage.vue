<template>
  <div class="buy-page">
    <div class="tabs-header">
      <el-tabs v-model="mainTab" class="main-tabs">
        <el-tab-pane name="buy">
          <template #label>
            <el-icon><ShoppingCart /></el-icon>
            购买全球云服务器
          </template>
        </el-tab-pane>
        <el-tab-pane name="owned">
          <template #label>
            <el-icon><Monitor /></el-icon>
            已购服务器明细
          </template>
        </el-tab-pane>
      </el-tabs>
      <div class="switch-hint muted small">
        <el-switch v-model="exactMode" inline-prompt active-text="精准配置" inactive-text="智能推荐" />
      </div>
    </div>

    <template v-if="mainTab === 'owned'">
      <ServersListInline />
    </template>

    <el-row v-else :gutter="18">
      <el-col :span="17">
        <div class="form-section">
          <h4 class="sec-title" style="cursor:pointer;user-select:none" @click="regionCollapsed = !regionCollapsed">
            <el-icon><LocationFilled /></el-icon>
            <span>区域与节点</span>
            <el-tag size="small" type="info" effect="plain" class="tag-subtitle">需求国家 · 可选地区</el-tag>
            <el-icon :class="['collapse-arrow', { open: !regionCollapsed }]" style="margin-left:auto;color:#9aa3b2"><ArrowDown /></el-icon>
          </h4>
          <div v-show="!regionCollapsed">
          <div class="country-top">
            <el-button type="primary" size="default" @click="quickSelectUS()">
              <el-icon><Star /></el-icon> 一键选择 · 🇺🇸 美国 · 随机节点
            </el-button>
            <el-tag effect="plain" type="success" size="default">推荐区域 · 库存充足</el-tag>
          </div>

          <el-tabs v-model="regionTab" class="region-tabs">
            <el-tab-pane label="美洲和欧洲" name="us_eu">
              <div class="country-grid">
                <div v-for="c in americasEur" :key="c.code"
                  :class="['country-card', { active: form.country === c.code }]"
                  @click="selectCountry(c)">
                  <span class="flag">{{ c.flag }}</span>
                  <span class="name">{{ c.name }}</span>
                  <span class="stock muted small">库存 {{ c.stock }} 台</span>
                  <span class="price-tag" v-if="c.priceFactor > 1">+{{ Math.round((c.priceFactor-1)*100) }}%</span>
                </div>
              </div>
              <h5 class="area-title muted small">可选地区</h5>
              <div class="city-grid">
                <div v-for="city in activeCities" :key="city"
                  :class="['city-chip', { active: form.city === city }]"
                  @click="form.city = city">
                  {{ city }}
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane label="亚洲和大洋洲" name="asia_oceania">
              <div class="country-grid">
                <div v-for="c in asiaOceania" :key="c.code"
                  :class="['country-card', { active: form.country === c.code }]"
                  @click="selectCountry(c)">
                  <span class="flag">{{ c.flag }}</span>
                  <span class="name">{{ c.name }}</span>
                  <span class="stock muted small">库存 {{ c.stock }} 台</span>
                  <span class="price-tag" v-if="c.priceFactor > 1">+{{ Math.round((c.priceFactor-1)*100) }}%</span>
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane label="拉美和非洲" name="lala_afr">
              <div class="country-grid">
                <div v-for="c in lalaAfr" :key="c.code"
                  :class="['country-card', { active: form.country === c.code }]"
                  @click="selectCountry(c)">
                  <span class="flag">{{ c.flag }}</span>
                  <span class="name">{{ c.name }}</span>
                  <span class="stock muted small">库存 {{ c.stock }} 台</span>
                  <span class="price-tag" v-if="c.priceFactor > 1">+{{ Math.round((c.priceFactor-1)*100) }}%</span>
                </div>
              </div>
            </el-tab-pane>
          </el-tabs>
          </div>
        </div>

        <el-row :gutter="18" class="mt-18">
          <el-col :span="12">
            <div class="form-section">
              <h4 class="sec-title"><el-icon><Van /></el-icon><span>接入与交付</span></h4>
              <div class="field-row">
                <label>交付协议</label>
                <el-radio-group v-model="form.protocol" size="default">
                  <el-radio value="Socks5">Socks5</el-radio>
                  <el-radio value="SSH/RDP">SSH / RDP</el-radio>
                  <el-radio value="Web面板">Web 面板</el-radio>
                </el-radio-group>
              </div>
              <div class="field-row">
                <label>目标业务用途</label>
                <el-input v-model="form.usagePurpose" placeholder="例如：多店铺 / 数据采集 / 网站托管" clearable />
              </div>
              <div class="field-row">
                <label>使用环境</label>
                <el-select v-model="form.env" placeholder="选择部署环境" style="width:100%">
                  <el-option label="Chrome / 浏览器环境" value="chrome" />
                  <el-option label="Python / Node.js 脚本" value="script" />
                  <el-option label="移动端 (安卓/iOS)" value="mobile" />
                  <el-option label="企业局域网出口" value="office" />
                  <el-option label="通用部署" value="general" />
                </el-select>
              </div>
              <div class="field-row">
                <label>加密模式</label>
                <el-radio-group v-model="form.encryptMode">
                  <el-radio value="default" border>默认全局加密</el-radio>
                  <el-radio value="random" border>系统随机加密</el-radio>
                </el-radio-group>
              </div>
              <div class="field-row">
                <label>UDP 转发</label>
                <el-switch v-model="form.udp" active-text="开启" inactive-text="关闭" />
              </div>
            </div>
          </el-col>
          <el-col :span="12">
            <div class="form-section">
              <h4 class="sec-title"><el-icon><Cpu /></el-icon><span>电脑配置</span></h4>
              <div class="plan-grid-mini">
                <div v-for="p in cpuPlans" :key="p.key"
                  :class="['plan-mini', { active: form.cpuPlan === p.key, recommended: p.recommended }]"
                  @click="selectCpuPlan(p)">
                  <div v-if="p.recommended" class="reco-mini">推荐</div>
                  <div class="pn">{{ p.name }}</div>
                  <div class="ps">
                    <b>{{ p.cpu }}核</b> / {{ p.ram }}G / {{ p.disk }}G
                  </div>
                  <div class="pp"><span class="currency">¥</span>{{ p.priceMonth }}<span class="unit">/月</span></div>
                </div>
              </div>
              <div class="field-row mt-12">
                <label>操作系统</label>
                <el-radio-group v-model="form.os">
                  <el-radio-button value="Ubuntu 22.04 LTS">Ubuntu 22.04</el-radio-button>
                  <el-radio-button value="CentOS 7.9">CentOS 7.9</el-radio-button>
                  <el-radio-button value="Debian 12">Debian 12</el-radio-button>
                  <el-radio-button value="Windows Server 2022">Win 2022</el-radio-button>
                </el-radio-group>
              </div>
            </div>
          </el-col>
        </el-row>

        <div class="form-section mt-18">
          <h4 class="sec-title"><el-icon><Connection /></el-icon><span>带宽计费模式</span></h4>
          <el-radio-group v-model="form.bwMode">
            <el-radio value="fixed" border><el-icon><Coin /></el-icon> 按固定量计费</el-radio>
            <el-radio value="shared" border><el-icon><Share /></el-icon> 按共享带宽</el-radio>
          </el-radio-group>
          <div class="bandwidth-box">
            <div class="bw-buttons">
              <div v-for="b in bandwidthList" :key="b.mbps"
                :class="['bw-chip', { active: form.bandwidth === b.mbps }]"
                @click="form.bandwidth = b.mbps">
                <b>{{ b.mbps }}</b> Mbps
              </div>
              <el-input-number
                v-model="form.customBw" :min="5" :max="1000" :step="10" size="default"
                controls-position="right" style="width:170px;margin-left:8px"
                @change="form.bandwidth = form.customBw"
              />
              <span class="muted small" style="margin-left:8px">Mbps</span>
            </div>
            <div class="field-row mt-12">
              <label>专线加密入口</label>
              <el-switch v-model="form.dedicatedEntry" active-text="原生入口" inactive-text="默认入口" />
            </div>
          </div>
        </div>

        <div class="form-section mt-18">
          <h4 class="sec-title"><el-icon><Lock /></el-icon><span>认证方式（登录凭据）</span></h4>
          <el-radio-group v-model="form.authMode">
            <el-radio value="userpass" border>账号密码认证</el-radio>
            <el-radio value="whitelist" border>IP 白名单</el-radio>
            <el-radio value="preset" border>按指定账号密码</el-radio>
          </el-radio-group>
          <div class="account-box" v-if="form.authMode !== 'whitelist'">
            <div class="field-row">
              <label>默认账号</label>
              <el-input v-model="form.username" class="acct-input">
                <template #append>
                  <el-button type="primary" link size="small" :icon="DocumentCopy" @click="copy(form.username)">复制</el-button>
                  <el-button type="primary" link size="small" :icon="RefreshRight" @click="resetUser" style="margin-left:4px">重置</el-button>
                </template>
              </el-input>
            </div>
            <div class="field-row">
              <label>默认密码</label>
              <el-input v-model="form.password" show-password class="acct-input">
                <template #append>
                  <el-button type="primary" link size="small" :icon="DocumentCopy" @click="copy(form.password)">复制</el-button>
                  <el-button type="primary" link size="small" :icon="Key" @click="genPassword" style="margin-left:4px" title="随机生成密码">生成</el-button>
                  <el-button type="primary" link size="small" :icon="RefreshRight" @click="genPassword(true)" style="margin-left:4px">重置</el-button>
                </template>
              </el-input>
            </div>
            <el-alert class="mt-8" type="info" :closable="false" show-icon
              title="默认账号与密码将在服务器开通后自动同步至您的账户中心，支持随时重置与修改。" />
          </div>
          <div v-else class="whitelist-box">
            <el-input v-model="form.whitelistIps" type="textarea" :rows="3"
              placeholder="每行一个 IP，最多 10 个；例如&#10;203.0.113.21&#10;198.51.100.44" />
          </div>
        </div>
      </el-col>

      <el-col :span="7">
        <div class="order-card sticky">
          <div class="order-head">
            <h5><el-icon><DocumentChecked /></el-icon> 请确认您的订单</h5>
            <span class="order-no muted small" v-if="pendingOrderNo">单号：{{ pendingOrderNo }}</span>
          </div>

          <el-descriptions class="order-info" :column="1" border size="small">
            <el-descriptions-item label="服务器类型">云服务器 / 多区域可选</el-descriptions-item>
            <el-descriptions-item label="国家/地区">{{ selectedCountryFlag }} {{ selectedCountryName }}</el-descriptions-item>
            <el-descriptions-item label="交付协议">{{ form.protocol }}</el-descriptions-item>
            <el-descriptions-item label="带宽规格">{{ form.bandwidth }} Mbps / 独享{{ form.bwMode === 'shared' ? '（共享池）' : '' }}</el-descriptions-item>
            <el-descriptions-item label="目标业务">{{ form.usagePurpose || '未指定' }}</el-descriptions-item>
          </el-descriptions>

          <div class="section-mini">
            <div class="mini-label">订购时长</div>
            <el-radio-group v-model="form.period" class="period-tabs">
              <el-radio-button value="1m">30 天</el-radio-button>
              <el-radio-button value="3m">60 天</el-radio-button>
              <el-radio-button value="6m">90 天</el-radio-button>
              <el-radio-button value="1y">120 天+</el-radio-button>
            </el-radio-group>
          </div>

          <div class="section-mini">
            <div class="mini-label">IP 购买数量</div>
            <div class="qty-row">
              <el-input-number v-model="form.qty" :min="1" :max="50" size="default" controls-position="right" style="width:140px" />
              <span class="unit muted small">台</span>
              <el-button link type="primary" size="small" @click="form.qty = Math.max(1, form.qty-1)">-1</el-button>
              <el-button link type="primary" size="small" @click="form.qty = Math.min(50, form.qty+1)">+1</el-button>
            </div>
          </div>

          <div class="section-mini">
            <div class="mini-label">自动续费（余额扣）</div>
            <el-switch v-model="form.autoRenew" active-text="开启" inactive-text="关闭" />
          </div>

          <el-divider class="mini-divider" />

          <div class="section-mini">
            <div class="mini-label">支付方式</div>
            <el-tabs v-model="form.payMethod" class="pay-tabs">
              <el-tab-pane name="balance">
                <template #label><el-icon><Wallet /></el-icon>余额支付 <el-tag size="small" type="warning" effect="dark">¥{{ balance.toFixed(2) }}</el-tag></template>
              </el-tab-pane>
              <el-tab-pane name="alipay">
                <template #label><el-icon><Money /></el-icon>支付宝支付</template>
              </el-tab-pane>
              <el-tab-pane name="wechat">
                <template #label><el-icon><ChatDotRound /></el-icon>微信支付</template>
              </el-tab-pane>
            </el-tabs>
          </div>

          <div class="price-summary">
            <div class="sum-line"><span>订单金额</span><span class="line-price">¥ {{ subtotal.toFixed(2) }}</span></div>
            <div class="sum-line" v-if="discountsTotal > 0"><span>优惠合计</span><span class="ok">- ¥ {{ discountsTotal.toFixed(2) }}</span></div>
            <div class="sum-line total-line">
              <span>总价</span>
              <span class="big-price"><small class="currency">¥</small>{{ total.toFixed(2) }}</span>
            </div>
          </div>

          <el-checkbox v-model="form.agree" class="agree-check">
            我已阅读并同意<a class="link" href="javascript:void(0)">《用户服务协议》</a>与<a class="link" href="javascript:void(0)">《退款政策》</a>
          </el-checkbox>

          <el-button class="submit-btn"
            :disabled="!canSubmit" :loading="submitting" @click="onSubmit">
            <el-icon><CircleCheckFilled /></el-icon>
            确认购买
          </el-button>

          <div class="tips muted small">
            ⚠️ 本网络仅供合法进出口贸易、跨境电商、数据分析使用，禁止任何违反所在国家法律法规的行为。
            订单确认后将进入 <b>实名认证 → 支付 → 资源分配（30~90秒）</b>，可在「已购服务器明细」中查看进度。
          </div>
        </div>
      </el-col>
    </el-row>

    <el-tooltip content="在线客服 · 7×24小时" placement="left">
      <el-button type="success" class="float-help-btn" @click="csVisible = true">
        <el-icon :size="22"><Service /></el-icon>
      </el-button>
    </el-tooltip>
    <el-drawer v-model="csVisible" title="客服支持" direction="rtl" size="380px">
      <div class="cs-mini">
        <div class="cs-item"><el-icon><ChatDotRound /></el-icon><b>微信：</b> metoe_support_01<el-button link size="small" @click="copy('metoe_support_01')">复制</el-button></div>
        <div class="cs-item"><el-icon><Phone /></el-icon><b>QQ：</b> 800888666<el-button link size="small" @click="copy('800888666')">复制</el-button></div>
        <div class="cs-item"><el-icon><Message /></el-icon><b>邮箱：</b> support@metoe.io</div>
        <div class="cs-item"><el-icon><PhoneFilled /></el-icon><b>热线：</b> 400-888-6666（周一至周日 09:00-23:00）</div>
      </div>
    </el-drawer>
  </div>
</template>
<script setup>
import { reactive, ref, computed, watch, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { getCountryTree, getPrices, buyProxy } from '@/api/proxies'
import {
  ShoppingCart, Monitor, LocationFilled, Star, Van,
  Cpu, Connection, Coin, Share, Lock,
  DocumentChecked, Wallet, Money, ChatDotRound, CircleCheckFilled,
  Service, Phone, Message, PhoneFilled, ArrowDown,
  DocumentCopy, RefreshRight, Key
} from '@element-plus/icons-vue'
import ServersListInline from '@/views/ServersList.vue'

const router = useRouter()
const userStore = useUserStore()
const submitting = ref(false)
const csVisible = ref(false)
const pendingOrderNo = ref('')
const mainTab = ref('buy')
const exactMode = ref(false)
const regionTab = ref('us_eu')
const regionCollapsed = ref(true)

const balance = computed(() => Number(userStore.userInfo?.balance || 0))

const americasEur = ref([])
const asiaOceania = ref([])
const lalaAfr = ref([])
const cityMap = reactive({
  US: ['随机','菲尼克斯','洛杉矶','亚特兰大','芝加哥','新奥尔良','硅谷','达拉斯','休斯顿','迈阿密','俄勒冈','波特兰','纽约','新泽西','西雅图','华盛顿特区','波士顿','圣何塞','纳什维尔','明尼阿波利斯'],
  GB: ['随机','伦敦','曼彻斯特','剑桥','利兹'],
  FR: ['随机','巴黎','里昂','马赛'],
  DE: ['随机','法兰克福','慕尼黑','柏林','汉堡'],
  CA: ['随机','多伦多','温哥华','蒙特利尔','卡尔加里'],
  ES: ['随机','马德里','巴塞罗那'],
  IT: ['随机','米兰','罗马'],
  NL: ['随机','阿姆斯特丹','鹿特丹'],
  AT: ['随机','维也纳'],
  CH: ['随机','苏黎世','日内瓦'],
  DK: ['随机','哥本哈根'],
  SE: ['随机','斯德哥尔摩'],
  PL: ['随机','华沙'],
})

const cpuPlans = ref([
  { key: 'econ',   name: '经济型', cpu: 1, ram: 1,  disk: 25,  os: 'Ubuntu 22.04 LTS', priceMonth: 59 },
  { key: 'std',    name: '标准版', cpu: 2, ram: 2,  disk: 50,  os: 'Ubuntu 22.04 LTS', priceMonth: 149, recommended: true },
  { key: 'pro',    name: '专业版', cpu: 4, ram: 4,  disk: 100, os: 'Ubuntu 22.04 LTS', priceMonth: 299 },
  { key: 'biz',    name: '商务版', cpu: 8, ram: 8,  disk: 200, os: 'Ubuntu 22.04 LTS', priceMonth: 699 },
  { key: 'corp',   name: '企业版', cpu: 16,ram: 32, disk: 500, os: 'Ubuntu 22.04 LTS', priceMonth: 1999 },
])

const bandwidthList = [
  { mbps: 5,   traffic: 250,   priceAdd: 0 },
  { mbps: 10,  traffic: 500,   priceAdd: 19 },
  { mbps: 15,  traffic: 750,   priceAdd: 29 },
  { mbps: 20,  traffic: 1000,  priceAdd: 39 },
  { mbps: 25,  traffic: 1500,  priceAdd: 49 },
  { mbps: 30,  traffic: 2000,  priceAdd: 69 },
]

function genPwd() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%'
  return Array.from({length:16}, ()=>chars[Math.floor(Math.random()*chars.length)]).join('')
}

const form = reactive({
  country: 'US',
  city: '随机',
  protocol: 'SSH/RDP',
  usagePurpose: '跨境电商',
  env: 'chrome',
  encryptMode: 'default',
  udp: false,
  cpuPlan: 'std',
  os: 'Ubuntu 22.04 LTS',
  bwMode: 'fixed',
  bandwidth: 5,
  customBw: 5,
  dedicatedEntry: false,
  authMode: 'preset',
  username: 'root',
  password: genPwd(),
  whitelistIps: '',
  period: '1m',
  qty: 1,
  autoRenew: true,
  payMethod: 'balance',
  agree: false,
})

function genPassword(reset=false) { form.password = genPwd() }
function resetUser() { form.username = form.os.startsWith('Windows') ? 'Administrator' : 'root' }
function copy(text, msg='已复制到剪贴板') {
  if (navigator.clipboard) navigator.clipboard.writeText(text)
  ElMessage.success(msg)
}
function selectCountry(c) {
  form.country = c.code
  const cities = cityMap[c.code]
  form.city = cities && cities.length ? cities[0] : '随机'
}
function selectCpuPlan(p) {
  form.cpuPlan = p.key
  if (p.os && !form.os.startsWith('Windows')) form.os = p.os
}
function quickSelectUS() {
  regionCollapsed.value = false
  const us = americasEur.value.find(c => c.code === 'US')
  if (us) { selectCountry(us); regionTab.value = 'us_eu' }
  else { form.country = 'US'; form.city = '随机' }
  ElMessage.success('已快速选择美国 · 随机节点')
}

async function loadCountryTree() {
  try {
    const tree = await getCountryTree()
    if (tree && tree.length) {
      const groupMap = { '热门地区': americasEur, '美洲': americasEur, '欧洲': americasEur, '亚太': asiaOceania }
      const defaultFactor = (g) => {
        if (g === '热门地区') return 1.0
        if (g === '美洲') return 1.05
        if (g === '欧洲') return 1.1
        if (g === '亚太') return 1.08
        return 1.12
      }
      const seen = { us_eu: new Set(), asia: new Set() }
      tree.forEach((g) => {
        const key = g.group || '热门地区'
        const target = groupMap[key]
        if (!target) return
        const factor = defaultFactor(key)
        const items = (g.items || []).map((it) => ({
          ...it,
          stock: it.stock || Math.floor(Math.random()*5000)+500,
          priceFactor: it.priceBase ? (it.priceBase / 29) : factor,
        }))
        items.forEach((it) => {
          const bucket = key === '亚太' ? seen.asia : seen.us_eu
          if (bucket.has(it.code)) return
          bucket.add(it.code)
          target.value.push(it)
        })
      })
      if (!lalaAfr.value.length) {
        lalaAfr.value = [
          { code: 'BR', name: '巴西', flag: '🇧🇷', stock: 880, priceFactor: 1.22 },
          { code: 'MX', name: '墨西哥', flag: '🇲🇽', stock: 1520, priceFactor: 1.15 },
          { code: 'AR', name: '阿根廷', flag: '🇦🇷', stock: 430, priceFactor: 1.24 },
          { code: 'ZA', name: '南非', flag: '🇿🇦', stock: 610, priceFactor: 1.28 },
          { code: 'EG', name: '埃及', flag: '🇪🇬', stock: 320, priceFactor: 1.26 },
          { code: 'KE', name: '肯尼亚', flag: '🇰🇪', stock: 210, priceFactor: 1.3 },
        ]
      }
      if (!form.country && americasEur.value.length) {
        const us = americasEur.value.find(c => c.code === 'US')
        if (us) { selectCountry(us); return }
        selectCountry(americasEur.value[0])
      }
    }
  } catch (e) {}
}

async function loadPrices() {
  try {
    const res = await getPrices({ category: 'ISP' })
    const plans = res?.data?.plans || res?.plans || []
    if (plans.length) {
      const map = { basic:'econ', standard:'std', pro:'pro', corp:'corp' }
      plans.forEach((p) => {
        const k = map[p.key]
        if (k) {
          const target = cpuPlans.value.find((x) => x.key === k)
          if (target) target.priceMonth = p.price
        }
      })
    }
  } catch (e) {}
}

watch(() => form.os, (v) => {
  if (v.startsWith('Windows')) form.username = 'Administrator'
  else form.username = 'root'
})

const activeCities = computed(() => {
  return cityMap[form.country] || ['随机']
})
const allCountries = computed(() => [...americasEur.value, ...asiaOceania.value, ...lalaAfr.value])
const countryMap = computed(() => Object.fromEntries(allCountries.value.map(c => [c.code, c])))
const selectedCountry = computed(() => countryMap.value[form.country] || { flag:'🇺🇸', name:'美国' })
const selectedCountryName = computed(() => selectedCountry.value.name)
const selectedCountryFlag = computed(() => selectedCountry.value.flag)
const selectedCpu = computed(() => cpuPlans.value.find(p => p.key === form.cpuPlan) || cpuPlans.value[1])
const periodMonths = computed(() => ({ '1m': 1, '3m': 2, '6m': 3, '1y': 4 })[form.period])
const periodFactor = computed(() => ({ '1m': 1, '3m': 0.95, '6m': 0.9, '1y': 0.84 })[form.period])

const bwPriceAdd = computed(() => {
  const match = bandwidthList.find(b => b.mbps === Number(form.bandwidth))
  if (match) return match.priceAdd
  return Math.round((Number(form.bandwidth) || 10) * 2.3)
})

const basePrice = computed(() => selectedCpu.value.priceMonth)
const regionAdd = computed(() => {
  const f = (selectedCountry.value?.priceFactor) || 1
  return Math.max(0, basePrice.value * (f - 1))
})
const unitPrice = computed(() => basePrice.value + regionAdd.value + bwPriceAdd.value + (form.dedicatedEntry ? 19 : 0))
const subtotal = computed(() => unitPrice.value * form.qty * periodMonths.value)
const periodDiscount = computed(() => subtotal.value * Math.max(0, 1 - periodFactor.value))
const qtyDiscount = computed(() => {
  const base = subtotal.value * periodFactor.value
  if (form.qty >= 20) return base * 0.15
  if (form.qty >= 10) return base * 0.08
  if (form.qty >= 5)  return base * 0.04
  return 0
})
const discountsTotal = computed(() => periodDiscount.value + qtyDiscount.value)
const total = computed(() => Math.max(0.01, subtotal.value - discountsTotal.value))

const canSubmit = computed(() =>
  !!form.country && !!form.cpuPlan && form.bandwidth > 0 && form.agree &&
  (form.authMode === 'whitelist' || (form.password && form.password.length >= 8 && form.username))
)

async function onSubmit() {
  if (!canSubmit.value) { ElMessage.warning('请完善配置并勾选用户服务协议'); return }
  if (form.payMethod === 'balance' && balance.value < total.value) {
    ElMessage.warning(`账户余额不足，还差 ¥ ${(total.value - balance.value).toFixed(2)}，请选择其他支付方式或充值。`)
    return
  }
  submitting.value = true
  try {
    const sc = selectedCountry.value || {}
    const res = await buyProxy({
      category: 'cloud_server',
      country: form.country,
      countryName: sc.name,
      countryFlag: sc.flag,
      city: form.city,
      qty: form.qty,
      period: form.period,
      plan: form.cpuPlan,
      cpu: selectedCpu.value.cpu,
      ram: selectedCpu.value.ram,
      disk: selectedCpu.value.disk,
      os: form.os,
      bandwidth: form.bandwidth,
      traffic: Math.round((Number(form.bandwidth) || 10) * 60),
      usage: form.env,
      usagePurpose: form.usagePurpose,
      protocol: form.protocol,
      encryptMode: form.encryptMode,
      udp: form.udp,
      bwMode: form.bwMode,
      dedicatedEntry: form.dedicatedEntry,
      authMode: form.authMode,
      username: form.username,
      password: form.password,
      whitelistIps: form.whitelistIps,
      payMethod: form.payMethod,
      autoRenew: form.autoRenew,
      amount: subtotal.value,
      discount: discountsTotal.value,
      total: total.value,
    })
    pendingOrderNo.value = res?.data?.orderNo || res?.orderNo || ''
    ElMessage.success('订单已创建，正在跳转支付与交付流程')
    router.push(`/orders/${res?.data?.orderNo || res?.orderNo}?pay=1`)
  } catch (e) {
    ElMessage.error(e.message || '下单失败')
  } finally {
    submitting.value = false
  }
}

onMounted(async () => { await Promise.all([loadCountryTree(), loadPrices()]) })
</script>
<style scoped>
.buy-page { position: relative; }
.tabs-header {
  display: flex; justify-content: space-between; align-items: center;
  background: #fff; padding: 0 20px; border-radius: 12px; margin-bottom: 18px;
  border: 1px solid #eef0f4;
}
.main-tabs :deep(.el-tabs__header) { margin: 0; border: none; }
.main-tabs :deep(.el-tabs__item) { height: 58px; line-height: 58px; font-size: 15px; font-weight: 600; padding: 0 28px; }
.main-tabs :deep(.el-tabs__item.is-active) { color: #10b981; }
.main-tabs :deep(.el-tabs__active-bar) { background: #10b981; height: 3px; border-radius: 2px; }
.switch-hint { display: flex; align-items: center; gap: 8px; }

.form-section {
  background: #fff; padding: 22px 22px 20px; border-radius: 14px;
  border: 1px solid #eef0f4;
}
.sec-title {
  margin: 0 0 16px; display: flex; align-items: center; gap: 8px;
  font-size: 15px; color: #111827; font-weight: 700;
}
.sec-title .el-icon { color: #10b981; }
.tag-subtitle { margin-left: auto; font-weight: 500; }
.collapse-arrow {
  margin-left: 10px; transition: transform .28s cubic-bezier(.4,0,.2,1);
}
.collapse-arrow.open { transform: rotate(180deg); }

.country-top {
  margin-bottom: 16px;
  display: flex; align-items: center; gap: 12px;
}
.region-tabs :deep(.el-tabs__header) { margin: 0 0 14px; }
.country-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
.country-card {
  position: relative; border: 1.5px solid #e5e7eb; border-radius: 14px; padding: 14px 10px 12px;
  cursor: pointer; transition: all .22s cubic-bezier(.4,0,.2,1); display: flex; flex-direction: column; align-items: center; gap: 5px;
  background: #fff; overflow: hidden;
}
.country-card::before {
  content: ''; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(16,185,129,.04), transparent 45%);
  opacity: 0; transition: opacity .22s;
}
.country-card:hover {
  border-color: #34d399; transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(16,185,129,.14), 0 2px 6px rgba(16,185,129,.08);
}
.country-card:hover::before { opacity: 1; }
.country-card.active {
  border-color: #10b981; background: #ecfdf5;
  box-shadow: 0 0 0 4px rgba(16,185,129,.13), 0 6px 16px rgba(16,185,129,.18);
}
.country-card.active::before { opacity: 1; }
.country-card .flag { font-size: 32px; filter: drop-shadow(0 1px 2px rgba(0,0,0,.08)); }
.country-card .name { font-weight: 700; color: #111827; font-size: 13.5px; letter-spacing: .2px; }
.country-card .stock { color: #6b7280; font-size: 11.5px; }
.country-card .price-tag {
  position: absolute; top: 8px; right: 8px;
  background: linear-gradient(135deg, #f87171, #ef4444); color: #fff; font-size: 10.5px;
  padding: 2px 8px; border-radius: 999px; font-weight: 700; letter-spacing: .2px;
  box-shadow: 0 2px 6px rgba(239,68,68,.3);
}
.area-title { margin: 18px 0 10px; font-weight: 700; font-size: 12px; letter-spacing: .5px; color: #374151; text-transform: uppercase; }
.city-grid { display: flex; flex-wrap: wrap; gap: 10px; }
.city-chip {
  padding: 7px 16px; border: 1.5px solid #e5e7eb; border-radius: 999px;
  background: #fff; cursor: pointer; font-size: 12.5px; color: #374151; font-weight: 500;
  transition: all .18s;
}
.city-chip:hover { border-color: #409eff; background: #f0f7ff; color: #409eff; transform: translateY(-1px); }
.city-chip.active {
  background: linear-gradient(135deg, #409eff, #2b7cd3); border-color: #2b7cd3;
  color: #fff; font-weight: 600;
  box-shadow: 0 4px 10px rgba(64,158,255,.32);
}

.field-row {
  display: flex; align-items: center; gap: 14px; padding: 10px 0;
  border-bottom: 1px dashed #f0f2f6;
}
.field-row:last-child { border-bottom: none; }
.field-row label {
  width: 104px; color: #4b5563; font-weight: 600; font-size: 13px; flex-shrink: 0;
}

.plan-grid-mini { display: grid; grid-template-columns: repeat(5, 1fr); gap: 12px; }
.plan-mini {
  position: relative; border: 2px solid #e5e7eb; border-radius: 14px; padding: 14px 10px 12px;
  cursor: pointer; transition: all .22s cubic-bezier(.4,0,.2,1); background: #fff; text-align: center;
  overflow: hidden;
}
.plan-mini::before {
  content: ''; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(16,185,129,.05), transparent 55%);
  opacity: 0; transition: opacity .22s;
}
.plan-mini:hover {
  border-color: #409eff; transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(64,158,255,.14), 0 2px 6px rgba(64,158,255,.08);
}
.plan-mini:hover::before { opacity: 1; }
.plan-mini.active {
  border-color: #10b981; background: #ecfdf5;
  box-shadow: 0 0 0 4px rgba(16,185,129,.13), 0 8px 18px rgba(16,185,129,.18);
}
.plan-mini.active::before { opacity: 1; }
.reco-mini {
  position: absolute; top: -1px; left: 50%; transform: translateX(-50%);
  background: linear-gradient(135deg, #fbbf24, #f59e0b); color: #fff;
  padding: 2px 12px 3px; border-radius: 0 0 10px 10px; font-size: 10.5px; font-weight: 800;
  letter-spacing: .5px; text-transform: uppercase;
  box-shadow: 0 2px 6px rgba(245,158,11,.35);
}
.plan-mini .pn { font-weight: 800; font-size: 14px; margin-bottom: 6px; color: #111827; letter-spacing: .2px; }
.plan-mini .ps { font-size: 11.5px; color: #6b7280; margin-bottom: 8px; line-height: 1.5; }
.plan-mini .ps b { color: #111827; font-weight: 700; }
.plan-mini .pp { color: #ef4444; font-weight: 800; font-size: 15px; }
.plan-mini .pp .currency { font-size: 11px; color: #f87171; font-weight: 700; }
.plan-mini .pp .unit { color: #9ca3af; font-size: 11px; font-weight: 600; margin-left: 2px; }

.bandwidth-box { margin-top: 16px; }
.bw-buttons { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
.bw-chip {
  border: 2px solid #e5e7eb; padding: 9px 18px; border-radius: 12px;
  cursor: pointer; background: #fff; transition: all .2s; font-size: 13px; font-weight: 600;
  color: #374151; position: relative;
}
.bw-chip:hover {
  border-color: #409eff; color: #409eff; transform: translateY(-1px);
  box-shadow: 0 4px 10px rgba(64,158,255,.15);
}
.bw-chip.active {
  background: linear-gradient(135deg, #409eff, #2b7cd3); border-color: #2b7cd3;
  color: #fff; font-weight: 700;
  box-shadow: 0 0 0 4px rgba(64,158,255,.14), 0 6px 16px rgba(64,158,255,.32);
}
.bw-chip b { font-size: 14px; }

.account-box {
  margin-top: 16px; background: linear-gradient(180deg, #f9fafb, #fff);
  border: 1.5px solid #e5e7eb; border-radius: 14px; padding: 16px 18px;
  box-shadow: inset 0 1px 0 rgba(255,255,255,.8);
}
.acct-input { max-width: 360px; }
.whitelist-box { margin-top: 16px; }

.form-section {
  background: #fff; padding: 24px 24px 22px; border-radius: 16px;
  border: 1px solid #eef0f4;
  box-shadow: 0 1px 3px rgba(17,24,39,.03), 0 1px 2px rgba(17,24,39,.02);
  transition: box-shadow .2s, transform .2s;
}
.form-section:hover { box-shadow: 0 4px 14px rgba(17,24,39,.05); }
.sec-title {
  margin: 0 0 18px; display: flex; align-items: center; gap: 10px;
  font-size: 16px; color: #111827; font-weight: 800; letter-spacing: .2px;
}
.sec-title .el-icon {
  color: #10b981; font-size: 18px;
  width: 28px; height: 28px; border-radius: 8px;
  background: linear-gradient(135deg, #ecfdf5, #d1fae5);
  display: inline-flex; align-items: center; justify-content: center;
}
.tag-subtitle {
  margin-left: auto; font-weight: 600; padding: 3px 10px;
  background: #f3f4f6; border-radius: 999px; font-size: 12px; color: #4b5563;
}

.field-row {
  display: flex; align-items: center; gap: 16px; padding: 12px 0;
  border-bottom: 1px dashed #f0f2f6;
}
.field-row:last-child { border-bottom: none; }
.field-row label {
  width: 108px; color: #374151; font-weight: 700; font-size: 13px; flex-shrink: 0;
  letter-spacing: .2px;
}
.country-top {
  margin-bottom: 18px; display: flex; align-items: center; gap: 14px;
}
.country-top .el-button { border-radius: 10px; height: 38px; font-weight: 600; }

.order-card {
  background: #fff; border-radius: 18px; padding: 22px 22px 26px;
  border: 1px solid #eef0f4; position: relative;
  box-shadow: 0 2px 10px rgba(17,24,39,.04), 0 8px 30px rgba(16,185,129,.06);
}
.order-card::before {
  content: ''; position: absolute; inset: 0; border-radius: 18px; pointer-events: none;
  background: linear-gradient(135deg, rgba(16,185,129,.05), transparent 35%);
}
.sticky { position: sticky; top: 10px; }
.order-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; position: relative; }
.order-head h5 {
  margin: 0; font-size: 17px; font-weight: 800; color: #111827;
  display: flex; align-items: center; gap: 8px; letter-spacing: .2px;
}
.order-head h5 .el-icon {
  color: #10b981; width: 28px; height: 28px; border-radius: 8px;
  background: linear-gradient(135deg, #ecfdf5, #d1fae5);
  display: inline-flex; align-items: center; justify-content: center; font-size: 16px;
}
.order-no { font-family: Consolas, monospace; font-size: 12px; color: #6b7280; }

.order-info { margin-bottom: 8px; }
.order-info :deep(.el-descriptions__label) {
  width: 96px; background: #f9fafb; color: #6b7280; font-weight: 600; font-size: 12.5px;
}
.order-info :deep(.el-descriptions__body .el-descriptions__cell) { padding: 10px 12px; }
.order-info :deep(.el-descriptions--border) { border-radius: 12px; overflow: hidden; }

.section-mini { padding: 12px 0 14px; display: flex; flex-direction: column; gap: 10px; position: relative; }
.mini-label { font-weight: 700; color: #111827; font-size: 13px; letter-spacing: .2px; display: flex; align-items: center; gap: 6px; }
.mini-label::before {
  content: ''; width: 3px; height: 12px; border-radius: 2px;
  background: linear-gradient(180deg, #10b981, #059669);
}
.period-tabs { width: 100%; }
.period-tabs :deep(.el-radio-group) {
  display: flex; gap: 8px;
}
.period-tabs :deep(.el-radio-button) { flex: 1; text-align: center; border: none !important; }
.period-tabs :deep(.el-radio-button__inner) {
  width: 100%; padding: 10px 0; font-weight: 700; border-radius: 10px !important;
  border: 2px solid #e5e7eb !important; margin: 0 !important; background: #fff;
  color: #4b5563; font-size: 13px; transition: all .2s !important;
}
.period-tabs :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
  background: linear-gradient(135deg, #10b981, #059669) !important;
  border-color: #059669 !important; color: #fff !important;
  box-shadow: 0 4px 12px rgba(16,185,129,.32);
  transform: translateY(-1px);
}
.period-tabs :deep(.el-radio-button:hover .el-radio-button__inner) {
  border-color: #10b981 !important; color: #10b981;
}
.qty-row { display: flex; align-items: center; gap: 12px; }
.qty-row .unit { color: #6b7280; font-weight: 500; }

.mini-divider { margin: 4px 0; border: none; border-top: 1px dashed #e5e7eb; }

.pay-tabs { position: relative; }
.pay-tabs :deep(.el-tabs__header) { margin: 0 0 6px; border-bottom: 1px solid #eef0f4; }
.pay-tabs :deep(.el-tabs__nav-wrap::after) { height: 1px; background: #eef0f4; }
.pay-tabs :deep(.el-tabs__item) {
  padding: 0 14px; height: 46px; line-height: 46px; font-weight: 700;
  color: #4b5563; font-size: 13px; transition: color .2s;
}
.pay-tabs :deep(.el-tabs__item:hover) { color: #10b981; }
.pay-tabs :deep(.el-tabs__item.is-active) {
  color: #059669; font-weight: 800;
}
.pay-tabs :deep(.el-tabs__active-bar) {
  background: linear-gradient(90deg, #10b981, #059669);
  height: 3px; border-radius: 2px 2px 0 0;
}
.pay-tabs :deep(.el-tabs__item .el-tag) { margin-left: 6px; border: none; padding: 2px 8px; font-weight: 700; border-radius: 999px; }

.price-summary {
  background: linear-gradient(135deg, #fff7ed 0%, #fef3c7 50%, #fffbeb 100%);
  border: 1.5px solid #fcd34d; border-radius: 14px; padding: 16px 18px; margin: 14px 0 16px;
  position: relative; overflow: hidden;
  box-shadow: 0 4px 12px rgba(251,191,36,.15), inset 0 1px 0 rgba(255,255,255,.8);
}
.price-summary::after {
  content: '¥'; position: absolute; right: -8px; top: -14px; font-size: 90px; font-weight: 900;
  color: rgba(251,191,36,.12); line-height: 1; font-family: 'DIN Alternate', sans-serif;
}
.sum-line {
  display: flex; justify-content: space-between; padding: 5px 0; font-size: 13px; color: #4b5563; font-weight: 500; position: relative;
}
.line-price { font-family: Consolas, 'SF Mono', Menlo, monospace; color: #111827; font-weight: 700; font-size: 13.5px; }
.total-line {
  border-top: 1.5px dashed #f59e0b; margin-top: 8px; padding-top: 12px;
  align-items: flex-end;
}
.total-line span:first-child {
  font-size: 14px; color: #111827; align-self: center; font-weight: 700; letter-spacing: .3px;
}
.big-price {
  color: #dc2626; font-size: 30px; font-weight: 900; line-height: 1;
  font-family: 'DIN Alternate', 'Oswald', Consolas, sans-serif;
  letter-spacing: -.5px; text-shadow: 0 1px 0 rgba(255,255,255,.6);
}
.big-price .currency { font-size: 16px; margin-right: 2px; vertical-align: top; font-weight: 800; color: #ef4444; }

.agree-check {
  display: block; margin-bottom: 16px; padding: 10px 12px;
  background: #f9fafb; border-radius: 10px; border: 1px solid #eef0f4;
}
.agree-check :deep(.el-checkbox__label) { color: #4b5563; font-size: 12.5px; font-weight: 500; }

.submit-btn {
  width: 100%; height: 54px; border-radius: 14px; font-size: 18px; font-weight: 800; letter-spacing: 1px;
  background: linear-gradient(135deg, #10b981 0%, #059669 50%, #047857 100%);
  border: none; color: #fff !important;
  box-shadow: 0 10px 24px rgba(16,185,129,.4), 0 4px 10px rgba(4,120,87,.25);
  transition: all .22s cubic-bezier(.4,0,.2,1);
  position: relative; overflow: hidden;
}
.submit-btn::before {
  content: ''; position: absolute; inset: 0;
  background: linear-gradient(135deg, rgba(255,255,255,.18), transparent 50%);
  pointer-events: none;
}
.submit-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 14px 32px rgba(16,185,129,.48), 0 6px 14px rgba(4,120,87,.3);
  filter: saturate(1.08);
}
.submit-btn:active { transform: translateY(0); box-shadow: 0 6px 16px rgba(16,185,129,.4); }
.submit-btn:disabled {
  background: linear-gradient(135deg, #9ca3af, #6b7280) !important;
  box-shadow: 0 2px 8px rgba(107,114,128,.2) !important;
  transform: none !important; filter: none;
  cursor: not-allowed;
}
.submit-btn :deep(.el-icon) { font-size: 20px !important; margin-right: 4px; }

.tips {
  margin-top: 16px; line-height: 1.75;
  background: linear-gradient(180deg, #fffbeb, #fffdf4);
  padding: 12px 14px; border-radius: 12px;
  border-left: 4px solid #f59e0b;
  border: 1px solid #fde68a; border-left-width: 4px;
  font-size: 12.5px; color: #78350f;
}
.tips b { color: #92400e; font-weight: 700; }
.muted { color: #6b7280; } .small { font-size: 12px; }
.link { color: #2563eb; margin: 0 2px; font-weight: 600; }
.link:hover { text-decoration: underline; }
.mt-8 { margin-top: 8px; } .mt-12 { margin-top: 12px; } .mt-18 { margin-top: 18px; }
.ok { color: #059669; font-weight: 700; }

/* mini cs drawer */
.cs-mini { display: flex; flex-direction: column; gap: 14px; }
.cs-item {
  display: flex; align-items: center; gap: 10px; padding: 14px 16px;
  border: 1px solid #eef0f4; border-radius: 14px; font-size: 14px; background: #fafbfc;
  transition: all .2s;
}
.cs-item:hover {
  border-color: #10b981; background: #ecfdf5; transform: translateY(-1px);
}
.cs-item .el-icon {
  color: #10b981; font-size: 18px; width: 32px; height: 32px; border-radius: 10px;
  background: linear-gradient(135deg, #ecfdf5, #d1fae5);
  display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cs-item b { margin-left: 4px; color: #111827; font-weight: 700; }
.cs-item .el-button { margin-left: auto; border-radius: 10px; font-weight: 600; }

.float-help-btn {
  position: fixed; right: 26px; bottom: 140px; z-index: 100;
  width: 60px; height: 60px; border-radius: 50% !important; padding: 0 !important;
  box-shadow: 0 10px 26px rgba(16,185,129,0.5), 0 4px 10px rgba(4,120,87,.3);
  background: linear-gradient(135deg,#10b981,#059669 60%,#047857) !important; border: none !important;
  transition: all .25s cubic-bezier(.4,0,.2,1);
}
.float-help-btn::before {
  content: ''; position: absolute; inset: 0; border-radius: 50%;
  background: radial-gradient(circle at 30% 25%, rgba(255,255,255,.3), transparent 60%);
  pointer-events: none;
}
.float-help-btn:hover { transform: scale(1.08) rotate(-4deg); box-shadow: 0 14px 32px rgba(16,185,129,.58); }
.float-help-btn:active { transform: scale(.96); }

.tabs-header {
  display: flex; justify-content: space-between; align-items: center;
  background: #fff; padding: 0 22px; border-radius: 16px; margin-bottom: 18px;
  border: 1px solid #eef0f4;
  box-shadow: 0 1px 3px rgba(17,24,39,.03);
}
.main-tabs :deep(.el-tabs__header) { margin: 0; border: none; }
.main-tabs :deep(.el-tabs__item) {
  height: 60px; line-height: 60px; font-size: 15px; font-weight: 700; padding: 0 28px;
  color: #4b5563; transition: color .2s; letter-spacing: .2px;
}
.main-tabs :deep(.el-tabs__item:hover) { color: #10b981; }
.main-tabs :deep(.el-tabs__item.is-active) { color: #059669; font-weight: 800; }
.main-tabs :deep(.el-tabs__active-bar) {
  background: linear-gradient(90deg, #10b981, #059669); height: 3px; border-radius: 2px 2px 0 0;
}
.switch-hint { display: flex; align-items: center; gap: 10px; }

@media (max-width: 1400px) {
  .plan-grid-mini { grid-template-columns: repeat(3, 1fr); }
}
@media (max-width: 1200px) {
  .country-grid { grid-template-columns: repeat(3, 1fr); }
  .plan-grid-mini { grid-template-columns: repeat(2, 1fr); }
}
</style>
