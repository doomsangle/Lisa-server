import request from '@/utils/request'

export function createSnapshot(proxyId, snapshotType = 'manual') {
  return request({ url: `/reputation/snapshot/${proxyId}`, method: 'post', params: { snapshot_type: snapshotType } })
}

export function getSnapshotList(params) {
  return request({ url: '/reputation/snapshots', method: 'get', params })
}

export function getReputationTrend(proxyId, limit = 30) {
  return request({ url: `/reputation/trend/${proxyId}`, method: 'get', params: { limit } })
}
