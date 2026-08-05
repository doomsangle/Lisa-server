import request from '@/utils/request'

export function getCouponList(params) {
  return request({ url: '/coupons', method: 'get', params })
}

export function getAvailableCoupons() {
  return request({ url: '/coupons/available', method: 'get' })
}

export function getMyCoupons(params) {
  return request({ url: '/coupons/mine', method: 'get', params })
}

export function createCoupon(data) {
  return request({ url: '/coupons', method: 'post', data })
}

export function updateCoupon(cid, data) {
  return request({ url: `/coupons/${cid}`, method: 'put', data })
}

export function redeemCoupon(code) {
  return request({ url: '/coupons/redeem', method: 'post', data: { code } })
}
