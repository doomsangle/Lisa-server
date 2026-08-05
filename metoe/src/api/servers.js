import request from '../utils/request'

export function listServers(params) {
  return request({ url: '/servers', method: 'get', params })
}

export function getServerDetail(id) {
  return request({ url: `/servers/${id}`, method: 'get' })
}

export function rebootServer(id) {
  return request({ url: `/servers/${id}/reboot`, method: 'post' })
}

export function reinstallServer(id) {
  return request({ url: `/servers/${id}/reinstall`, method: 'post' })
}
