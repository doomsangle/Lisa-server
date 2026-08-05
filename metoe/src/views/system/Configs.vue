<template>
  <div class="configs-page">
    <div class="page-header">
      <div>
        <h3 class="section-title"><el-icon><Setting /></el-icon> 全局系统配置</h3>
        <p class="muted small">所有站点级配置，仅 <el-tag size="small" type="danger">超级管理员</el-tag> 可修改；其他登录用户（admin/support/finance 等）仅可查看。</p>
      </div>
      <div class="header-actions">
        <el-button size="default" @click="loadConfigs"><el-icon><Refresh /></el-icon> 重新加载</el-button>
        <el-button type="primary" size="default" :disabled="!canEdit" :loading="saving" @click="save">
          <el-icon><CircleCheckFilled /></el-icon> 保存全部变更
        </el-button>
      </div>
    </div>

    <el-tabs v-model="activeTab" class="configs-tabs" type="border-card">
      <el-tab-pane label="站点与客服" name="site">
        <el-form :model="form" :disabled="!canEdit" label-width="160px" label-position="right">
          <el-row :gutter="20">
            <el-col :span="12">
              <el-form-item label="站点名称">
                <el-input v-model="form.site_name" placeholder="MetoE 全球云服务器平台" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="客服工作时间">
                <el-input v-model="form.cs_work_time" placeholder="周一至周日 09:00-23:00" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="微信号">
                <el-input v-model="form.cs_wechat" placeholder="客服微信号" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="微信二维码URL">
                <el-input v-model="form.cs_wechat_qr" placeholder="图片URL，留空显示默认占位" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="用户群/频道链接">
                <el-input v-model="form.cs_group_invite" placeholder="https://t.me/..." />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="QQ号">
                <el-input v-model="form.cs_qq" placeholder="客服QQ" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="QQ二维码URL">
                <el-input v-model="form.cs_qq_qr" placeholder="图片URL" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="客服邮箱">
                <el-input v-model="form.cs_email" placeholder="support@metoe.io" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="客服电话">
                <el-input v-model="form.cs_phone" placeholder="400-xxx-xxxx" />
              </el-form-item>
            </el-col>
          </el-row>
        </el-form>
      </el-tab-pane>

      <el-tab-pane label="支付配置" name="pay">
        <el-form :model="form" :disabled="!canEdit" label-width="160px" label-position="right">
          <h4 class="group-title"><el-icon><CreditCard /></el-icon> 支付渠道开关（1=开启，0=关闭）</h4>
          <el-row :gutter="20">
            <el-col :span="6">
              <el-form-item label="模拟支付">
                <el-switch v-model="form.payment_mock_enabled" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="支付宝">
                <el-switch v-model="form.payment_alipay_enabled" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="微信支付">
                <el-switch v-model="form.payment_wechat_enabled" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="USDT">
                <el-switch v-model="form.payment_usdt_enabled" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
            <el-col :span="6">
              <el-form-item label="PayPal">
                <el-switch v-model="form.payment_paypal_enabled" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
          </el-row>

          <el-divider />
          <h4 class="group-title"><el-icon><Coin /></el-icon> USDT (TRC20 默认)</h4>
          <el-row :gutter="20">
            <el-col :span="8">
              <el-form-item label="网络类型">
                <el-select v-model="form.usdt_network">
                  <el-option label="TRC20 (推荐，转账0手续费)" value="TRC20" />
                  <el-option label="ERC20 (以太坊)" value="ERC20" />
                  <el-option label="BEP20 (币安链)" value="BEP20" />
                </el-select>
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="最小确认数">
                <el-input-number v-model.number="form.usdt_min_confirm_num" :min="0" :max="20" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="订单有效期(分)">
                <el-input-number v-model.number="form.usdt_order_expire_min_num" :min="5" :max="1440" />
              </el-form-item>
            </el-col>
            <el-col :span="24">
              <el-form-item label="收款钱包地址">
                <el-input v-model="form.usdt_wallet_address" placeholder="TRC20 钱包地址，用户扫码转账到此地址" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="汇率来源">
                <el-input v-model="form.usdt_rate_source" placeholder="coinbase / binance" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="CNY/USD 参考汇率">
                <el-input-number v-model.number="form.usdt_cny_usd_rate_num" :precision="4" :step="0.01" :min="1" />
              </el-form-item>
            </el-col>
          </el-row>

          <el-divider />
          <h4 class="group-title"><el-icon><Wallet /></el-icon> PayPal</h4>
          <el-row :gutter="20">
            <el-col :span="8">
              <el-form-item label="运行模式">
                <el-select v-model="form.paypal_mode">
                  <el-option label="sandbox 沙盒测试" value="sandbox" />
                  <el-option label="live 正式生产" value="live" />
                </el-select>
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Client ID">
                <el-input v-model="form.paypal_client_id" show-password placeholder="AW-..." />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Secret">
                <el-input v-model="form.paypal_secret" show-password placeholder="EK-..." />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="结算币种">
                <el-input v-model="form.paypal_currency" placeholder="USD" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="手续费率(%)">
                <el-input-number v-model.number="form.paypal_fee_rate_num" :precision="4" :step="0.001" :min="0" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="固定手续费(USD)">
                <el-input-number v-model.number="form.paypal_fixed_fee_usd_num" :precision="2" :step="0.01" :min="0" />
              </el-form-item>
            </el-col>
          </el-row>
        </el-form>
      </el-tab-pane>

      <el-tab-pane label="供应商与部署" name="provider">
        <el-form :model="form" :disabled="!canEdit" label-width="160px" label-position="right">
          <h4 class="group-title"><el-icon><Cpu /></el-icon> 云服务器供应商</h4>
          <el-row :gutter="20">
            <el-col :span="12">
              <el-form-item label="已启用供应商">
                <el-input v-model="form.providers_enabled" placeholder="lisa,vultr,digitalocean（逗号分隔）" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="默认下单供应商">
                <el-select v-model="form.default_provider">
                  <el-option label="Lisa 主机（模拟）" value="lisa" />
                  <el-option label="Vultr" value="vultr" />
                  <el-option label="DigitalOcean" value="digitalocean" />
                </el-select>
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="Lisa API 端点">
                <el-input v-model="form.lisa_api_endpoint" placeholder="https://api.lisa-host.com/v1" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="Lisa 默认 OS">
                <el-input v-model="form.lisa_default_os" placeholder="Ubuntu 22.04 LTS" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="Lisa API Key">
                <el-input v-model="form.lisa_api_key" show-password placeholder="sk_lisa_..." />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="Lisa API Secret">
                <el-input v-model="form.lisa_api_secret" show-password placeholder="secret_lisa_..." />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Lisa 默认规格">
                <el-input v-model="form.lisa_default_spec" placeholder="1c1g25g1t" />
              </el-form-item>
            </el-col>
          </el-row>
          <el-row :gutter="20">
            <el-col :span="12">
              <el-form-item label="Vultr API 端点">
                <el-input v-model="form.vultr_api_endpoint" placeholder="https://api.vultr.com" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="Vultr API Key">
                <el-input v-model="form.vultr_api_key" show-password placeholder="DEMO-VULTR-..." />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Vultr 默认区域">
                <el-input v-model="form.vultr_default_region" placeholder="ewr" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Vultr 默认套餐">
                <el-input v-model="form.vultr_default_plan" placeholder="vc2-2c-4gb" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="Vultr 默认 OS ID">
                <el-input v-model="form.vultr_default_os_id" placeholder="1743 (Ubuntu 22.04)" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="DigitalOcean API 端点">
                <el-input v-model="form.digitalocean_api_endpoint" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="DigitalOcean Token">
                <el-input v-model="form.digitalocean_api_token" show-password />
              </el-form-item>
            </el-col>
          </el-row>

          <el-divider />
          <h4 class="group-title"><el-icon><Monitor /></el-icon> 部署与接入</h4>
          <el-row :gutter="20">
            <el-col :span="8">
              <el-form-item label="支付后自动部署">
                <el-switch v-model="form.deploy_auto_start" :active-value="'1'" :inactive-value="'0'" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="部署超时(分钟)">
                <el-input-number v-model.number="form.deploy_timeout_min_num" :min="5" :max="360" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="默认接入协议类型">
                <el-input v-model="form.vpn_default_type" placeholder="wg-access / sb-access（节点接入协议，勿用敏感词命名）" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="部署输出目录（本地）">
                <el-input v-model="form.vpn_output_root" placeholder="./data/output（可留空自动）" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="初始化部署脚本路径">
                <el-input v-model="form.vpn_shell_path" placeholder="/opt/s-box/deploy-init.sh" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="节点默认类型">
                <el-input v-model="form.node_default_type" placeholder="wg-access（节点默认接入方式）" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="入口 Nginx 端口">
                <el-input-number v-model.number="form.node_nginx_port_num" :min="1" :max="65535" />
              </el-form-item>
            </el-col>
            <el-col :span="8">
              <el-form-item label="节点配置根目录">
                <el-input v-model="form.node_output_root" placeholder="/etc/s-box/output" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="节点初始化脚本">
                <el-input v-model="form.node_shell_path" placeholder="/opt/s-box/deploy-init.sh" />
              </el-form-item>
            </el-col>
          </el-row>
        </el-form>
      </el-tab-pane>

      <el-tab-pane label="回调与通知" name="callback">
        <el-form :model="form" :disabled="!canEdit" label-width="160px" label-position="right">
          <h4 class="group-title"><el-icon><Bell /></el-icon> 管理后端部署回调</h4>
          <el-row :gutter="20">
            <el-col :span="24">
              <el-form-item label="回调域名">
                <el-input v-model="form.callback_api_domain" placeholder="https://admin-api.metoe.io" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="回调路径">
                <el-input v-model="form.callback_api_path" placeholder="/api/internal/deploy/notify" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="回调鉴权 Token">
                <el-input v-model="form.callback_api_token" show-password placeholder="Bearer callback_demo_token_..." />
              </el-form-item>
            </el-col>
          </el-row>
          <el-alert type="warning" :closable="false" show-icon
            title="说明：部署任务每步完成（或失败/超时）会通过该回调域名通知管理后端，便于集中监控和二次处理。" />
        </el-form>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'
import { listAllConfigs, saveConfigs } from '@/api/config'

const userStore = useUserStore()
const canEdit = computed(() => userStore.roles?.includes('super_admin'))
const activeTab = ref('site')
const loading = ref(false)
const saving = ref(false)
const rawList = ref([])

const form = reactive({})
const _keys = [
  'site_name',
  'cs_wechat','cs_wechat_qr','cs_qq','cs_qq_qr','cs_email','cs_phone','cs_work_time','cs_group_invite',
  'payment_mock_enabled','payment_alipay_enabled','payment_wechat_enabled','payment_usdt_enabled','payment_paypal_enabled',
  'paypal_mode','paypal_client_id','paypal_secret','paypal_currency','paypal_fee_rate','paypal_fixed_fee_usd',
  'usdt_network','usdt_wallet_address','usdt_cny_usd_rate','usdt_min_confirm','usdt_order_expire_min','usdt_rate_source',
  'callback_api_domain','callback_api_path','callback_api_token',
  'lisa_api_endpoint','lisa_api_key','lisa_api_secret','lisa_default_spec','lisa_default_os',
  'vultr_api_endpoint','vultr_api_key','vultr_default_region','vultr_default_plan','vultr_default_os_id',
  'digitalocean_api_endpoint','digitalocean_api_token','providers_enabled','default_provider',
  'deploy_auto_start','deploy_timeout_min','vpn_default_type','vpn_output_root','vpn_shell_path',
  'node_default_type','node_nginx_port','node_output_root','node_shell_path'
]
_keys.forEach(k => { form[k] = '' })

function _asNum(v, d=0) {
  const n = parseFloat(v)
  return isNaN(n) ? d : n
}
Object.defineProperty(form, 'usdt_min_confirm_num', {
  get() { return _asNum(form.usdt_min_confirm, 1) },
  set(v) { form.usdt_min_confirm = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'usdt_order_expire_min_num', {
  get() { return _asNum(form.usdt_order_expire_min, 30) },
  set(v) { form.usdt_order_expire_min = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'usdt_cny_usd_rate_num', {
  get() { return _asNum(form.usdt_cny_usd_rate, 7.25) },
  set(v) { form.usdt_cny_usd_rate = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'paypal_fee_rate_num', {
  get() { return _asNum(form.paypal_fee_rate, 0.044) },
  set(v) { form.paypal_fee_rate = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'paypal_fixed_fee_usd_num', {
  get() { return _asNum(form.paypal_fixed_fee_usd, 0.3) },
  set(v) { form.paypal_fixed_fee_usd = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'deploy_timeout_min_num', {
  get() { return _asNum(form.deploy_timeout_min, 30) },
  set(v) { form.deploy_timeout_min = String(v ?? '') },
  configurable: true, enumerable: true
})
Object.defineProperty(form, 'node_nginx_port_num', {
  get() { return _asNum(form.node_nginx_port, 80) },
  set(v) { form.node_nginx_port = String(v ?? '') },
  configurable: true, enumerable: true
})

async function loadConfigs() {
  loading.value = true
  try {
    const list = await listAllConfigs() || []
    rawList.value = list
    list.forEach(r => {
      if (r.key in form) form[r.key] = (r.value ?? '')
    })
  } catch (e) {
    console.warn(e)
    ElMessage.error('加载系统配置失败')
  } finally {
    loading.value = false
  }
}

async function save() {
  if (!canEdit.value) {
    ElMessage.warning('仅超级管理员可修改系统配置')
    return
  }
  saving.value = true
  try {
    const payload = {}
    _keys.forEach(k => { payload[k] = form[k] ?? '' })
    await saveConfigs(payload)
    ElMessage.success('系统配置保存成功，立即生效')
    await loadConfigs()
  } catch (e) {
    ElMessage.error('保存失败：' + (e?.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

onMounted(loadConfigs)
</script>

<style scoped>
.configs-page .page-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 18px;
}
.configs-page .page-header .header-actions { display: flex; gap: 10px; }
.configs-page .section-title { margin: 0 0 4px; }
.configs-page .group-title {
  margin: 6px 0 14px; padding-left: 8px;
  border-left: 3px solid #10b981; color: #0B1220; font-size: 15px;
}
.configs-page .configs-tabs :deep(.el-tabs__content) { padding: 18px 24px; }
.configs-page .muted { color: #6b7280; }
.configs-page .small { font-size: 12px; }
</style>
