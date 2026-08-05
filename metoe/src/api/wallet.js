import request from '@/utils/request'
import { getTransactionsList, getTransactionsSummary, TX_TYPE_OPTIONS } from './transactions'

const LS_KEY = 'metoe_wallet_fund_flow'
const LS_ACC_KEY = 'metoe_wallet_accounts'

function nowTime() {
  const d = new Date()
  const p = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}
function loadFlow() {
  try { return JSON.parse(localStorage.getItem(LS_KEY) || '[]') } catch { return [] }
}
function saveFlow(list) {
  localStorage.setItem(LS_KEY, JSON.stringify(list || []))
}
function loadAccounts(mainUserId = 'admin') {
  try {
    const cache = JSON.parse(localStorage.getItem(LS_ACC_KEY) || '{}')
    if (cache && Object.keys(cache).length) return cache
  } catch (_) {}
  const seed = {
    admin: { userId: 'admin', name: 'admin (主账号)', role: 'main', parentId: null, balance: 99979, lastUpdate: nowTime() },
    finance_alice: { userId: 'finance_alice', name: 'finance_alice (财务子账号)', role: 'sub', parentId: 'admin', balance: 8500, lastUpdate: nowTime() },
    ops_bob: { userId: 'ops_bob', name: 'ops_bob (运营子账号)', role: 'sub', parentId: 'admin', balance: 3200, lastUpdate: nowTime() },
    dev_carol: { userId: 'dev_carol', name: 'dev_carol (开发子账号)', role: 'sub', parentId: 'admin', balance: 1560, lastUpdate: nowTime() },
    audit_david: { userId: 'audit_david', name: 'audit_david (只读子账号)', role: 'sub', parentId: 'admin', balance: 480, lastUpdate: nowTime() },
    ex_erin: { userId: 'ex_erin', name: 'ex_erin (已停用)', role: 'sub', parentId: 'admin', balance: 20, lastUpdate: nowTime() },
    platform_root: { userId: 'platform_root', name: '平台管理员', role: 'super_admin', parentId: null, balance: 999999, lastUpdate: nowTime() },
  }
  localStorage.setItem(LS_ACC_KEY, JSON.stringify(seed))
  return seed
}
function saveAccounts(data) { localStorage.setItem(LS_ACC_KEY, JSON.stringify(data || {})) }

function seedDefaultFlowIfEmpty(mainUser = 'admin') {
  const list = loadFlow()
  if (list.length > 0) return list
  const acc = loadAccounts(mainUser)
  const seed = [
    { flowNo: 'FF' + Date.now() + '01', time: '2026-07-01 10:12:31', type: 'recharge', userId: 'admin', counterparty: '-', operator: 'admin', amount: 3000, balanceAfter: acc.admin.balance, remark: '支付宝充值-订单RCH20260701001' },
    { flowNo: 'FF' + Date.now() + '02', time: '2026-07-02 14:08:19', type: 'spend', userId: 'admin', counterparty: '平台-云服务器', operator: 'admin', amount: -218, balanceAfter: acc.admin.balance - 5000, remark: '购买 US 2核2G 5M 30天 · 订单PO00001' },
    { flowNo: 'FF' + Date.now() + '03', time: '2026-07-05 09:44:02', type: 'transfer_out', userId: 'admin', counterparty: 'finance_alice', operator: 'admin', amount: -5000, balanceAfter: acc.admin.balance - 5000, remark: '划转至财务子账号 · 月度预算' },
    { flowNo: 'FF' + Date.now() + '04', time: '2026-07-05 09:44:03', type: 'transfer_in', userId: 'finance_alice', counterparty: 'admin', operator: 'admin', amount: 5000, balanceAfter: acc.finance_alice.balance, remark: '主账号划转 · 月度预算' },
    { flowNo: 'FF' + Date.now() + '05', time: '2026-07-08 11:02:58', type: 'spend', userId: 'ops_bob', counterparty: '平台-云服务器', operator: 'ops_bob', amount: -298, balanceAfter: acc.ops_bob.balance, remark: '批量购买 2 台新加坡节点 · PO00023' },
    { flowNo: 'FF' + Date.now() + '06', time: '2026-07-10 15:38:12', type: 'refund', userId: 'admin', counterparty: '平台-退款', operator: 'system', amount: 218, balanceAfter: acc.admin.balance, remark: '工单退款 · PO00001 质量问题赔付' },
    { flowNo: 'FF' + Date.now() + '07', time: '2026-07-15 19:21:40', type: 'transfer_out', userId: 'admin', counterparty: 'dev_carol', operator: 'admin', amount: -1000, balanceAfter: acc.admin.balance - 1000, remark: '划转至开发子账号 · 测试环境预算' },
    { flowNo: 'FF' + Date.now() + '08', time: '2026-07-15 19:21:41', type: 'transfer_in', userId: 'dev_carol', counterparty: 'admin', operator: 'admin', amount: 1000, balanceAfter: acc.dev_carol.balance, remark: '主账号划转 · 测试环境预算' },
    { flowNo: 'FF' + Date.now() + '09', time: '2026-07-18 13:55:03', type: 'transfer_in', userId: 'admin', counterparty: 'audit_david', operator: 'audit_david', amount: 180, balanceAfter: acc.admin.balance + 180, remark: '只读子账号余额归集 · 离职清退' },
    { flowNo: 'FF' + Date.now() + '10', time: '2026-07-18 13:55:04', type: 'transfer_out', userId: 'audit_david', counterparty: 'admin', operator: 'audit_david', amount: -180, balanceAfter: acc.audit_david.balance, remark: '余额归集至主账号 · 离职清退' },
  ]
  saveFlow(seed)
  return seed
}

export function listWalletAccounts(mainUserId) {
  return new Promise(async (resolve) => {
    try {
      const r = await request({ url: '/subaccounts', method: 'get', params: { page: 1, page_size: 200 } })
      if (r && r.code === 0 && Array.isArray(r.data?.list)) {
        const main = { userId: 'admin', name: 'admin (主账号)', role: 'main', parentId: null, balance: 0, lastUpdate: nowTime() }
        try {
          const b = await request({ url: '/wallet/balance', method: 'get' })
          if (b?.code === 0) main.balance = b.data?.balanceNum || 0
        } catch (_) {}
        const subs = r.data.list.map((c, i) => ({
          userId: c.childId || c.username || ('sub_' + i),
          name: (c.username || 'sub_' + i) + ' (子账号)',
          role: c.status === 'disabled' || c.status === 0 ? 'sub disabled' : 'sub',
          parentId: mainUserId || 'admin',
          balance: c.maxBalance != null ? Number(c.maxBalance) : (c.balanceNum || 0),
          lastUpdate: c.createdAt || nowTime(),
        }))
        resolve({ code: 0, data: [main, ...subs] })
        return
      }
    } catch (_) {}
    const accs = loadAccounts(mainUserId)
    setTimeout(() => resolve({ data: Object.values(accs), code: 0 }), 120)
  })
}

export function transferFunds({ fromUserId, toUserId, amount, remark = '', operator, payPassword }) {
  return new Promise(async (resolve, reject) => {
    try {
      const r = await request({ url: '/wallet/transfer', method: 'post', data: {
        to_username: toUserId, amount: Number(amount), remark: remark || '划转',
        pay_password: payPassword,
      }})
      if (r && r.code === 0 && r.data) {
        const t = r.data
        resolve({ code: 0, data: {
          from: { flowNo: t.transferNo, time: nowTime(), type: 'transfer_out', userId: fromUserId, counterparty: toUserId, operator: operator || fromUserId, amount: -1 * Number(amount), balanceAfter: t.balanceAfter || 0, remark: remark || '划转支出' },
          to:   { flowNo: t.transferNo + 'B', time: nowTime(), type: 'transfer_in', userId: toUserId, counterparty: fromUserId, operator: operator || fromUserId, amount: Number(amount), balanceAfter: t.toBalanceAfter || 0, remark: remark || '划转收入' },
        }})
        return
      } else if (r && r.message) {
        return reject(new Error(r.message))
      }
    } catch (e) {
      if (e && /^(余额|金额|请选择|不能等于|账户|划转金额)/.test(e.message || '')) return reject(e)
    }
    amount = Number(amount) || 0
    if (!fromUserId || !toUserId) return reject(new Error('请选择转出和转入账号'))
    if (fromUserId === toUserId) return reject(new Error('转出账号不能等于转入账号'))
    if (amount <= 0) return reject(new Error('划转金额必须大于 0'))
    const accs = loadAccounts()
    const from = accs[fromUserId]
    const to = accs[toUserId]
    if (!from) return reject(new Error('转出账号不存在'))
    if (!to) return reject(new Error('转入账号不存在'))
    if (Number(from.balance) < amount) return reject(new Error(`转出账号余额不足（当前余额 ¥${Number(from.balance).toFixed(2)}）`))

    from.balance = Number((Number(from.balance) - amount).toFixed(2))
    to.balance = Number((Number(to.balance) + amount).toFixed(2))
    from.lastUpdate = nowTime()
    to.lastUpdate = nowTime()
    saveAccounts(accs)

    const t1 = nowTime()
    const base = Date.now()
    const f1 = {
      flowNo: 'FF' + base + 'A', time: t1, type: 'transfer_out',
      userId: fromUserId, counterparty: toUserId, operator: operator || fromUserId,
      amount: -1 * amount, balanceAfter: from.balance, remark: remark || '划转支出'
    }
    const f2 = {
      flowNo: 'FF' + (base + 1) + 'B', time: t1, type: 'transfer_in',
      userId: toUserId, counterparty: fromUserId, operator: operator || fromUserId,
      amount: amount, balanceAfter: to.balance, remark: remark || '划转收入'
    }
    const list = loadFlow()
    list.unshift(f1, f2)
    saveFlow(list)

    setTimeout(() => resolve({ code: 0, data: { from: f1, to: f2 } }), 220)
  })
}

export function collectFunds({ fromUserId, toUserId, amount, operator, remark }) {
  return transferFunds({ fromUserId, toUserId, amount, remark: remark || '余额归集', operator })
}

function txToFlow(tx) {
  const typeMap = {
    recharge: 'recharge', order_pay: 'spend', order_refund: 'refund',
    transfer_out: 'transfer_out', transfer_in: 'transfer_in',
    sub_transfer_out: 'transfer_out', sub_transfer_in: 'transfer_in',
    daily_fee: 'spend', coupon_rebate: 'refund',
    affiliate_commission: 'recharge', system_adjust: 'spend',
  }
  const type = typeMap[tx.type] || tx.type
  return {
    flowNo: tx.id != null ? ('TX' + tx.id) : ('TX' + (tx.orderNo || tx.txId || '')),
    time: tx.createdAt || nowTime(),
    type, userId: tx.userId || 'admin',
    counterparty: tx.payChannel ? ('支付-' + tx.payChannel) : (tx.orderNo ? ('订单-' + tx.orderNo) : '-'),
    operator: tx.userId || 'admin',
    amount: type === 'recharge' || type === 'refund' || type === 'transfer_in'
      ? Math.abs(tx.amountNum || 0)
      : -1 * Math.abs(tx.amountNum || 0),
    balanceAfter: tx.balanceAfter ? Number(tx.balanceAfter) : 0,
    remark: tx.remark || (tx.typeLabel || '') + (tx.orderNo ? ' · ' + tx.orderNo : ''),
  }
}

export function getFundFlow(params = {}) {
  return new Promise(async (resolve) => {
    try {
      const p = { page: params.page || 1, page_size: params.pageSize || 20 }
      if (params.type && params.type !== 'all') p.type = params.type
      if (params.keyword) p.keyword = params.keyword
      const r = await getTransactionsList(p)
      if (r && r.code === 0) {
        resolve({
          code: 0,
          data: {
            list: (r.data.list || []).map(txToFlow),
            total: r.data.total || 0,
            page: r.data.page || p.page,
            pageSize: r.data.pageSize || p.page_size,
          },
        })
        return
      }
    } catch (_) {}
    let list = seedDefaultFlowIfEmpty(params.mainUserId || 'admin')
    if (params.userId && params.userId !== 'all') list = list.filter(f => f.userId === params.userId)
    if (params.type && params.type !== 'all') list = list.filter(f => f.type === params.type)
    if (params.keyword) {
      const kw = String(params.keyword).toLowerCase()
      list = list.filter(f =>
        (f.flowNo || '').toLowerCase().includes(kw) ||
        (f.remark || '').toLowerCase().includes(kw) ||
        (f.counterparty || '').toLowerCase().includes(kw) ||
        (f.userId || '').toLowerCase().includes(kw)
      )
    }
    const page = Number(params.page) || 1
    const pageSize = Number(params.pageSize) || 15
    const total = list.length
    const start = (page - 1) * pageSize
    setTimeout(() => resolve({
      code: 0, data: { list: list.slice(start, start + pageSize), total, page, pageSize }
    }), 120)
  })
}

export function getWalletStats(mainUserId = 'admin') {
  return new Promise(async (resolve) => {
    try {
      const [balanceR, summaryR] = await Promise.all([
        request({ url: '/wallet/balance', method: 'get' }),
        getTransactionsSummary({}),
      ])
      if (balanceR?.code === 0 && summaryR?.code === 0) {
        const b = Number(summaryR.data?.totalIncome || 0)
        const c = Number(summaryR.data?.totalExpense || 0)
        resolve({
          code: 0,
          data: {
            mainBalance: balanceR.data?.balanceNum || 0,
            subTotal: 0,
            monthRecharge: b,
            monthSpend: c,
            monthTransferOut: 0,
            monthTransferIn: 0,
            monthRefund: 0,
          },
        })
        return
      }
    } catch (_) {}
    const list = seedDefaultFlowIfEmpty(mainUserId)
    const monthKey = new Date().toISOString().slice(0, 7)
    const monthFlows = list.filter(f => (f.time || '').startsWith(monthKey))
    const accs = loadAccounts(mainUserId)
    const accounts = Object.values(accs).filter(a => a.parentId === mainUserId || a.userId === mainUserId)
    const sum = (arr) => arr.reduce((s, x) => s + (Number(x.amount) || 0), 0)
    const stats = {
      mainBalance: (accs[mainUserId] || {}).balance || 0,
      subTotal: accounts.filter(a => a.role === 'sub').reduce((s, a) => s + Number(a.balance || 0), 0),
      monthRecharge: sum(monthFlows.filter(f => f.type === 'recharge')),
      monthSpend: Math.abs(sum(monthFlows.filter(f => f.type === 'spend'))),
      monthTransferOut: Math.abs(sum(monthFlows.filter(f => f.type === 'transfer_out' && f.userId === mainUserId))),
      monthTransferIn: sum(monthFlows.filter(f => f.type === 'transfer_in' && f.userId === mainUserId)),
      monthRefund: sum(monthFlows.filter(f => f.type === 'refund')),
    }
    setTimeout(() => resolve({ code: 0, data: stats }), 100)
  })
}

export { TX_TYPE_OPTIONS }
