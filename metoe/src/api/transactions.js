import request from '@/utils/request'

export function getTransactionsList(params) {
  return request({ url: '/transactions', method: 'get', params })
}

export function getTransactionsSummary(params) {
  return request({ url: '/transactions/summary', method: 'get', params })
}

export const TX_TYPE_OPTIONS = [
  { value: 'recharge', label: '充值' },
  { value: 'order_pay', label: '订单支付' },
  { value: 'order_refund', label: '订单退款' },
  { value: 'transfer_out', label: '资金划出' },
  { value: 'transfer_in', label: '资金划入' },
  { value: 'daily_fee', label: '日扣费' },
  { value: 'system_adjust', label: '系统调整' },
  { value: 'coupon_rebate', label: '优惠券返利' },
  { value: 'affiliate_commission', label: '分销佣金' },
]
