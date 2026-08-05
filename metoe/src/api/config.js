import request from '../utils/request'

export function getCustomerService() {
  return request({ url: '/config/customer-service', method: 'get' })
}

export function getPaymentChannels() {
  return request({ url: '/config/payment-channels', method: 'get' })
}

export function listAllConfigs() {
  return request({ url: '/config/all', method: 'get' })
}

export function saveConfigs(items) {
  return request({ url: '/config/save', method: 'post', data: { items } })
}
