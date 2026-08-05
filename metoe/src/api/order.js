import request from '@/utils/request'

export function getOrderList(params) {
  return request({ url: '/orders', method: 'get', params })
}
export function getOrderDetail(orderNo) {
  return request({ url: `/orders/${orderNo}`, method: 'get' })
}
export function payOrder(orderNo, data = {}) {
  return request({ url: `/orders/${orderNo}/pay`, method: 'post', data })
}
export function updateOrderStatus(id, status) {
  return request({ url: `/orders/${id}/status`, method: 'put', data: { status } })
}
export function runCheckIp(data) {
  return request({ url: '/check/ip', method: 'post', data })
}
export function getCheckHistory(params) {
  return request({ url: '/check/history', method: 'get', params })
}
export function getFeedbackList(params) {
  return request({ url: '/feedbacks', method: 'get', params })
}
export function createFeedback(data) {
  return request({ url: '/feedbacks', method: 'post', data })
}
export function getFeedbackDetail(id) {
  return request({ url: `/feedbacks/${id}`, method: 'get' })
}
export function updateFeedbackStatus(id, status) {
  return request({ url: `/feedbacks/${id}/status`, method: 'put', data: { status } })
}
