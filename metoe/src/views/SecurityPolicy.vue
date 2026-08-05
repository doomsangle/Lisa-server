<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card class="score-card" shadow="hover">
          <div class="score-label muted small">账户安全评分</div>
          <div class="score-row">
            <div class="score-num">86</div>
            <el-tag type="success" effect="dark" round size="large">良好</el-tag>
          </div>
          <el-progress :percentage="86" :stroke-width="10" :show-text="false" color="#67c23a" />
          <div class="score-tips muted small">
            开启两步验证 +12 / 绑定支付密码 +8
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <el-icon :size="28" color="#10b981"><Lock /></el-icon>
          <div class="stat-val">已保护</div>
          <div class="stat-lbl muted small">密码强度</div>
          <el-progress :percentage="90" :stroke-width="6" :show-text="false" color="#10b98a" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <el-icon :size="28" color="#409eff"><Key /></el-icon>
          <div class="stat-val">3 个</div>
          <div class="stat-lbl muted small">活跃 API 密钥</div>
          <el-progress :percentage="60" :stroke-width="6" :show-text="false" color="#409eff" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <el-icon :size="28" color="#e6a23c"><Monitor /></el-icon>
          <div class="stat-val">5 台</div>
          <div class="stat-lbl muted small">已登录设备</div>
          <el-progress :percentage="40" :stroke-width="6" :show-text="false" color="#e6a23c" />
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="14">
        <el-card shadow="never" class="list-card">
          <template #header>
            <div class="card-header">
              <b>安全设置清单</b>
              <el-tag type="info" size="small">建议全部完成</el-tag>
            </div>
          </template>
          <el-table :data="items" style="width: 100%">
            <el-table-column label="功能" min-width="180">
              <template #default="{ row }">
                <div class="feature-item">
                  <div class="feat-icon" :style="{ background: row.bg }">
                    <el-icon :size="20" color="#fff"><component :is="row.icon" /></el-icon>
                  </div>
                  <div>
                    <div class="feat-name">{{ row.name }}</div>
                    <div class="feat-desc muted small">{{ row.desc }}</div>
                  </div>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="120" align="center">
              <template #default="{ row }">
                <el-tag v-if="row.status==='done'" type="success" effect="light" round>已完成</el-tag>
                <el-tag v-else-if="row.status==='recommend'" type="warning" effect="light" round>推荐开启</el-tag>
                <el-tag v-else type="info" effect="light" round>未开启</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="200" align="right">
              <template #default="{ row }">
                <el-button v-if="row.status==='done'" size="small">管理</el-button>
                <el-button v-else type="primary" size="small" plain>{{ row.cta }}</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="10">
        <el-card shadow="never" class="list-card">
          <template #header>
            <div class="card-header">
              <b>最近登录设备</b>
              <el-button link type="primary" size="small">查看全部</el-button>
            </div>
          </template>
          <el-timeline>
            <el-timeline-item
              v-for="(d, i) in devices" :key="i" :timestamp="d.time" placement="top"
              :color="d.current?'#67c23a':(d.risk?'#f56c6c':'#909399')"
            >
              <el-card class="device-card" :class="{ cur: d.current }" shadow="never">
                <div class="dev-row">
                  <div class="dev-info">
                    <el-icon :size="18"><component :is="d.os==='Windows'?'Monitor':'Connection'" /></el-icon>
                    <b>{{ d.os }} · {{ d.browser }}</b>
                    <el-tag v-if="d.current" size="small" type="success" effect="light">当前会话</el-tag>
                    <el-tag v-if="d.risk" size="small" type="danger" effect="light">异常地点</el-tag>
                  </div>
                  <div class="dev-ip mono">{{ d.ip }}</div>
                </div>
                <div class="dev-loc muted small">{{ d.location }}</div>
                <div class="dev-actions" v-if="!d.current">
                  <el-button size="small" type="danger" link>下线设备</el-button>
                </div>
              </el-card>
            </el-timeline-item>
          </el-timeline>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
<script setup>
import { ref, reactive } from 'vue'
import {
  Lock, Key, Monitor, Connection, Wallet, User, Avatar, CircleCheckFilled, Refresh
} from '@element-plus/icons-vue'

const items = ref([
  { name: '登录密码', desc: '建议每 90 天更换，包含字母数字符号', icon: Lock, status: 'done', cta: '修改', bg: 'linear-gradient(135deg,#10b981,#059669)' },
  { name: '两步验证 (2FA)', desc: '使用 Google Authenticator 或短信', icon: Key, status: 'recommend', cta: '立即开启', bg: 'linear-gradient(135deg,#3b82f6,#2563eb)' },
  { name: '支付资金密码', desc: '消费、提现、退款时需二次验证', icon: Wallet, status: 'recommend', cta: '立即设置', bg: 'linear-gradient(135deg,#f59e0b,#d97706)' },
  { name: 'API IP 白名单', desc: '仅允许指定 IP 调用您的 API 密钥', icon: Connection, status: 'off', cta: '配置', bg: 'linear-gradient(135deg,#8b5cf6,#7c3aed)' },
  { name: '实名认证', desc: '身份核验后解锁双倍活动奖励', icon: Avatar, status: 'recommend', cta: '去认证', bg: 'linear-gradient(135deg,#10b981,#0ea5e9)' },
  { name: '安全邮箱 / 手机', desc: '用于找回密码、接收异常告警', icon: User, status: 'done', cta: '管理', bg: 'linear-gradient(135deg,#409eff,#10b981)' },
])

const devices = reactive([
  { os: 'Windows', browser: 'Chrome 126', ip: '203.0.113.45', location: '中国 上海 电信', time: '刚刚', current: true, risk: false },
  { os: 'macOS', browser: 'Safari 17', ip: '198.51.100.12', location: '中国 北京 联通', time: '3小时前', current: false, risk: false },
  { os: 'iOS', browser: '微信内置浏览器', ip: '192.0.2.88', location: '中国 广东 深圳 移动', time: '昨天 18:42', current: false, risk: false },
  { os: 'Android', browser: 'Chrome 125', ip: '45.33.32.156', location: '美国 洛杉矶', time: '2天前 09:15', current: false, risk: true },
])
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.score-card {
  background: linear-gradient(135deg, #eff6ff, #ecfdf5);
  border: none;
  border-radius: 14px;
}
.score-label { margin-bottom: 10px; }
.score-row { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
.score-num { font-size: 42px; font-weight: 800; color: #065f46; line-height: 1; }
.score-tips { margin-top: 10px; }
.stat-card { border-radius: 14px; height: 100%; }
.stat-card :deep(.el-card__body) { display: flex; flex-direction: column; gap: 8px; }
.stat-val { font-size: 22px; font-weight: 700; color: #111827; margin-top: 4px; }
.stat-lbl { margin-bottom: 6px; }
.list-card { border-radius: 14px; }
.card-header { display: flex; justify-content: space-between; align-items: center; }
.feature-item { display: flex; align-items: center; gap: 12px; padding: 4px 0; }
.feat-icon {
  width: 44px; height: 44px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 4px 10px rgba(0,0,0,0.08);
  flex-shrink: 0;
}
.feat-name { font-weight: 600; color: #111827; }
.feat-desc { margin-top: 2px; }
.device-card {
  background: #fafbfc;
  border-radius: 10px;
  margin-bottom: 4px;
  padding: 10px 14px;
  border: 1px solid #eef0f3;
}
.device-card.cur { background: #f0fdf4; border-color: #86efac; }
.dev-row { display: flex; justify-content: space-between; align-items: center; }
.dev-info { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.dev-ip { font-size: 13px; color: #374151; }
.dev-loc { margin-top: 6px; }
.dev-actions { margin-top: 6px; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
