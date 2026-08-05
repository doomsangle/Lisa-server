import request from '@/utils/request'

export function login(data) {
  return request({ url: '/auth/login', method: 'post', data })
}
export function register(data) {
  return request({ url: '/auth/register', method: 'post', data })
}
export function logout() {
  return request({ url: '/auth/logout', method: 'post' })
}
export function getProfile() {
  return request({ url: '/auth/profile', method: 'get' })
}
export function updateProfile(data) {
  return request({ url: '/auth/profile', method: 'put', data })
}
export function changePassword(data) {
  return request({ url: '/auth/password', method: 'put', data })
}
export function resetApiKey() {
  return request({ url: '/auth/api-key/reset', method: 'post' })
}
// ---- 个人设置中心 ----
export function getSettings() {
  return request({ url: '/auth/settings', method: 'get' })
}
export function updateSettings(data) {
  return request({ url: '/auth/settings', method: 'put', data })
}
export function getBindings() {
  return request({ url: '/auth/bindings', method: 'get' })
}
export function sendBindingCode(data) {
  return request({ url: '/auth/bindings/send', method: 'post', data })
}
export function verifyBinding(data) {
  return request({ url: '/auth/bindings/verify', method: 'post', data })
}
export function setPayPassword(data) {
  return request({ url: '/auth/pay-password', method: 'post', data })
}
export function getLoginRecords(params) {
  return request({ url: '/auth/login-records', method: 'get', params })
}

