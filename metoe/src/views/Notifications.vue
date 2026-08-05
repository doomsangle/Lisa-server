<template>
  <div class="notify-page">
    <el-row :gutter="16">
      <el-col :span="16">
        <div class="page-card">
          <div class="card-head">
            <h3 class="section-title">
              <el-icon><Bell /></el-icon> 通知中心
              <el-tag size="small" type="danger" round v-if="unread.total > 0">
                未读 {{ unread.total }}
              </el-tag>
            </h3>
            <div class="actions">
              <el-button size="small" @click="loadNotifications(true)">
                <el-icon><Refresh /></el-icon> 刷新
              </el-button>
              <el-button size="small" type="primary" plain @click="markAllRead">
                <el-icon><CircleCheckFilled /></el-icon> 全部标记已读
              </el-button>
              <el-button size="small" type="danger" plain @click="clearRead">
                <el-icon><DeleteFilled /></el-icon> 清空已读
              </el-button>
            </div>
          </div>

          <div class="tabs">
            <el-radio-group v-model="typeFilter" size="small" @change="loadNotifications">
              <el-radio-button value="">全部</el-radio-button>
              <el-radio-button v-for="(t,k) in typeMap" :key="k" :value="k">
                {{ t.label }}
                <el-badge v-if="unread.byType?.[k]" :value="unread.byType[k]" class="type-badge" :max="99" />
              </el-radio-button>
            </el-radio-group>
            <el-radio-group v-model="readFilter" size="small" style="margin-left:12px" @change="loadNotifications">
              <el-radio-button value="">全部状态</el-radio-button>
              <el-radio-button value="0">未读</el-radio-button>
              <el-radio-button value="1">已读</el-radio-button>
            </el-radio-group>
          </div>

          <div class="notify-list" v-loading="loading">
            <div v-for="n in list" :key="n.id"
              class="notify-item"
              :class="[n.level, {unread: !n.isRead}]"
              @click="handleItemClick(n)">
              <div class="notify-icon" :class="n.level">
                <el-icon :size="20"><component :is="iconOf(n.type)" /></el-icon>
              </div>
              <div class="notify-body">
                <div class="notify-head">
                  <el-tag size="small" :type="levelTag(n.level)" effect="light">
                    {{ n.levelLabel }}
                  </el-tag>
                  <el-tag size="small" effect="plain">{{ n.typeLabel }}</el-tag>
                  <b class="notify-title">{{ n.title }}</b>
                  <span class="muted small">{{ n.createdAt }}</span>
                </div>
                <div class="notify-content">{{ n.content }}</div>
              </div>
              <div class="notify-actions">
                <el-button v-if="!n.isRead" link size="small" type="primary" @click.stop="markOneRead(n)">
                  标记已读
                </el-button>
                <el-popconfirm title="确认删除该通知？" @confirm="removeOne(n)">
                  <template #reference>
                    <el-button link size="small" type="danger" @click.stop>
                      <el-icon><Delete /></el-icon>
                    </el-button>
                  </template>
                </el-popconfirm>
              </div>
            </div>
            <el-empty v-if="!loading && !list.length" :image-size="120"
              description="暂无通知，一切正常运行中 👍" />
          </div>

          <el-pagination
            v-if="total > 0"
            class="mt-16"
            background
            layout="total, prev, pager, next, jumper"
            :total="total"
            :current-page="page"
            :page-size="pageSize"
            @current-change="(p) => { page = p; loadNotifications() }"
          />
        </div>
      </el-col>

      <el-col :span="8">
        <div class="page-card">
          <h3 class="section-title"><el-icon><DataBoard /></el-icon> 通知概览</h3>
          <div class="stat-grid">
            <div class="stat-item">
              <div class="label">全部通知</div>
              <div class="value">{{ total || '0' }}</div>
            </div>
            <div class="stat-item warn">
              <div class="label">未读消息</div>
              <div class="value">{{ unread.total || '0' }}</div>
            </div>
            <div class="stat-item">
              <div class="label">类型数</div>
              <div class="value">{{ Object.keys(unread.byType || {}).length || '0' }}</div>
            </div>
            <div class="stat-item">
              <div class="label">最近7天</div>
              <div class="value">{{ last7Count || '0' }}</div>
            </div>
          </div>

          <el-divider />
          <h4 class="sub-title"><el-icon><InfoFilled /></el-icon> 通知类型说明</h4>
          <ul class="type-desc">
            <li v-for="(t,k) in typeMap" :key="k">
              <span class="dot" :style="{background: t.color}"></span>
              <b>{{ t.label }}</b>：{{ t.desc }}
            </li>
          </ul>
        </div>

        <div class="page-card mt-16">
          <h3 class="section-title"><el-icon><Reading /></el-icon> 常见问题</h3>
          <div class="faq">
            <el-collapse>
              <el-collapse-item title="如何关闭邮件/短信提醒？" name="1">
                前往「个人中心 → 通知设置」自定义各渠道的推送开关，系统公告类通知将继续保留。
              </el-collapse-item>
              <el-collapse-item title="订单支付成功为何没有通知？" name="2">
                若支付为异步回调（USDT 等），会在链上确认后推送通知；可到「充值订单」页查看最新状态。
              </el-collapse-item>
              <el-collapse-item title="工单回复通知会推送到哪里？" name="3">
                工单客服回复时，站内信、邮箱（未读>3条时）都会推送通知；您也可以在个人中心关闭邮箱推送。
              </el-collapse-item>
            </el-collapse>
          </div>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { reactive, ref, onMounted, computed } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Bell, Refresh, CircleCheckFilled, DeleteFilled, Delete, DataBoard,
  InfoFilled, Reading, Message, Wallet, Monitor, Tickets,
  Present, Lock, Operation, Setting
} from '@element-plus/icons-vue'
import { useRouter } from 'vue-router'
import {
  getNotificationList, getNotificationUnreadCount,
  markNotificationRead, markAllNotificationsRead,
  deleteNotification, clearReadNotifications
} from '@/api/notifications'

const router = useRouter()
const loading = ref(false)
const list = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const typeFilter = ref('')
const readFilter = ref('')
const unread = reactive({ total: 0, byType: {} })

const typeMap = {
  system:   { label: '系统公告', color: '#909399', desc: '平台维护、活动公告、政策更新' },
  wallet:   { label: '钱包变动', color: '#e6a23c', desc: '充值到账、扣费、退款、资金划转' },
  order:    { label: '订单状态', color: '#409eff', desc: '云服务器下单、支付成功、发货' },
  server:   { label: '云服务器', color: '#67c23a', desc: '开机、关机、重装、到期提醒' },
  feedback: { label: '工单反馈', color: '#f56c6c', desc: '新工单、客服回复、状态变更' },
  coupon:   { label: '优惠券',   color: '#8e44ad', desc: '发券、过期、兑换成功' },
  security: { label: '安全',     color: '#e74c3c', desc: '密码修改、异地登录、API Key重置' },
  deploy:   { label: '部署',     color: '#16a085', desc: '云服务器部署进度、结果回调' },
}

const iconOf = (t) => ({
  system: Setting, wallet: Wallet, order: Tickets, server: Monitor,
  feedback: Message, coupon: Present, security: Lock, deploy: Operation
})[t] || Bell

const levelTag = (lv) => ({
  info: 'info', success: 'success', warning: 'warning', error: 'danger'
})[lv] || 'info'

const last7Count = computed(() => {
  const now = Date.now()
  return list.value.filter(n => {
    const t = new Date(n.createdAt?.replace(/-/g, '/')).getTime()
    return t && now - t <= 7 * 86400000
  }).length
})

async function loadNotifications(force) {
  loading.value = true
  try {
    const params = { page: page.value, page_size: pageSize.value }
    if (typeFilter.value) params.type = typeFilter.value
    if (readFilter.value !== '') params.is_read = readFilter.value
    const r = await getNotificationList(params)
    if (r?.code !== 0) throw new Error(r?.message || '加载失败')
    list.value = r.data?.list || []
    total.value = r.data?.total || 0
  } catch (e) {
    ElMessage.error(e?.message || '加载通知失败')
  } finally {
    loading.value = false
  }
  if (force) await loadUnreadCount()
}

async function loadUnreadCount() {
  try {
    const r = await getNotificationUnreadCount()
    if (r?.code === 0) {
      unread.total = r.data?.total || 0
      unread.byType = r.data?.byType || {}
    }
  } catch {}
}

async function markOneRead(n) {
  try {
    const r = await markNotificationRead(n.id)
    if (r?.code !== 0) throw new Error(r?.message || '操作失败')
    n.isRead = true
    unread.total = Math.max(0, unread.total - 1)
    if (unread.byType?.[n.type]) unread.byType[n.type] -= 1
  } catch (e) {
    ElMessage.error(e.message || '操作失败')
  }
}

async function markAllRead() {
  try {
    const r = await markAllNotificationsRead(typeFilter.value || undefined)
    if (r?.code !== 0) throw new Error(r?.message || '操作失败')
    ElMessage.success(r.message || `已标记 ${r.data?.changed || 0} 条为已读`)
    list.value.forEach(n => n.isRead = true)
    unread.total = 0
    Object.keys(unread.byType).forEach(k => unread.byType[k] = 0)
  } catch (e) {
    ElMessage.error(e.message || '操作失败')
  }
}

async function removeOne(n) {
  try {
    const r = await deleteNotification(n.id)
    if (r?.code !== 0) throw new Error(r?.message || '删除失败')
    list.value = list.value.filter(x => x.id !== n.id)
    total.value = Math.max(0, total.value - 1)
    if (!n.isRead) unread.total = Math.max(0, unread.total - 1)
    ElMessage.success('已删除')
  } catch (e) {
    ElMessage.error(e.message || '删除失败')
  }
}

async function clearRead() {
  try {
    const r = await clearReadNotifications()
    if (r?.code !== 0) throw new Error(r?.message || '操作失败')
    ElMessage.success(r.message || `已清空 ${r.data?.changed || 0} 条已读`)
    await loadNotifications()
  } catch (e) {
    ElMessage.error(e.message || '操作失败')
  }
}

function handleItemClick(n) {
  if (!n.isRead) markOneRead(n)
  const jump = {
    order:    '/orders',
    wallet:   '/billing',
    feedback: '/feedback',
    coupon:   '/coupons',
    server:   '/servers',
    security: '/profile',
  }[n.type]
  if (jump) router.push(jump)
}

onMounted(async () => {
  await loadNotifications()
  await loadUnreadCount()
})
</script>

<style scoped>
.notify-page { }
.card-head { display: flex; align-items: center; justify-content: space-between; }
.section-title { display: flex; align-items: center; gap: 8px; margin: 0 0 16px; font-size: 16px; }
.sub-title { display: flex; align-items: center; gap: 6px; margin: 0 0 12px; font-size: 14px; font-weight: 600; }
.muted { color: #6b7280; } .small { font-size: 12px; }
.mt-16 { margin-top: 16px; }
.actions { display: flex; gap: 8px; }
.tabs { margin: 8px 0 16px; display: flex; align-items: center; flex-wrap: wrap; }
.type-badge { margin-left: 6px; }

.notify-list { display: flex; flex-direction: column; gap: 10px; min-height: 200px; }
.notify-item {
  display: flex; gap: 12px; padding: 12px 14px;
  border: 1px solid #ebeef5; border-radius: 10px;
  background: #fff; cursor: pointer; transition: all 0.2s;
  align-items: flex-start;
}
.notify-item.unread {
  background: linear-gradient(90deg, rgba(64,158,255,0.05) 0%, #fff 60%);
  border-color: #c6e2ff;
}
.notify-item:hover { border-color: #409eff; box-shadow: 0 4px 12px rgba(64,158,255,0.08); }
.notify-icon {
  width: 40px; height: 40px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  color: #fff;
}
.notify-icon.info { background: #909399; }
.notify-icon.success { background: #67c23a; }
.notify-icon.warning { background: #e6a23c; }
.notify-icon.error { background: #f56c6c; }
.notify-body { flex: 1; min-width: 0; }
.notify-head {
  display: flex; align-items: center; gap: 8px; margin-bottom: 6px; flex-wrap: wrap;
}
.notify-head .muted { margin-left: auto; }
.notify-title { font-weight: 600; }
.notify-content { color: #303133; line-height: 1.6; }
.notify-actions { flex-shrink: 0; display: flex; flex-direction: column; gap: 4px; align-items: flex-end; }

.stat-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.stat-item {
  background: #f5f7fa; padding: 14px 12px; border-radius: 10px;
  border: 1px solid #ebeef5;
}
.stat-item.warn { background: #fdf6ec; border-color: #faecd8; }
.stat-item .label { color: #6b7280; font-size: 13px; }
.stat-item .value { font-size: 26px; font-weight: 700; margin-top: 4px; }
.type-desc { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
.type-desc li { display: flex; align-items: flex-start; gap: 10px; font-size: 13px; }
.type-desc .dot { width: 8px; height: 8px; border-radius: 50%; margin-top: 6px; flex-shrink: 0; }
</style>
