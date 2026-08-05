import request from '@/utils/request'

export function getWalletBalance() {
  return request({ url: '/wallet/balance', method: 'get' })
}

export function createRecharge(data) {
  return request({ url: '/wallet/recharge', method: 'post', data })
}

export function getRechargeOptions() {
  return request({ url: '/wallet/recharge-options', method: 'get' })
}

export function transferFunds(data) {
  return request({ url: '/wallet/transfer', method: 'post', data })
}

export function getTransferList(params) {
  return request({ url: '/wallet/transfers', method: 'get', params })
}
