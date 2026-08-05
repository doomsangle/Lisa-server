import request from '@/utils/request'

export function runIpCheck({ ip, checks }) {
  return request({
    url: '/check/ip',
    method: 'post',
    data: { ip, checks: checks || ['geo', 'asn', 'rbl', 'abuse', 'ipqs', 'scam', 'spur'] }
  })
}

export function getCheckHistory({ page = 1, pageSize = 20 } = {}) {
  return request({
    url: '/check/history',
    method: 'get',
    params: { page, pageSize }
  })
}

export function getCheckRecordById(id) {
  return request({
    url: `/check/record/${id}`,
    method: 'get'
  })
}

export function exportCheckHistory() {
  return request({
    url: '/check/export',
    method: 'get',
    responseType: 'blob'
  })
}
