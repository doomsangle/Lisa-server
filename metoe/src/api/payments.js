import request from '../utils/request'

export function createPayment(data) {
  return request({ url: '/payments/create', method: 'post', data })
}

export function mockConfirmPay(payNo) {
  return request({ url: `/payments/mock-confirm?pay_no=${payNo}`, method: 'get' })
}

export function listPayments(params) {
  return request({ url: '/payments', method: 'get', params })
}

export function getPaymentDetail(payNo) {
  return request({ url: `/payments/${payNo}`, method: 'get' })
}
