import request from '@/utils/request'

export function getSubaccountList(params) {
  return request({ url: '/subaccounts', method: 'get', params })
}

export function createSubaccount(data) {
  return request({ url: '/subaccounts', method: 'post', data })
}

export function updateSubaccount(childId, data) {
  return request({ url: `/subaccounts/${childId}`, method: 'put', data })
}

export function resetSubaccountPassword(childId, newPassword) {
  return request({ url: `/subaccounts/${childId}/reset-password`, method: 'post', data: { new_password: newPassword } })
}

export function deleteSubaccount(childId) {
  return request({ url: `/subaccounts/${childId}`, method: 'delete' })
}

export function getSubaccountPermissions() {
  return request({ url: '/subaccounts/permissions/available', method: 'get' })
}
