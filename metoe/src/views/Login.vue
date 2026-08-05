<template>
  <div class="login-page">
    <div class="bg-deco"></div>
    <div class="login-box">
      <div class="login-left">
        <div class="brand">
          <el-icon size="42" color="#409eff"><Monitor /></el-icon>
          <h1>MetoE 全球云服务器平台</h1>
          <p class="muted">静态住宅 · 数据中心 · 移动节点<br />全球 190+ 国家机房，高性能高可靠</p>
        </div>
        <div class="feature-list">
          <div class="feature"><el-icon color="#52c41a"><CircleCheckFilled /></el-icon> 190+ 国家地区机房</div>
          <div class="feature"><el-icon color="#52c41a"><CircleCheckFilled /></el-icon> 企业级硬件 99.9% SLA</div>
          <div class="feature"><el-icon color="#52c41a"><CircleCheckFilled /></el-icon> SSH/RDP 远程接入</div>
          <div class="feature"><el-icon color="#52c41a"><CircleCheckFilled /></el-icon> 分钟级交付 / 按量订阅</div>
        </div>
      </div>
      <div class="login-right">
        <el-tabs v-model="activeTab" stretch class="login-tabs">
          <el-tab-pane label="登录" name="login">
            <el-form ref="loginRef" :model="loginForm" :rules="loginRules" label-position="top" @keyup.enter="onLogin">
              <el-form-item label="用户名 / 邮箱" prop="username">
                <el-input v-model="loginForm.username" placeholder="请输入用户名或邮箱" size="large">
                  <template #prefix><el-icon><User /></el-icon></template>
                </el-input>
              </el-form-item>
              <el-form-item label="密码" prop="password">
                <el-input v-model="loginForm.password" type="password" show-password placeholder="请输入密码" size="large">
                  <template #prefix><el-icon><Lock /></el-icon></template>
                </el-input>
              </el-form-item>
              <div class="flex-between mb-16">
                <el-checkbox v-model="loginForm.remember">记住我</el-checkbox>
                <a class="link">忘记密码？联系客服</a>
              </div>
              <el-button type="primary" size="large" class="full-width" :loading="loading" @click="onLogin">登 录</el-button>
              <div class="tips">
                测试账号：<b>admin / 123456</b> (管理员) &nbsp; 普通用户：<b>demo / 123456</b>
              </div>
            </el-form>
          </el-tab-pane>
          <el-tab-pane label="注册" name="register">
            <el-form ref="registerRef" :model="regForm" :rules="regRules" label-position="top">
              <el-form-item label="用户名" prop="username">
                <el-input v-model="regForm.username" placeholder="3-20位字母数字下划线" size="large" />
              </el-form-item>
              <el-form-item label="邮箱" prop="email">
                <el-input v-model="regForm.email" placeholder="请输入邮箱" size="large" />
              </el-form-item>
              <el-form-item label="密码" prop="password">
                <el-input v-model="regForm.password" type="password" show-password placeholder="6-32位" size="large" />
              </el-form-item>
              <el-form-item label="确认密码" prop="confirm">
                <el-input v-model="regForm.confirm" type="password" show-password placeholder="再次输入密码" size="large" />
              </el-form-item>
              <el-form-item prop="agree">
                <el-checkbox v-model="regForm.agree">
                  我已阅读并同意 <a class="link">用户协议</a> 和 <a class="link">隐私政策</a>
                </el-checkbox>
              </el-form-item>
              <el-button type="success" size="large" class="full-width" :loading="loading" @click="onRegister">立即注册</el-button>
            </el-form>
          </el-tab-pane>
        </el-tabs>

        <div class="cs-footer muted small">
          <div class="cs-title">💡 遇到问题？联系客服（7×24小时）：</div>
          <div class="cs-items">
            <span class="cs-tag">微信：support@metoe.io</span>
            <span class="cs-divider">|</span>
            <span class="cs-tag">📱 服务热线：400-888-6666</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { reactive, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Monitor, CircleCheckFilled, User, Lock } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import { register as registerApi } from '@/api/auth'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const activeTab = ref('login')
const loading = ref(false)
const loginRef = ref(null)
const registerRef = ref(null)

const loginForm = reactive({ username: '', password: '', remember: false })
const loginRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, min: 6, message: '密码至少6位', trigger: 'blur' }]
}

const regForm = reactive({ username: '', email: '', password: '', confirm: '', agree: false })
const validateConfirm = (r, v, cb) => {
  if (!v) return cb(new Error('请确认密码'))
  if (v !== regForm.password) return cb(new Error('两次密码不一致'))
  cb()
}
const regRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { pattern: /^[a-zA-Z0-9_]{3,20}$/, message: '3-20位字母数字下划线', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email', message: '邮箱格式错误', trigger: 'blur' }
  ],
  password: [{ required: true, min: 6, message: '密码至少6位', trigger: 'blur' }],
  confirm: [{ validator: validateConfirm, trigger: 'blur' }],
  agree: [
    { validator: (r, v, cb) => v ? cb() : cb(new Error('请先同意用户协议')), trigger: 'change' }
  ]
}

async function onLogin() {
  await loginRef.value.validate()
  try {
    loading.value = true
    await userStore.login(loginForm)
    ElMessage.success('登录成功')
    router.replace(route.query.redirect || '/dashboard')
  } finally {
    loading.value = false
  }
}
async function onRegister() {
  await registerRef.value.validate()
  try {
    loading.value = true
    await registerApi(regForm)
    ElMessage.success('注册成功，请登录')
    activeTab.value = 'login'
    loginForm.username = regForm.username
  } finally {
    loading.value = false
  }
}
</script>
<style scoped>
.login-page {
  height: 100vh; width: 100%; display: flex; align-items: center; justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  position: relative; overflow: hidden;
}
.bg-deco {
  position: absolute; inset: 0;
  background:
    radial-gradient(circle at 10% 20%, rgba(255,255,255,0.1) 0%, transparent 40%),
    radial-gradient(circle at 90% 80%, rgba(255,255,255,0.1) 0%, transparent 40%);
}
.login-box {
  position: relative; width: 880px; max-width: 92vw;
  background: #fff; border-radius: 16px; overflow: hidden;
  box-shadow: 0 20px 60px rgba(0,0,0,0.25);
  display: flex;
}
.login-left {
  width: 48%; padding: 48px 36px;
  background: linear-gradient(135deg, #409eff 0%, #67c23a 100%);
  color: #fff;
}
.login-right { width: 52%; padding: 36px 40px; }
.brand h1 { margin: 16px 0 8px; font-size: 28px; }
.brand .muted { color: rgba(255,255,255,0.9); line-height: 1.7; }
.feature-list { margin-top: 40px; display: grid; gap: 16px; }
.feature {
  display: flex; align-items: center; gap: 10px;
  background: rgba(255,255,255,0.15); padding: 10px 14px;
  border-radius: 8px; font-size: 14px;
}
.login-tabs { }
.full-width { width: 100%; }
.mb-16 { margin-bottom: 16px; }
.flex-between { display: flex; justify-content: space-between; align-items: center; }
.link { color: #409eff; cursor: pointer; }
.link:hover { text-decoration: underline; }
.tips {
  margin-top: 16px; padding: 10px 12px; background: #fef9e6;
  border-radius: 6px; font-size: 12px; color: #b37700;
  border: 1px solid #ffe58f;
}
@media (max-width: 768px) {
  .login-left { display: none; }
  .login-right { width: 100%; }
}
.cs-footer {
  margin-top: 20px; padding: 12px 14px; background: #f7faf7; border-radius: 8px;
  border: 1px solid #d9f7be; text-align: center; line-height: 1.7;
}
.cs-title { color: #389e0d; margin-bottom: 6px; font-weight: 500; }
.cs-items { display: flex; justify-content: center; align-items: center; flex-wrap: wrap; }
.cs-tag { padding: 0 8px; }
.cs-divider { color: #ddd; margin: 0 6px; }
.small { font-size: 12px; }
.muted { color: #6b7280; }
</style>
