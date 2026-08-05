<template>
  <div class="roles-page">
    <el-row :gutter="16">
      <el-col :span="9">
        <div class="page-card">
          <div class="flex-between">
            <h3 class="section-title"><el-icon><Lock /></el-icon> 角色列表</h3>
            <el-button type="primary" size="small" @click="openEdit(null)"><el-icon><Plus /></el-icon> 新增</el-button>
          </div>
          <el-table :data="roles" border stripe @row-click="selectRole" highlight-current-row>
            <el-table-column prop="code" label="标识" width="140">
              <template #default="{ row }">
                <el-tag size="small" :type="row.code==='super_admin'?'danger':(row.code==='admin'?'warning':'info')">{{ row.code }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="name" label="名称" />
            <el-table-column prop="userCount" label="用户数" width="80" align="center" />
            <el-table-column label="操作" width="150" @click.stop>
              <template #default="{ row }">
                <el-button link size="small" @click="openEdit(row)"><el-icon><Edit /></el-icon> 编辑</el-button>
                <el-button link size="small" type="danger" :disabled="row.protected" @click="removeRole(row)">
                  <el-icon><Delete /></el-icon> 删除
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>
      <el-col :span="15">
        <div class="page-card">
          <h3 class="section-title">
            <el-icon><Key /></el-icon> 权限分配 -
            <span style="color:#409eff">{{ currentRole ? currentRole.name : '请选择角色' }}</span>
          </h3>
          <el-alert v-if="!currentRole" type="info" :closable="false" title="请从左侧选择角色以编辑其权限。" />
          <template v-else>
            <div class="flex-between mt-12">
              <div>
                <el-checkbox :model-value="isAllSelected" :indeterminate="isIndeterminate" @change="checkAll">
                  全选 / 反选
                </el-checkbox>
              </div>
              <el-button size="small" type="primary" :loading="saving" @click="savePerms">
                <el-icon><CircleCheckFilled /></el-icon> 保存权限
              </el-button>
            </div>
            <el-tree
              ref="treeRef"
              class="mt-12"
              :data="permTree"
              show-checkbox
              node-key="code"
              :default-checked-keys="currentRole.permissions"
              :props="{ label: 'name', children: 'children' }"
              style="background:#fafbfc; padding: 12px; border-radius: 8px"
            />
          </template>
        </div>

        <div class="page-card mt-16">
          <h3 class="section-title"><el-icon><Notebook /></el-icon> 权限说明（RBAC 模型）</h3>
          <el-descriptions :column="2" border size="small">
            <el-descriptions-item label="模型">用户 → 角色 → 权限（多对多）</el-descriptions-item>
            <el-descriptions-item label="Super Admin">拥有全部权限（绕过检查）</el-descriptions-item>
            <el-descriptions-item label="前端">路由 meta.permission + Pinia hasPermission()</el-descriptions-item>
            <el-descriptions-item label="后端">JWT 中间件 + RBAC 中间件校验</el-descriptions-item>
          </el-descriptions>
        </div>
      </el-col>
    </el-row>

    <el-dialog v-model="editVisible" :title="editingRole ? '编辑角色' : '新增角色'" width="460px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="标识" prop="code">
          <el-input v-model="form.code" placeholder="英文标识，如：support" :disabled="!!editingRole" />
        </el-form-item>
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="中文名称，如：客服" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="form.desc" type="textarea" :rows="3" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveRole">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Lock, Plus, Edit, Delete, Key, CircleCheckFilled, Notebook } from '@element-plus/icons-vue'

const permTree = [
  { code: 'dashboard', name: '仪表盘', children: [
    { code: 'dashboard:view', name: '查看仪表盘' }
  ]},
  { code: 'access', name: '接入实例', children: [
    { code: 'nodes:view', name: '查看接入实例' },
    { code: 'nodes:manage', name: '管理接入实例（增删改）' }
  ]},
  { code: 'servers', name: '云服务器', children: [
    { code: 'servers:view', name: '查看云服务器' },
    { code: 'servers:manage', name: '管理云服务器' }
  ]},
  { code: 'deploy', name: '部署任务', children: [
    { code: 'deploy:view', name: '查看部署记录' },
    { code: 'deploy:run', name: '执行部署/重部署' }
  ]},
  { code: 'payment', name: '支付与账单', children: [
    { code: 'payment:pay', name: '发起支付' },
    { code: 'payment:view', name: '查看支付记录' },
    { code: 'payment:refund', name: '退款管理' }
  ]},
  { code: 'orders', name: '订单', children: [
    { code: 'orders:create', name: '下单购买' },
    { code: 'orders:view', name: '查看订单' },
    { code: 'orders:manage', name: '管理订单（改价/退款）' }
  ]},
  { code: 'check', name: '网络检测中心', children: [
    { code: 'check:run', name: '执行检测' },
    { code: 'check:history', name: '查看历史' }
  ]},
  { code: 'developer', name: '开发者 API', children: [
    { code: 'developer:view', name: '查看 API 文档' },
    { code: 'developer:key', name: '生成 API Key' }
  ]},
  { code: 'feedback', name: '反馈', children: [
    { code: 'feedback:create', name: '提交反馈' },
    { code: 'feedback:manage', name: '处理反馈' }
  ]},
  { code: 'config', name: '系统配置', children: [
    { code: 'config:view', name: '查看系统配置' },
    { code: 'config:manage', name: '修改系统配置' }
  ]},
  { code: 'system', name: '系统管理', children: [
    { code: 'system:users:view', name: '查看用户' },
    { code: 'system:users:manage', name: '管理用户（增删改）' },
    { code: 'system:roles:view', name: '查看角色' },
    { code: 'system:roles:manage', name: '管理角色权限' }
  ]}
]
const allLeafKeys = computed(() => {
  const arr = []
  function walk(nodes) {
    nodes.forEach(n => {
      if (n.children && n.children.length) walk(n.children)
      else arr.push(n.code)
    })
  }
  walk(permTree)
  return arr
})

const defaultRoles = [
  { code: 'super_admin', name: '超级管理员', protected: true, userCount: 1,
    permissions: allLeafKeys.value, desc: '拥有全部权限' },
  { code: 'admin', name: '管理员', protected: true, userCount: 2,
    permissions: allLeafKeys.value.filter(k => !k.startsWith('system:roles') && k !== 'config:manage'),
    desc: '业务管理员' },
  { code: 'finance', name: '财务', protected: false, userCount: 0,
    permissions: ['dashboard:view','orders:view','orders:manage','payment:view','payment:refund','servers:view'], desc: '财务管理' },
  { code: 'support', name: '客服', protected: false, userCount: 0,
    permissions: ['dashboard:view','nodes:view','servers:view','deploy:view','check:run','check:history','feedback:manage','config:view'], desc: '客服与运营' },
  { code: 'user', name: '普通用户', protected: true, userCount: 15,
    permissions: ['dashboard:view','nodes:view','servers:view','deploy:view','deploy:run','orders:create','orders:view','payment:pay','payment:view','check:run','check:history','developer:view','developer:key','feedback:create'], desc: '注册默认角色' }
]
const roles = ref([...defaultRoles])
const currentRole = ref(null)
const treeRef = ref(null)

function selectRole(row) {
  currentRole.value = row
}

const checkedKeys = computed(() => currentRole.value?.permissions || [])
const isAllSelected = computed(() => checkedKeys.value.length > 0 && checkedKeys.value.length === allLeafKeys.value.length)
const isIndeterminate = computed(() => checkedKeys.value.length > 0 && checkedKeys.value.length < allLeafKeys.value.length)

function checkAll(val) {
  if (!treeRef.value) return
  if (val) treeRef.value.setCheckedKeys(allLeafKeys.value)
  else treeRef.value.setCheckedKeys([])
}
function savePerms() {
  const keys = treeRef.value.getCheckedKeys(false)
  currentRole.value.permissions = keys
  ElMessage.success(`角色 ${currentRole.value.name} 权限已保存，共 ${keys.length} 项`)
}

const editVisible = ref(false)
const saving = ref(false)
const editingRole = ref(null)
const formRef = ref(null)
const form = reactive({ code: '', name: '', desc: '' })
const rules = {
  code: [
    { required: true, message: '请输入标识' },
    { pattern: /^[a-z][a-z0-9_]{1,31}$/, message: '2-32位小写字母数字下划线' }
  ],
  name: [{ required: true, message: '请输入名称' }]
}
function openEdit(row) {
  editingRole.value = row
  if (row) {
    Object.assign(form, { code: row.code, name: row.name, desc: row.desc })
  } else {
    Object.assign(form, { code: '', name: '', desc: '' })
  }
  editVisible.value = true
}
async function saveRole() {
  await formRef.value.validate()
  saving.value = true
  setTimeout(() => {
    saving.value = false
    if (editingRole.value) {
      Object.assign(editingRole.value, { name: form.name, desc: form.desc })
      ElMessage.success('已更新')
    } else {
      roles.value.push({ code: form.code, name: form.name, protected: false, userCount: 0, permissions: [], desc: form.desc })
      ElMessage.success('已新增')
    }
    editVisible.value = false
  }, 400)
}
function removeRole(row) {
  ElMessageBox.confirm(`确认删除角色 ${row.name}？已分配该角色的用户将失去对应权限。`, '提示', { type: 'warning' })
    .then(() => {
      const idx = roles.value.findIndex(r => r.code === row.code)
      if (idx >= 0) roles.value.splice(idx, 1)
      ElMessage.success('已删除')
      if (currentRole.value?.code === row.code) currentRole.value = null
    }).catch(() => {})
}

onMounted(() => { if (roles.value.length) selectRole(roles.value[0]) })
</script>
<style scoped>
.roles-page { }
.section-title { display: flex; align-items: center; gap: 8px; margin: 0 0 14px; font-size: 16px; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }
.mt-12 { margin-top: 12px; } .mt-16 { margin-top: 16px; }
</style>
