import request from '@/utils/request'

export function getProxyList(params) {
  return request({ url: '/proxies', method: 'get', params })
}
export function buyProxy(data) {
  return request({ url: '/proxies/buy', method: 'post', data })
}
export function updateProxy(id, data) {
  return request({ url: `/proxies/${id}`, method: 'put', data })
}
export function deleteProxy(id) {
  return request({ url: `/proxies/${id}`, method: 'delete' })
}
export function batchAction(action, data) {
  return request({ url: `/proxies/batch/${action}`, method: 'post', data })
}
export function getCountryTree() {
  return request({ url: '/proxies/country-tree', method: 'get' })
}
export function getPrices(params) {
  return request({ url: '/proxies/prices', method: 'get', params })
}
export function redeployProxy(id) {
  return request({ url: `/proxies/${id}/redeploy`, method: 'post' })
}

