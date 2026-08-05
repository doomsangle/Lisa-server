import request from '../utils/request'

export function listDeployTasks(params) {
  return request({ url: '/deploy-tasks', method: 'get', params })
}

export function getDeployTask(id) {
  return request({ url: `/deploy-tasks/${id}`, method: 'get' })
}

export function getDeployLogs(id) {
  return request({ url: `/deploy-tasks/${id}/logs`, method: 'get' })
}

export function retryDeploy(id) {
  return request({ url: `/deploy-tasks/${id}/retry`, method: 'post' })
}

export function callbackNotifyDeploy(data) {
  return request({ url: '/internal/deploy/notify', method: 'post', data })
}
