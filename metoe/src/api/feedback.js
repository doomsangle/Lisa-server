import request from '@/utils/request'

export function getFeedbackList(params) {
  return request({ url: '/feedbacks', method: 'get', params })
}

export function createFeedback(data) {
  return request({ url: '/feedbacks', method: 'post', data })
}

export function getFeedbackDetail(id) {
  return request({ url: `/feedbacks/${id}`, method: 'get' })
}

export function replyFeedback(id, data) {
  return request({ url: `/feedbacks/${id}/replies`, method: 'post', data })
}

export function updateFeedbackStatus(id, status) {
  return request({ url: `/feedbacks/${id}/status`, method: 'put', data: { status } })
}
