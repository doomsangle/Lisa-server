<template>
  <div class="page-wrap">
    <el-row :gutter="16">
      <el-col :span="18">
        <el-card shadow="hover" class="search-card">
          <div class="s-row">
            <el-icon :size="22" color="#409eff"><Search /></el-icon>
            <el-input v-model="kw" size="large" placeholder="搜索：文档名称、关键词、教程、示例代码、常见问题..." />
            <el-button type="primary" size="large" :icon="Search">搜索资源</el-button>
            <el-button size="large" :icon="MagicStick" @click="$router.push('/developer')">前往 API 文档</el-button>
          </div>
          <div class="hot-tags muted small">
            <b>热门搜索：</b>
            <el-tag v-for="(t, i) in hotTags" :key="i" size="small" effect="plain" class="tag" :type="i % 2 === 0 ? 'primary' : 'success'">{{ t }}</el-tag>
          </div>
        </el-card>

        <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
          <template #header>
            <div class="card-header">
              <b>📚 资源分类</b>
              <el-radio-group v-model="catView" size="small">
                <el-radio-button value="card">卡片视图</el-radio-button>
                <el-radio-button value="list">列表视图</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div class="cat-grid">
            <div v-for="(c, i) in cats" :key="i" class="cat-card" @click="openCat(c)">
              <div class="cat-ic" :style="{ background: c.bg }"><el-icon :size="30" color="#fff"><component :is="c.icon" /></el-icon></div>
              <div class="cat-name"><b>{{ c.name }}</b></div>
              <div class="cat-cnt muted small">{{ c.count }} 篇文档 · {{ c.update }}</div>
              <div class="cat-top">
                <div v-for="(t, j) in c.hot.slice(0, 3)" :key="j" class="cat-pt muted small">
                  <span class="dot">•</span> {{ t }}
                </div>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="side-card">
          <template #header><b>🚀 新手任务引导</b></template>
          <div class="progress-row">
            <div class="p-num"><b>{{ doneTasks }}/{{ tasks.length }}</b></div>
            <el-progress :percentage="Math.round(doneTasks/tasks.length*100)" :stroke-width="10" :color="['#10b981','#0ea5e9']" />
          </div>
          <div class="task-list">
            <div v-for="(t, i) in tasks" :key="i" class="task-item" :class="{ done: t.done }" @click="doTask(t)">
              <div class="tk-box" :class="{ ok: t.done }">
                <el-icon v-if="t.done" color="#10b981"><CircleCheckFilled /></el-icon>
                <span v-else class="t-num">{{ i + 1 }}</span>
              </div>
              <div class="tk-txt">
                <div class="tk-title">{{ t.title }}</div>
                <div class="tk-sub muted small">{{ t.sub }}</div>
              </div>
              <el-icon class="tk-arrow"><ArrowRight /></el-icon>
            </div>
          </div>
        </el-card>

        <el-card shadow="hover" style="margin-top: 16px; border-radius: 14px;">
          <template #header><b>🔌 SDK & 工具下载</b></template>
          <div class="dl-list">
            <div v-for="(s, i) in sdks" :key="i" class="dl-item">
              <div class="dl-ic" :class="s.key"><el-icon :size="20"><component :is="s.icon" /></el-icon></div>
              <div class="dl-info">
                <div class="dl-name">{{ s.name }} <el-tag size="small" type="info" effect="plain">v{{ s.ver }}</el-tag></div>
                <div class="dl-mute muted small">{{ s.size }} · {{ s.date }}</div>
              </div>
              <el-button link type="primary" size="small" :icon="Download">下载</el-button>
            </div>
          </div>
        </el-card>

        <el-card shadow="hover" style="margin-top: 16px; border-radius: 14px;">
          <template #header><b>💬 社区 / 支持</b></template>
          <div class="ch-list">
            <a href="javascript:;" class="ch-item"><el-icon color="#059669"><Reading /></el-icon> 帮助中心</a>
            <a href="javascript:;" class="ch-item"><el-icon color="#409eff"><ChatLineSquare /></el-icon> 开发者社群</a>
            <a href="javascript:;" class="ch-item"><el-icon color="#f59e0b"><Tickets /></el-icon> 提交工单</a>
            <a href="javascript:;" class="ch-item"><el-icon color="#8b5cf6"><Bell /></el-icon> 订阅产品更新</a>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" style="margin-top: 16px; border-radius: 14px;">
      <template #header>
        <div class="card-header">
          <b>🔥 本周热门推荐</b>
          <el-link type="primary" :underline="false">查看全部文章 →</el-link>
        </div>
      </template>
      <el-table :data="articles" stripe style="width: 100%;">
        <el-table-column label="分类" width="120">
          <template #default="{ row }">
            <el-tag size="small" effect="plain" :type="row.tagType">{{ row.cat }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="标题" min-width="360">
          <template #default="{ row }">
            <div class="art-title">
              <el-icon color="#e6a23c" v-if="row.hot"><Promotion /></el-icon>
              <b>{{ row.title }}</b>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="author" label="作者" width="110" />
        <el-table-column label="阅读量" width="110" align="right">
          <template #default="{ row }">{{ row.views }} 👁</template>
        </el-table-column>
        <el-table-column prop="likes" label="👍" width="70" align="right" />
        <el-table-column prop="date" label="更新时间" width="170" />
        <el-table-column label="操作" width="90" align="right">
          <template #default><el-button link type="primary" size="small">阅读</el-button></template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>
<script setup>
import { ref, computed, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Search, MagicStick, CircleCheckFilled, ArrowRight, Download,
  Reading, Monitor, Notebook, Tickets, Setting, UserFilled, Promotion, Bell,
  ChatLineSquare, PictureFilled, VideoPlay, DataBoard, Box, Connection
} from '@element-plus/icons-vue'

const kw = ref('')
const catView = ref('card')
const hotTags = ['SSH连接','BGP网络','DDoS防护','自动化部署','快照备份','API密钥','重置密码','重装系统','内网组网','控制面板']
const cats = [
  { name: '新手入门指南', count: 12, update: '2026-07-19', icon: 'Reading', bg: 'linear-gradient(135deg,#10b981,#059669)', hot: ['购买您的第一台云服务器','使用 SSH 登录实例','常用 Linux 命令速查表'] },
  { name: '产品文档', count: 68, update: '2026-07-21', icon: 'Notebook', bg: 'linear-gradient(135deg,#3b82f6,#2563eb)', hot: ['实例生命周期管理','网络与安全组','块存储 / 对象存储'] },
  { name: 'API & SDK 参考', count: 42, update: '2026-07-20', icon: 'MagicStick', bg: 'linear-gradient(135deg,#8b5cf6,#7c3aed)', hot: ['认证与鉴权','实例管理 API','账单查询 API'] },
  { name: '开发者教程', count: 36, update: '2026-07-18', icon: 'Monitor', bg: 'linear-gradient(135deg,#f59e0b,#d97706)', hot: ['Docker 一键部署','WordPress 建站','K3s 轻量集群'] },
  { name: '视频培训课程', count: 18, update: '2026-07-15', icon: 'VideoPlay', bg: 'linear-gradient(135deg,#ef4444,#dc2626)', hot: ['10 分钟上手 MetoE','架构师公开课','网络安全最佳实践'] },
  { name: '最佳实践', count: 24, update: '2026-07-17', icon: 'Setting', bg: 'linear-gradient(135deg,#0ea5e9,#0284c7)', hot: ['高可用架构设计','云上容灾备份','成本优化指南'] },
  { name: '常见问题 FAQ', count: 96, update: '2026-07-21', icon: 'Tickets', bg: 'linear-gradient(135deg,#84cc16,#65a30d)', hot: ['付款后多久开通？','如何更换 IP？','7 天无理由退款'] },
  { name: '服务等级协议', count: 8, update: '2026-06-30', icon: 'UserFilled', bg: 'linear-gradient(135deg,#64748b,#475569)', hot: ['SLA 99.99% 可用性','故障赔付标准','合规与安全白皮书'] },
]
const tasks = reactive([
  { title: '完成实名认证', sub: '解锁双倍奖励 + 100 台购买额度', done: false, action: '/verify' },
  { title: '购买第一台云服务器', sub: '50 元体验全球节点', done: false, action: '/servers/buy' },
  { title: '配置 SSH 密钥登录', sub: '更安全的登录方式', done: true, action: '/policy' },
  { title: '创建第一个快照备份', sub: '数据安全的第一步', done: true, action: '/servers' },
  { title: '邀请好友注册', sub: '最高 8% 返佣', done: false, action: '/affiliate' },
  { title: '绑定微信通知', sub: '余额变动 / 到期提醒', done: false, action: '/policy' },
])
const doneTasks = computed(() => tasks.filter(t => t.done).length)
const sdks = [
  { key: 'py', name: 'Python SDK', icon: 'Box', ver: '1.8.0', size: '1.8 MB', date: '2026-07-10' },
  { key: 'js', name: 'Node.js SDK', icon: 'Connection', ver: '2.1.0', size: '920 KB', date: '2026-07-15' },
  { key: 'go', name: 'Go SDK', icon: 'DataBoard', ver: '1.5.2', size: '3.2 MB', date: '2026-07-12' },
  { key: 'cli', name: 'CLI 命令行工具', icon: 'Monitor', ver: '0.9.0', size: '18 MB', date: '2026-07-20' },
]
const articles = [
  { cat: '新手入门', tagType: 'success', title: '【图文教程】MetoE 新手上路：注册、充值、购买、登录全流程', author: 'MetoE 官方', views: '38,426', likes: 1286, date: '2026-07-20', hot: true },
  { cat: '产品文档', tagType: 'primary', title: '实例规格对比：经济型 / 标准型 / 计算型 / 高 IO 型适用场景', author: '产品团队', views: '22,188', likes: 842, date: '2026-07-19' },
  { cat: 'API 参考', tagType: 'info', title: '新版 v2 API 正式上线：支持批量创建 + 异步回调 + 标签', author: 'API 组', views: '15,036', likes: 624, date: '2026-07-18', hot: true },
  { cat: '最佳实践', tagType: 'warning', title: '高可用架构实战：3 节点 + 负载均衡 + 读写分离部署指南', author: '架构师 Ada', views: '11,280', likes: 512, date: '2026-07-16' },
  { cat: '常见问题', tagType: 'danger', title: 'FAQ 汇总：SSH 连接不上 / 网络慢 / 重置密码 / 退款条件', author: '客服团队', views: '68,924', likes: 2308, date: '2026-07-21', hot: true },
]

function openCat(c) { ElMessage.info(`打开【${c.name}】分类（示例）`) }
function doTask(t) {
  if (!t.done) {
    t.done = true
    ElMessage.success(`已完成"${t.title}"，积分 +10`)
  } else ElMessage.info('已完成该任务')
}
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.search-card, .side-card { border-radius: 14px; }
.s-row { display: flex; align-items: center; gap: 10px; }
.s-row .el-input { flex: 1; }
.hot-tags { margin-top: 14px; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.tag { cursor: pointer; }

.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.cat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px; }
.cat-card {
  padding: 18px;
  border-radius: 14px;
  background: #fff;
  border: 1px solid #eef0f3;
  cursor: pointer;
  transition: all .2s ease;
}
.cat-card:hover { transform: translateY(-3px); box-shadow: 0 14px 26px rgba(0,0,0,0.08); border-color: #409eff; }
.cat-ic {
  width: 60px; height: 60px; border-radius: 14px; display: flex; align-items: center; justify-content: center;
  margin-bottom: 12px; box-shadow: 0 8px 16px rgba(0,0,0,0.1);
}
.cat-name { font-size: 16px; color: #111827; margin-bottom: 4px; }
.cat-cnt { margin-bottom: 10px; }
.cat-top { display: flex; flex-direction: column; gap: 5px; }
.cat-pt { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cat-pt .dot { color: #10b981; margin-right: 4px; }

.progress-row { display: flex; align-items: center; gap: 14px; margin-bottom: 14px; }
.p-num { font-size: 20px; color: #111827; min-width: 56px; }
.task-list { display: flex; flex-direction: column; gap: 10px; }
.task-item {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 12px; border-radius: 10px;
  background: #fafbfc; cursor: pointer;
  transition: all .18s ease;
}
.task-item:hover { background: #eff6ff; }
.task-item.done { opacity: 0.96; }
.tk-box {
  width: 28px; height: 28px; border-radius: 8px;
  background: #e5e7eb; color: #374151;
  display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 13px;
  flex-shrink: 0;
}
.tk-box.ok { background: #d1fae5; }
.tk-txt { flex: 1; min-width: 0; }
.tk-title { color: #111827; font-size: 13px; font-weight: 600; }
.tk-sub { margin-top: 3px; }
.tk-arrow { color: #9ca3af; }

.dl-list, .ch-list { display: flex; flex-direction: column; gap: 10px; }
.dl-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px; border-radius: 10px; background: #fafbfc;
}
.dl-ic {
  width: 38px; height: 38px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  color: #fff;
}
.dl-ic.py { background: linear-gradient(135deg,#f59e0b,#3b82f6); }
.dl-ic.js { background: linear-gradient(135deg,#facc15,#eab308); }
.dl-ic.go { background: linear-gradient(135deg,#0ea5e9,#0284c7); }
.dl-ic.cli { background: linear-gradient(135deg,#111827,#374151); }
.dl-info { flex: 1; }
.dl-name { font-weight: 600; color: #111827; font-size: 13px; }
.dl-mute { margin-top: 2px; }

.ch-item {
  display: flex; align-items: center; gap: 10px;
  padding: 10px 12px; border-radius: 10px;
  text-decoration: none; color: #111827;
  background: #f9fafb;
}
.ch-item:hover { background: #eff6ff; color: #2563eb; }

.art-title { display: flex; align-items: center; gap: 8px; color: #111827; font-size: 14px; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
