import { defineStore } from 'pinia'
import { login as loginApi, logout as logoutApi, getProfile } from '@/api/auth'
import router from '@/router'

export const useUserStore = defineStore('user', {
  state: () => ({
    token: localStorage.getItem('metoe_token') || '',
    userInfo: JSON.parse(localStorage.getItem('metoe_user') || 'null'),
    roles: [],
    permissions: []
  }),
  getters: {
    isLoggedIn: s => !!s.token,
    isAdmin: s => s.roles.includes('super_admin') || s.roles.includes('admin')
  },
  actions: {
    async login(payload) {
      const res = await loginApi(payload)
      const data = res?.data || res
      this.token = data.token
      this.userInfo = data.user || {}
      this.roles = data.roles || []
      this.permissions = data.permissions || []
      localStorage.setItem('metoe_token', this.token)
      localStorage.setItem('metoe_user', JSON.stringify(this.userInfo))
      return data
    },
    async fetchProfile() {
      try {
        const res = await getProfile()
        const data = res?.data || res
        this.userInfo = data.user
        this.roles = data.roles || []
        this.permissions = data.permissions || []
        localStorage.setItem('metoe_user', JSON.stringify(this.userInfo))
        return data
      } catch (e) {
        this.logout(true)
        throw e
      }
    },
    logout(goLogin = true) {
      try { logoutApi().catch(() => {}) } catch (_) {}
      this.token = ''
      this.userInfo = null
      this.roles = []
      this.permissions = []
      localStorage.removeItem('metoe_token')
      localStorage.removeItem('metoe_user')
      if (goLogin) {
        try { router.replace('/login').catch(() => {}) } catch (_) {}
      }
    },
    hasPermission(perm) {
      if (!perm) return true
      if (this.roles.includes('super_admin')) return true
      return this.permissions.includes(perm)
    }
  }
})
