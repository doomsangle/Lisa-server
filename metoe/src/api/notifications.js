import request from '@/utils/request'

export function getNotificationList(params) {
  return request({ url: '/notifications', method: 'get', params })
}

export function getNotificationUnreadCount() {
  return request({ url: '/notifications/unread-count', method: 'get' })
}

export function markNotificationRead(nid) {
  return request({ url: `/notifications/${nid}/read`, method: 'post' })
}

export function markAllNotificationsRead(type) {
  return request({ url: '/notifications/read-all', method: 'post', params: type ? { type } : {} })
}

export function deleteNotification(nid) {
  return request({ url: `/notifications/${nid}`, method: 'delete' })
}

export function clearReadNotifications() {
  return request({ url: '/notifications/clear-read', method: 'delete' })
}
