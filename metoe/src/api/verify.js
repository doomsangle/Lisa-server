import request from '@/utils/request'

export function getMyKycStatus() {
  return request({ url: '/verify/my-status', method: 'get' })
}

export function submitPersonKyc(payload) {
  return request({
    url: '/verify/submit/person',
    method: 'post',
    data: payload,
  })
}

export function submitCompanyKyc(payload) {
  return request({
    url: '/verify/submit/company',
    method: 'post',
    data: payload,
  })
}

export function demoAutoPass() {
  return request({ url: '/verify/demo/auto-pass', method: 'post' })
}

export function getKycAdminList(params) {
  return request({
    url: '/verify/admin/list',
    method: 'get',
    params: params || {},
  })
}

export function auditKyc({ id, pass, reason }) {
  return request({
    url: '/verify/admin/audit',
    method: 'post',
    data: { id, pass_: !!pass, reason: reason || '' },
  })
}
