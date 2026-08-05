<template>
  <div class="feedback-page">
    <el-row :gutter="16">
      <el-col :span="14">
        <div class="page-card">
          <h3 class="section-title"><el-icon><ChatLineSquare /></el-icon> 提交反馈 / 工单</h3>
          <el-form ref="formRef" :model="form" :rules="rules" label-width="100px">
            <el-form-item label="类型" prop="type">
              <el-radio-group v-model="form.type">
                <el-radio value="bug">问题反馈</el-radio>
                <el-radio value="feature">功能建议</el-radio>
                <el-radio value="consult">使用咨询</el-radio>
                <el-radio value="bill">账单/充值</el-radio>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="紧急度" prop="priority">
              <el-radio-group v-model="form.priority">
                <el-radio value="low">低</el-radio>
                <el-radio value="normal">普通</el-radio>
                <el-radio value="high">高</el-radio>
                <el-radio value="urgent">紧急</el-radio>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="关联资源 ID">
              <el-input v-model="form.refId" placeholder="选填，节点ID / 服务器ID / 订单号" />
            </el-form-item>
            <el-form-item label="标题" prop="title">
              <el-input v-model="form.title" placeholder="用一句话概括问题" maxlength="80" show-word-limit />
            </el-form-item>
            <el-form-item label="详细描述" prop="content">
              <el-input v-model="form.content" type="textarea" :rows="6"
                placeholder="请详细描述遇到的问题、期望结果、复现步骤，可附截图链接。" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="submitting" @click="submit">
                <el-icon><Promotion /></el-icon> 提交工单
              </el-button>
              <el-button @click="resetForm">清空</el-button>
            </el-form-item>
          </el-form>
        </div>
      </el-col>

      <el-col :span="10">
        <div class="page-card">
          <h3 class="section-title">
            <el-icon><Tickets /></el-icon> 我的工单
            <el-button link size="small" style="margin-left:auto" @click="loadTickets(true)">
              <el-icon><Refresh /></el-icon> 刷新
            </el-button>
          </h3>
          <div class="tab-wrap">
            <el-radio-group v-model="statusFilter" size="small" @change="loadTickets">
              <el-radio-button value="all">全部</el-radio-button>
              <el-radio-button value="open">处理中</el-radio-button>
              <el-radio-button value="replied">已回复</el-radio-button>
              <el-radio-button value="closed">已关闭</el-radio-button>
            </el-radio-group>
          </div>
          <div class="ticket-list" v-loading="loadingList">
            <div v-for="t in tickets" :key="t.id" class="ticket-card" @click="openTicket(t)">
              <div class="ticket-head">
                <el-tag size="small" :type="tagType(t.type)">{{ t.typeLabel || typeName(t.type) }}</el-tag>
                <el-tag size="small" :type="t.status==='closed'?'info':(t.status==='open'?'warning':'success')" effect="light">
                  {{ statusName(t.status) }}
                </el-tag>
                <span class="muted small">#{{ t.ticketNo || t.id }}</span>
              </div>
              <div class="ticket-title">{{ t.title }}</div>
              <div class="ticket-foot muted small">
                <span>{{ t.ts || t.createdAt }}</span>
                <span v-if="t.unread" class="unread-dot">{{ t.unread }} 条新回复</span>
                <span v-else-if="t.replyCount" class="reply-count">共 {{ t.replyCount }} 条对话</span>
              </div>
            </div>
            <el-empty v-if="!loadingList && !tickets.length" description="暂无工单，先提交一个吧" :image-size="100" />
          </div>
        </div>
      </el-col>
    </el-row>

    <el-drawer v-model="drawerVisible" :title="`工单详情 - ${detail?.ticketNo || ''}`" direction="rtl" size="680px" destroy-on-close>
      <div v-if="detail" class="tk-detail">
        <div class="tk-meta row-gap">
          <div><b>标题：</b>{{ detail.title }}</div>
          <div class="row">
            <el-tag size="small" :type="tagType(detail.type)">{{ detail.typeLabel || typeName(detail.type) }}</el-tag>
            <el-tag size="small" :type="detail.status==='closed'?'info':(detail.status==='open'?'warning':'success')" effect="plain">
              {{ statusName(detail.status) }}
            </el-tag>
            <el-tag size="small" effect="dark" :type="priorityColor(detail.priority)">{{ priorityName(detail.priority) }}</el-tag>
            <span class="muted small" v-if="detail.refId">关联资源：{{ detail.refId }}</span>
            <span class="muted small">创建于 {{ detail.createdAt }}</span>
          </div>
        </div>

        <el-divider content-position="left">沟通记录 ({{ detail.replies?.length || 0 }})</el-divider>

        <div class="reply-stream">
          <div v-for="r in detail.replies" :key="r.id" class="reply-item" :class="[r.role, {internal: r.isInternal}]">
            <div class="reply-avatar" :class="r.role">
              {{ (r.username || r.roleLabel || 'U').charAt(0).toUpperCase() }}
            </div>
            <div class="reply-body">
              <div class="reply-head">
                <span class="reply-name">{{ r.username || r.roleLabel }}</span>
                <el-tag size="small" v-if="r.role==='admin'" type="danger">管理员</el-tag>
                <el-tag size="small" v-else-if="r.role==='support'" type="primary">客服</el-tag>
                <el-tag size="small" v-else type="success" effect="plain">我</el-tag>
                <el-tag size="small" v-if="r.isInternal" type="warning" effect="dark">内部备注</el-tag>
                <span class="muted small reply-time">{{ r.ts || r.createdAt }}</span>
              </div>
              <div class="reply-content" style="white-space: pre-wrap;">{{ r.content }}</div>
              <div v-if="r.attachments" class="muted small mt-4">附件：{{ r.attachments }}</div>
            </div>
          </div>
        </div>

        <el-divider />

        <div v-if="detail.status !== 'closed'">
          <el-form :model="replyForm" label-position="top">
            <el-form-item label="补充回复">
              <el-input v-model="replyForm.content" type="textarea" :rows="4"
                placeholder="请输入您的补充说明或回复内容..." maxlength="3000" show-word-limit />
            </el-form-item>
            <div class="row" style="justify-content: space-between;">
              <div>
                <el-checkbox v-model="closeAfterReply" v-if="isMyTicket">回复后关闭工单</el-checkbox>
              </div>
              <div>
                <el-button @click="drawerVisible=false">取消</el-button>
                <el-button type="primary" :loading="replying" @click="submitReply">
                  <el-icon><Promotion /></el-icon> 发送回复
                </el-button>
                <el-button type="info" plain v-if="isMyTicket && detail.status!=='closed'" @click="closeTicket">
                  关闭工单
                </el-button>
              </div>
            </div>
          </el-form>
        </div>
        <el-alert v-else type="info" :closable="false" show-icon title="此工单已关闭，如有新问题请重新提交。" />
      </div>
    </el-drawer>
  </div>
</template>

<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  ChatLineSquare, Plus, Promotion, Tickets, Refresh
} from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import {
  getFeedbackList, createFeedback, getFeedbackDetail,
  replyFeedback, updateFeedbackStatus
} from '@/api/feedback'

const userStore = useUserStore()
const formRef = ref(null)
const submitting = ref(false)
const loadingList = ref(false)
const replying = ref(false)
const defaultForm = () => ({
  type: 'bug', priority: 'normal', title: '', content: '', refId: '',
  files: []
})
const form = reactive(defaultForm())
const rules = {
  type: [{ required: true, message: '请选择类型' }],
  priority: [{ required: true, message: '请选择紧急度' }],
  title: [{ required: true, min: 5, message: '标题至少5个字' }],
  content: [{ required: true, min: 10, message: '请提供详细描述（至少10字）' }]
}

const tickets = ref([])
const statusFilter = ref('all')
const detail = ref(null)
const drawerVisible = ref(false)
const replyForm = reactive({ content: '' })
const closeAfterReply = ref(false)

const isMyTicket = computed(() => {
  const uid = userStore.userInfo?.id
  return detail.value?.userId === uid || !userStore.hasPermission('feedback:manage')
})

const typeMap = { bug: '问题反馈', feature: '功能建议', consult: '使用咨询', bill: '账单问题' }
const tagType = (t) => ({ bug: 'danger', feature: 'warning', consult: undefined, bill: 'success' })[t]
const typeName = (t) => typeMap[t] || t
const statusName = (s) => ({ open: '处理中', processing: '处理中', replied: '已回复', closed: '已关闭' })[s] || s
const priorityName = (p) => ({ low: '低', normal: '普通', high: '高', urgent: '紧急' })[p] || p
const priorityColor = (p) => ({ low: 'info', normal: undefined, high: 'warning', urgent: 'danger' })[p] || undefined

async function loadTickets(force) {
  loadingList.value = true
  try {
    const params = { page: 1, pageSize: 50 }
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    const r = await getFeedbackList(params)
    tickets.value = (r?.list || []).filter(t => !force ? true : true)
  } catch (e) {
    ElMessage.error(e?.message || '加载工单列表失败')
  } finally {
    loadingList.value = false
  }
}

async function submit() {
  await formRef.value.validate()
  submitting.value = true
  try {
    const r = await createFeedback({
      type: form.type, priority: form.priority,
      title: form.title.trim(), content: form.content.trim(),
      refId: form.refId?.trim() || undefined,
    })
    if (r?.code !== 0) throw new Error(r?.message || '提交失败')
    ElMessage.success(`工单提交成功，工单号：${r.data.ticketNo}。我们会在1个工作日内处理。`)
    resetForm()
    await loadTickets(true)
  } catch (e) {
    ElMessage.error(e.message || '提交失败，请稍后重试')
  } finally {
    submitting.value = false
  }
}

function resetForm() { Object.assign(form, defaultForm()) }

async function openTicket(t) {
  try {
    const r = await getFeedbackDetail(t.id)
    if (r?.code !== 0) throw new Error(r?.message || '加载详情失败')
    detail.value = r.data
    drawerVisible.value = true
    replyForm.content = ''
    closeAfterReply.value = false
    await loadTickets()
  } catch (e) {
    ElMessage.error(e.message || '加载详情失败')
  }
}

async function submitReply() {
  if (!replyForm.content?.trim() || replyForm.content.trim().length < 2) {
    ElMessage.warning('请输入至少 2 个字符的回复内容')
    return
  }
  if (!detail.value) return
  replying.value = true
  try {
    const r = await replyFeedback(detail.value.id, { content: replyForm.content.trim() })
    if (r?.code !== 0) throw new Error(r?.message || '回复失败')
    replyForm.content = ''
    ElMessage.success('回复已发送')
    const id = detail.value.id
    const dr = await getFeedbackDetail(id)
    if (dr?.code === 0) detail.value = dr.data
    if (closeAfterReply.value) await closeTicket(true)
    await loadTickets()
  } catch (e) {
    ElMessage.error(e.message || '回复失败')
  } finally {
    replying.value = false
  }
}

async function closeTicket(silent) {
  if (!detail.value) return
  try {
    await ElMessageBox.confirm('确认关闭该工单？关闭后将无法继续回复。', '提示', { type: 'warning' })
  } catch { if (!silent) return }
  try {
    const r = await updateFeedbackStatus(detail.value.id, 'closed')
    if (r?.code !== 0) throw new Error(r?.message || '关闭失败')
    ElMessage.success('工单已关闭')
    drawerVisible.value = false
    await loadTickets()
  } catch (e) {
    ElMessage.error(e.message || '关闭失败')
  }
}

onMounted(loadTickets)
</script>

<style scoped>
.feedback-page { }
.section-title { display: flex; align-items: center; gap: 8px; margin: 0 0 16px; font-size: 16px; }
.muted { color: #6b7280; }
.small { font-size: 12px; }
.tab-wrap { margin-bottom: 12px; }
.ticket-list { display: grid; gap: 10px; min-height: 200px; }
.ticket-card {
  border: 1px solid #eef0f3; border-radius: 10px; padding: 12px 14px;
  background: #fff; cursor: pointer; transition: all 0.2s;
}
.ticket-card:hover { border-color: #409eff; box-shadow: 0 4px 12px rgba(64,158,255,0.08); }
.ticket-head { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
.ticket-head .muted { margin-left: auto; }
.ticket-title { font-weight: 500; margin-bottom: 6px; }
.ticket-foot { display: flex; align-items: center; gap: 12px; }
.unread-dot { color: #f56c6c; font-weight: 500; }
.reply-count { color: #409eff; }

.tk-detail .row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.tk-detail .row-gap { display: flex; flex-direction: column; gap: 8px; }
.row .muted { margin-left: auto; }

.reply-stream { display: flex; flex-direction: column; gap: 18px; max-height: 480px; overflow-y: auto; padding: 4px; }
.reply-item { display: flex; gap: 12px; }
.reply-avatar {
  width: 40px; height: 40px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  font-weight: 600; color: #fff;
}
.reply-avatar.user { background: linear-gradient(135deg,#67c23a,#2fbf7a); }
.reply-avatar.support { background: linear-gradient(135deg,#409eff,#337ecc); }
.reply-avatar.admin { background: linear-gradient(135deg,#f56c6c,#e03e3e); }
.reply-body { flex: 1; min-width: 0; }
.reply-head { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
.reply-name { font-weight: 600; }
.reply-time { margin-left: auto; }
.reply-content {
  background: #f5f7fa; border-radius: 10px; padding: 10px 14px;
  line-height: 1.7; border: 1px solid #ebeef5;
}
.reply-item.support .reply-content, .reply-item.admin .reply-content {
  background: #ecf5ff; border-color: #d9ecff;
}
.reply-item.internal .reply-content {
  background: #fdf6ec; border-color: #faecd8;
}
.mt-4 { margin-top: 6px; }
</style>
