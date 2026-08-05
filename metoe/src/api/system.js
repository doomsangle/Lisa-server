import request from '@/utils/request'

export function getUserList(params) {
  return request({ url: '/system/users', method: 'get', params })
}
export function createUser(data) {
  return request({ url: '/system/users', method: 'post', data })
}
export function updateUser(id, data) {
  return request({ url: `/system/users/${id}`, method: 'put', data })
}
export function deleteUser(id) {
  return request({ url: `/system/users/${id}`, method: 'delete' })
}
export function rechargeUser(id, data) {
  return request({ url: `/system/users/${id}/recharge`, method: 'post', data })
}
export function resetUserPassword(id, data) {
  return request({ url: `/system/users/${id}/reset-password`, method: 'post', data })
}
export function getRoleList() {
  return request({ url: '/system/roles', method: 'get' })
}
export function getPermissionTree() {
  return request({ url: '/system/permissions', method: 'get' })
}
export function createRole(data) {
  return request({ url: '/system/roles', method: 'post', data })
}
export function updateRole(code, data) {
  return request({ url: `/system/roles/${code}`, method: 'put', data })
}
export function deleteRole(code) {
  return request({ url: `/system/roles/${code}`, method: 'delete' })
}
export function saveRolePermissions(code, permissions) {
  return request({ url: `/system/roles/${code}/permissions`, method: 'post', data: { permissions } })
}
