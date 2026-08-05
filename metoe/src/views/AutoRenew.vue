<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="6"><el-card shadow="hover" class="stat-card ok">
        <div class="lbl muted small">自动续订中</div>
        <div class="val">8 台</div>
        <div class="ft">下次扣费金额 <b>¥ 4,280.00</b></div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card warn">
        <div class="lbl muted small">7 天内到期</div>
        <div class="val">3 台</div>
        <div class="ft">建议：立即开启自动续订</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card info">
        <div class="lbl muted small">已暂停 / 已过期</div>
        <div class="val">2 台</div>
        <div class="ft">已释放公网 IP · 数据保留7天</div>
      </el-card></el-col>
      <el-col :span="6"><el-card shadow="hover" class="stat-card good">
        <div class="lbl muted small">续订累计节省</div>
        <div class="val">¥ 3,160.50</div>
        <div class="ft">自动续订专属 <b>95 折</b> 优惠</div>
      </el-card></el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <div class="left">
            <b>我的云服务器 · 续订管理</b>
            <el-tag type="info" effect="light" round size="small" style="margin-left: 10px;">共 {{ total }} 台</el-tag>
          </div>
          <div class="right">
            <el-input v-model="kw" size="default" placeholder="搜索实例名 / IP" clearable style="width: 240px;">
              <template #prefix><el-icon><Search /></el-icon></template>
            </el-input>
            <el-select v-model="filter" size="default" clearable placeholder="筛选状态" style="width: 160px; margin-left: 10px;">
              <el-option label="自动续订开" value="on" />
              <el-option label="自动续订关" value="off" />
              <el-option label="7天内到期" value="expiring" />
              <el-option label="已过期暂停" value="expired" />
            </el-select>
            <el-button type="warning" plain :icon="BellFilled" style="margin-left: 10px;">批量开通提醒</el-button>
            <el-button type="success" :icon="RefreshRight">批量开启续订</el-button>
          </div>
        </div>
      </template>

      <el-alert
        title="🎉 自动续订福利：开启后到期前3小时自动扣余额，享 95 折优惠；余额不足自动跳过，不影响其他实例。"
        type="success" :closable="false" show-icon style="margin-bottom: 16px;"
      />

      <el-table :data="rows" stripe style="width: 100%;">
        <el-table-column label="服务器信息" min-width="320">
          <template #default="{ row }">
            <div class="srv-row">
              <div class="srv-logo" :style="{ background: row.bg }">
                <el-icon :size="22" color="#fff"><Cpu /></el-icon>
              </div>
              <div class="srv-info">
                <div class="srv-name">
                  <b>{{ row.name }}</b>
                  <el-tag v-if="row.tag" size="small" type="success" effect="light" style="margin-left: 6px;">{{ row.tag }}</el-tag>
                </div>
                <div class="srv-spec muted small">{{ row.cpu }} vCPU · {{ row.ram }}GB · {{ row.bw }}Mbps · {{ row.region }}</div>
                <div class="srv-ip mono">{{ row.ip }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="周期" width="110" align="center">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ row.period }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="到期时间" width="180" align="center">
          <template #default="{ row }">
            <div :class="{ danger: row.daysLeft <= 3 }">
              <div>{{ row.expireAt }}</div>
              <div class="muted small">剩余 <b :class="{ red: row.daysLeft <= 3, ok: row.daysLeft > 14 }">{{ row.daysLeft }} 天</b></div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="续订单价" width="130" align="right">
          <template #default="{ row }">
            <div>
              <div>¥ {{ row.price }}</div>
              <div class="muted small">自动续订 <span class="discount">95折 ¥ {{ Math.round(parseFloat(row.price) * 0.95) }}</span></div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="自动续订" width="130" align="center">
          <template #default="{ row }">
            <el-switch v-model="row.auto" :active-text="'ON'" :inactive-text="'OFF'" inline-prompt />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="220" align="right" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" plain :icon="Wallet">手动续费</el-button>
            <el-dropdown size="small" style="margin-left: 6px;">
              <el-button size="small">更多<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item>续费 3 个月</el-dropdown-item>
                  <el-dropdown-item>续费 1 年 (9 折)</el-dropdown-item>
                  <el-dropdown-item>配置续费通知</el-dropdown-item>
                  <el-dropdown-item divided>查看费用明细</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager">
        <el-pagination layout="total, sizes, prev, pager, next, jumper" :total="total" background />
      </div>
    </el-card>
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { Search, BellFilled, RefreshRight, Wallet, ArrowDown, Cpu } from '@element-plus/icons-vue'

const kw = ref('')
const filter = ref('')
const total = 13
const regions = ['新加坡 SGP', '洛杉矶 LAX', '东京 NRT', '法兰克福 FRA', '伦敦 LON', '纽约 NYC', '香港 HKG']
const bgs = [
  'linear-gradient(135deg,#3b82f6,#2563eb)',
  'linear-gradient(135deg,#10b981,#059669)',
  'linear-gradient(135deg,#f59e0b,#d97706)',
  'linear-gradient(135deg,#8b5cf6,#7c3aed)',
  'linear-gradient(135deg,#ef4444,#dc2626)',
  'linear-gradient(135deg,#0ea5e9,#0284c7)',
]
function randIp() {
  return `${100 + Math.floor(Math.random() * 150)}.${Math.floor(Math.random()*255)}.${Math.floor(Math.random()*255)}.${Math.floor(Math.random()*255)}`
}
const rows = Array.from({ length: total - 3 }).map((_, i) => {
  const cpus = [1, 2, 2, 4, 4, 8, 16]
  const rams = [1, 2, 4, 4, 8, 16, 32]
  const bws = [10, 30, 50, 50, 100, 200, 500]
  const periods = ['1个月', '3个月', '6个月', '1个月', '1年']
  const ci = i % 7
  const days = (i < 2 ? i + 1 : (i < 5 ? i + 4 : i * 8 + 10))
  const prices = [59, 149, 299, 299, 699, 1599, 3199]
  return {
    name: `prod-app-${String(i + 1).padStart(2,'0')}-${regions[i%7].split(' ')[0].toLowerCase()}`,
    ip: randIp(),
    cpu: cpus[ci], ram: rams[ci], bw: bws[ci],
    region: regions[i % 7],
    period: periods[i % 5],
    price: (prices[ci]).toFixed(2),
    expireAt: new Date(Date.now() + days * 86400000).toLocaleDateString('zh-CN') + ' 12:00',
    daysLeft: days,
    auto: i < 8,
    tag: i === 0 ? '核心生产' : (i === 5 ? '数据库' : ''),
    bg: bgs[i % bgs.length]
  }
})
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.stat-card { border-radius: 14px; }
.stat-card.ok { background: linear-gradient(135deg,#ecfeff,#dbeafe); }
.stat-card.warn { background: linear-gradient(135deg,#fff7ed,#fee2e2); }
.stat-card.info { background: linear-gradient(135deg,#f3f4f6,#e5e7eb); }
.stat-card.good { background: linear-gradient(135deg,#ecfdf5,#d1fae5); }
.stat-card .lbl { margin-bottom: 6px; }
.stat-card .val { font-size: 28px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.stat-card .ft { font-size: 12px; color: #374151; margin-top: 10px; }

.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
.card-header .left, .card-header .right { display: flex; align-items: center; }

.srv-row { display: flex; align-items: center; gap: 12px; padding: 4px 0; }
.srv-logo { width: 50px; height: 50px; border-radius: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 4px 10px rgba(0,0,0,0.1); }
.srv-name { font-size: 14px; color: #111827; }
.srv-spec { margin-top: 3px; }
.srv-ip { color: #374151; margin-top: 3px; font-size: 12px; }
.danger { color: #dc2626; }
.red { color: #dc2626; }
.ok { color: #10b981; }
.discount { color: #059669; font-weight: 600; }
.pager { margin-top: 18px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
