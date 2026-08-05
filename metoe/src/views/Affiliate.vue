<template>
  <div class="page-wrap">
    <el-card shadow="hover" class="hero-card">
      <div class="hero-row">
        <div class="hero-l">
          <div class="hero-title">
            <el-icon :size="28" color="#a855f7"><Share /></el-icon>
            <div>
              <h1>MetoE — 出海人的第一台全球服务器</h1>
              <p class="slogan-sub">3 分钟 · 美日新德英 · 干净 IP · 独享机器 · 扫码即用 · 中文客服</p>
            </div>
            <el-tag type="danger" effect="dark" round size="large" class="tag">邀请好友 · 终身返佣 15% 起</el-tag>
          </div>
          <div class="hero-sub muted">
            你的好友通过你的专属链接注册并充值购买，你将获得 <b class="hl">首充 15% + 复购 8%</b> 终身返佣；<br/>
            升级为 <b class="hl2">金牌分销员</b>（邀请满 50 人 或 月佣金满 ¥3000）后，最高享 <b class="hl2">30%</b> 返佣，佣金 T+1 自动提现至微信 / 支付宝 / USDT。<br/>
            <span class="trust">🛡️ 7 天无理由退款 · IP 纯净度 SLA · 不封号承诺 · 微信客服秒回</span>
          </div>
          <div class="hero-actions">
            <el-button type="primary" size="large" :icon="Present" @click="showLink">一键复制邀请链接</el-button>
            <el-button size="large" plain :icon="PictureFilled">生成专属海报</el-button>
            <el-button size="large" type="success" plain :icon="Wallet">立即提现</el-button>
          </div>
        </div>
        <div class="hero-r">
          <el-row :gutter="12">
            <el-col :span="12"><div class="h-box ok">
              <div class="hb-lbl muted small">累计返佣总额</div>
              <div class="hb-val">¥ {{ stats.totalComms.toLocaleString() }}</div>
              <div class="hb-foot up">较上月 ↑ 18.2%</div>
            </div></el-col>
            <el-col :span="12"><div class="h-box prim">
              <div class="hb-lbl muted small">可提现余额</div>
              <div class="hb-val">¥ {{ stats.availComms.toLocaleString() }}</div>
              <div class="hb-foot">满 ¥100 T+1 自动结算</div>
            </div></el-col>
            <el-col :span="12"><div class="h-box warn">
              <div class="hb-lbl muted small">已提现金额</div>
              <div class="hb-val">¥ {{ stats.withdrawn.toLocaleString() }}</div>
              <div class="hb-foot">累计 {{ stats.wdCount }} 笔 · 24h 内到账</div>
            </div></el-col>
            <el-col :span="12"><div class="h-box info">
              <div class="hb-lbl muted small">邀请总人数</div>
              <div class="hb-val">{{ stats.invitees }} <span class="unit">人</span></div>
              <div class="hb-foot">本月新增 {{ stats.newInvitees }} 人 · 激活率 62%</div>
            </div></el-col>
          </el-row>
        </div>
      </div>
    </el-card>

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="16">
        <el-card shadow="never" class="persona-card">
          <template #header>
            <div class="card-header">
              <b>🎯 复制·按你的人群一键发（5 套 Persona 专属话术）</b>
              <el-tag type="success" effect="light" round>点卡片话术一键复制</el-tag>
            </div>
          </template>
          <el-tabs v-model="activePersona" size="default" class="persona-tabs">
            <el-tab-pane name="p0">
              <template #label>🏪 跨境电商张店长（P0 最高优先）</template>
              <div class="persona-body">
                <div class="painter-row">
                  <div class="tag-painter">
                    <el-tag type="danger" effect="dark">痛点</el-tag>
                    <span class="txt">美国静态住宅 IP 怕封号 · 5 个站点 10 台机器管不过来 · 不会 Linux</span>
                  </div>
                  <div class="tag-painter ok">
                    <el-tag type="success" effect="dark">卖点</el-tag>
                    <span class="txt">48 条 RBL 体检 · 7 天 IP 封号免费换 · 3 分钟扫码即用 · 微信秒回</span>
                  </div>
                </div>
                <div class="copy-box">
                  <div class="copy-title">📱 私域群发/朋友圈话术（一键复制）</div>
                  <div class="copy-content" ref="copy0Ref">【推荐·跨境卖家防封号神器】
张总，您亚马逊 5 个站点 10 家店铺，现在买的美国 IP 是不是用着用着就封号？

🔥 MetoE 每台机器交付前都过 48 条 RBL 黑名单体检，【7 天内因 IP 问题封号凭截图免费换新】；1C1G 住宅 IP ¥49/台/月，买 10 台首单再打 5 折，下单后 3 分钟手机扫码直接用，完全不用懂 SSH。

👉 点我专属链接注册首单再减 ¥100：{{ link }}

有任何问题微信直接找我，我帮您对接中文客服。</div>
                  <el-button type="primary" :icon="DocumentCopy" @click="cpEl('copy0Ref')">复制朋友圈话术</el-button>
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane name="p1">
              <template #label>📣 社媒矩阵李运营（P1 高）</template>
              <div class="persona-body">
                <div class="painter-row">
                  <div class="tag-painter">
                    <el-tag type="danger" effect="dark">痛点</el-tag>
                    <span class="txt">200 台美国 ISP 切 IP 切到吐 · 一账号一 IP 绝对隔离 · 被 TikTok 机房检测</span>
                  </div>
                  <div class="tag-painter ok">
                    <el-tag type="success" effect="dark">卖点</el-tag>
                    <span class="txt">API 一键开 200 台 · 独享 ISP 不共享 · 被封号算我们免费换 · 账单自动分摊</span>
                  </div>
                </div>
                <div class="copy-box">
                  <div class="copy-title">📱 TikTok / MCN 私域话术（一键复制）</div>
                  <div class="copy-content" ref="copy1Ref">【TikTok 矩阵运营福音】
李总，您现在 200 个 TikTok 号切 IP 是不是一个运营管 50 个号切到吐？

🔥 MetoE 支持【API 一键批量创建 200 台美国 ISP 独享 IP】，30 秒全部交付；运营只管发内容不用管环境；被 TikTok 识别封号了我们【免费换新 IP】；价格 ¥69/台/月，比您现在买的共享机场还便宜 20%。

👉 专属注册链接（首单 ¥1000 减 ¥200）：{{ link }}

我自己团队在用，稳定运营 3 个月零批量封号，您可以先拿 10 台试 7 天。</div>
                  <el-button type="primary" :icon="DocumentCopy" @click="cpEl('copy1Ref')">复制 MCN 话术</el-button>
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane name="p2">
              <template #label>💻 独立开发者王全栈（P2 中）</template>
              <div class="persona-body">
                <div class="painter-row">
                  <div class="tag-painter">
                    <el-tag type="danger" effect="dark">痛点</el-tag>
                    <span class="txt">按小时计费怕浪费 · 绑信用卡麻烦 · USDT/支付宝想付就付</span>
                  </div>
                  <div class="tag-painter ok">
                    <el-tag type="success" effect="dark">卖点</el-tag>
                    <span class="txt">¥58/月 美国 1C1G · USDT/支付宝/微信随便付 · 按小时开关机 · 一键装 Docker</span>
                  </div>
                </div>
                <div class="copy-box">
                  <div class="copy-title">📱 V2EX/掘金/小红书话术（一键复制）</div>
                  <div class="copy-content" ref="copy2Ref">【独立开发者的美国小黑板 ¥58/月】
全栈兄，做副业不容易——上次上架美区 App Store 还要搬瓦工绑信用卡？

🔥 MetoE：1C1G 美国云 ¥58/月，【USDT / 支付宝 / 微信随便付】，不用绑国际信用卡；按小时计费，不用就关机省 70%；一键装 Docker / Node / Python；IP 提前 48 条黑名单体检，拿过来直接挂 OpenAI / Claude 反代不脏。

👉 专属链接注册送 ¥50 余额（一杯星巴克不到用上一个月）：{{ link }}
GitHub 1k+ star 作者亲测 6 个月稳定，7 天无理由退余额。</div>
                  <el-button type="primary" :icon="DocumentCopy" @click="cpEl('copy2Ref')">复制开发者话术</el-button>
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane name="p3">
              <template #label>📊 数据采集赵工程师（P3 中）</template>
              <div class="persona-body">
                <div class="painter-row">
                  <div class="tag-painter">
                    <el-tag type="danger" effect="dark">痛点</el-tag>
                    <span class="txt">Bright Data 1TB ¥3.8 万贵哭 · 并发掉线率高 · 财务报销对账难</span>
                  </div>
                  <div class="tag-painter ok">
                    <el-tag type="success" effect="dark">卖点</el-tag>
                    <span class="txt">ISP 级 1TB ¥1.5 万（省 60%）· 稳定 1000 QPS · 月度 Excel 报表直接报销</span>
                  </div>
                </div>
                <div class="copy-box">
                  <div class="copy-title">📱 AI 公司/爬虫微信群话术（一键复制）</div>
                  <div class="copy-content" ref="copy3Ref">【爬虫工程师哭了：BrightData 省 60% 方案】
赵工，您现在买 Bright Data / Oxylabs 1TB 流量是不是 ¥3.8 万起步？

🔥 MetoE ISP 级代理池【1TB 仅 ¥1.5 万】，同样的 ASN 覆盖，并发稳定 1000 QPS 掉线率 <1%；爬虫 VPS 5C8G ¥199/月不被 WAF 封；月度用量报表直接导 Excel 给财务报销，6% 专票齐全。

👉 先拿 100GB 免费测 3 天（满意再付费）：{{ link }}
我们团队 10 家 AI 公司客户在用，30 天不满意全额退。</div>
                  <el-button type="primary" :icon="DocumentCopy" @click="cpEl('copy3Ref')">复制采集工程师话术</el-button>
                </div>
              </div>
            </el-tab-pane>
            <el-tab-pane name="p4">
              <template #label>🏢 中小企业陈总（P4 低但 ARPU 高）</template>
              <div class="persona-body">
                <div class="painter-row">
                  <div class="tag-painter">
                    <el-tag type="danger" effect="dark">痛点</el-tag>
                    <span class="txt">200 人全球 OA 访问 · 机场不安全怕财务数据泄露 · 要审计/RAM/发票</span>
                  </div>
                  <div class="tag-painter ok">
                    <el-tag type="success" effect="dark">卖点</el-tag>
                    <span class="txt">主子账号 RAM + 审计日志 180 天 · 6% 专票 + 对公转 · 99.99% SLA 赔付</span>
                  </div>
                </div>
                <div class="copy-box">
                  <div class="copy-title">📱 商会/外贸协会/ERP 渠道话术（一键复制）</div>
                  <div class="copy-content" ref="copy4Ref">【中小企业全球办公：合规才是最便宜的】
陈总，您公司全球 200 人出差访问总部 OA/ERP，现在还在用机场？一旦财务数据泄露谁承担责任？

🔥 MetoE 企业版：主子账号 RAM 权限隔离 + 敏感操作审计日志保留 180 天 + 6% 增值税专票 + 对公转账合同齐全；20 个全球优化节点（CN2 GIA / 软银）+ 99.99% SLA 写进合同（超 1 分钟赔 ¥100）；签 1 年送 2 个月。

👉 预约我司方案经理上门演示（深圳/东莞/宁波 24h 到）：{{ link }}
标杆客户：10+ 年营收 5000 万+ 制造/外贸企业，审计日志过海关稽查 0 问题。</div>
                  <el-button type="primary" :icon="DocumentCopy" @click="cpEl('copy4Ref')">复制企业客户话术</el-button>
                </div>
              </div>
            </el-tab-pane>
          </el-tabs>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover" class="level-card">
          <template #header><b>🏆 分销等级 · {{ level.name }}</b></template>
          <div class="lvl-row">
            <div class="lvl-badge" :style="{ background: level.bg }">
              <el-icon :size="30" color="#fff"><Medal /></el-icon>
            </div>
            <div class="lvl-info">
              <div class="lvl-name">{{ level.name }} <el-tag v-if="50 - stats.invitees > 0" size="small" type="warning">再邀请 {{ 50 - stats.invitees }} 人升金牌 · 返佣 30%</el-tag><el-tag v-else size="small" type="success" effect="dark">🎉 已达金牌返佣 30%</el-tag></div>
              <div class="lvl-rate muted small">当前返佣率：首充 <b class="ok">{{ level.first }}</b> / 复购 <b class="ok">{{ level.recur }}</b> / 金牌 <b class="vip">30%</b></div>
              <el-progress :percentage="Math.min(100, Math.round(stats.invitees/50*100))" :stroke-width="10" :status="stats.invitees>=50?'success':''" style="margin-top: 8px;" />
            </div>
          </div>
          <el-divider />
          <el-steps :active="Math.max(0, Math.min(3, Math.floor(stats.invitees/12.5)))" direction="vertical" finish-status="success" size="small">
            <el-step title="L1 青铜（0-10 人）· 首充 15% / 复购 8%" description="注册即用 · 满 ¥100 周结" />
            <el-step title="L2 白银（10-50 人）· 首充 20% / 复购 12%" description="赠 20 张 ¥100 体验卡 · 月度结算" />
            <el-step title="L3 金牌（50 人 或 月佣 ¥3000+）· 首充 30% / 复购 15%" description="0 成本获客 100 张体验卡 · 团队管理奖 2% · T+1 到账" />
            <el-step title="L4 钻石（500 人 或 月佣 ¥3 万+）· 首充 30% + 团队 5%" description="白标定制 · 方案经理 1v1 · 季度奖金池" />
          </el-steps>
        </el-card>
        <el-card shadow="never" class="share-card" style="margin-top: 16px;">
          <template #header>
            <div class="card-header">
              <b>🔗 我的推广链接 / 二维码</b>
              <el-tag type="success" effect="light" round>永久有效 · 不限点击</el-tag>
            </div>
          </template>
          <div class="link-row">
            <el-input v-model="link" size="large" readonly>
              <template #append>
                <el-button type="primary" :icon="DocumentCopy" @click="cp(link)">复制链接</el-button>
              </template>
            </el-input>
          </div>
          <div class="qr-row">
            <div class="qr-box">
              <div class="qr-ic">
                <el-icon :size="64" color="#3b82f6"><DataBoard /></el-icon>
              </div>
              <div class="qr-txt muted small">扫码注册 · 首单 8 折 + ¥50 余额</div>
            </div>
            <div class="poster-hint">
              <h3>🎨 生成专属海报</h3>
              <div class="ph-list muted small">
                <div>• 横版 / 竖版 / 方形 · 适配朋友圈 / 小红书 / 公众号</div>
                <div>• 自动合成头像 + 昵称 + 邀请二维码 + Persona 话术</div>
                <div>• 8 套模板（跨境蓝 / 活力橙 / 企业黑…）+ 自定义背景</div>
              </div>
              <div class="ph-row">
                <div v-for="(p, i) in posters" :key="i" class="poster" :style="{ background: p.bg }">
                  <el-tag v-if="p.tag" size="small" type="danger" effect="dark">{{ p.tag }}</el-tag>
                  <div class="p-name">{{ p.name }}</div>
                  <el-button link size="small" type="primary">预览</el-button>
                </div>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" style="margin-top: 16px;">
      <el-col :span="12">
        <el-card shadow="never" class="list-card">
          <template #header>
            <div class="card-header">
              <b>👥 我的邀请好友（共 {{ stats.invitees }} 人）</b>
              <el-input size="default" placeholder="搜索好友昵称/ID" style="width: 220px;" clearable>
                <template #prefix><el-icon><Search /></el-icon></template>
              </el-input>
            </div>
          </template>
          <el-table :data="invitees" size="default" stripe>
            <el-table-column label="用户" min-width="200">
              <template #default="{ row }">
                <div class="usr">
                  <el-avatar :size="34" :style="{ background: row.bg }">{{ row.name.charAt(0) }}</el-avatar>
                  <div>
                    <div><b>{{ row.name }}</b><el-tag size="small" effect="plain" style="margin-left: 6px;" :type="row.vip?'warning':'info'">{{ row.vip ? '企业' : (row.tier==='p0'?'电商':(row.tier==='p1'?'社媒':(row.tier==='p2'?'开发者':(row.tier==='p3'?'数据':'—')))) }}</el-tag></div>
                    <div class="muted small mono">{{ row.id }}</div>
                  </div>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="注册时间" width="150">
              <template #default="{ row }">{{ row.createdAt }}</template>
            </el-table-column>
            <el-table-column label="首充" width="110" align="right">
              <template #default="{ row }"><b :class="{ ok: row.first }">{{ row.first ? '¥' + row.first : '—' }}</b></template>
            </el-table-column>
            <el-table-column label="累计消费" width="130" align="right">
              <template #default="{ row }"><b>¥ {{ row.total }}</b></template>
            </el-table-column>
            <el-table-column label="贡献佣金" width="130" align="right">
              <template #default="{ row }"><b class="ok">¥ {{ row.comm }}</b></template>
            </el-table-column>
          </el-table>
          <div class="pager"><el-pagination layout="total, prev, pager, next" :total="stats.invitees" background small /></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="never" class="list-card">
          <template #header>
            <div class="card-header">
              <b>💰 佣金流水（累计）</b>
              <el-tabs v-model="tab" size="small">
                <el-tab-pane label="全部" name="all" />
                <el-tab-pane label="首充佣金" name="first" />
                <el-tab-pane label="复购佣金" name="recur" />
                <el-tab-pane label="提现" name="wd" />
              </el-tabs>
            </div>
          </template>
          <el-table :data="comms" size="default" stripe>
            <el-table-column label="时间" width="150">
              <template #default="{ row }">{{ row.time }}</template>
            </el-table-column>
            <el-table-column label="类型" width="110">
              <template #default="{ row }">
                <el-tag size="small" effect="light" :type="row.tt">{{ row.type }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="来源用户" min-width="140">
              <template #default="{ row }"><span v-if="row.from">{{ row.from }}</span><span v-else class="muted small">—</span></template>
            </el-table-column>
            <el-table-column label="金额" width="130" align="right">
              <template #default="{ row }">
                <b :class="{ ok: !row.wd, danger: row.wd }">{{ row.wd ? '-' : '+' }} ¥ {{ row.val }}</b>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="100" align="center">
              <template #default="{ row }">
                <el-tag v-if="row.status==='ok'" type="success" size="small" effect="light">已到账</el-tag>
                <el-tag v-else-if="row.status==='pending'" type="warning" size="small" effect="light">待结算</el-tag>
                <el-tag v-else type="info" size="small" effect="light">处理中</el-tag>
              </template>
            </el-table-column>
          </el-table>
          <div class="pager"><el-pagination layout="total, prev, pager, next" :total="486" background small /></div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
<script setup>
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Share, Present, PictureFilled, Wallet, DocumentCopy, DataBoard,
  Medal, Search
} from '@element-plus/icons-vue'

const link = ref('https://www.metoe.io/invite?u=ADM-8826-GO')
const tab = ref('all')
const activePersona = ref('p0')
const posters = [
  { name: '跨境蓝 · 朋友圈', tag: '热', bg: 'linear-gradient(135deg,#3b82f6,#8b5cf6)' },
  { name: '活力橙 · 小红书', bg: 'linear-gradient(135deg,#f59e0b,#ef4444)' },
  { name: '自然绿 · 微信群', bg: 'linear-gradient(135deg,#10b981,#0ea5e9)' },
  { name: '商务黑 · 企业渠道', tag: '新', bg: 'linear-gradient(135deg,#111827,#374151)' },
]
const level = reactive({
  name: 'L2 白银分销员', first: '20%', recur: '12%', vip: '30%',
  bg: 'linear-gradient(135deg,#facc15,#f59e0b)',
})
const stats = reactive({
  totalComms: 88426, availComms: 3280, withdrawn: 72160, wdCount: 48,
  invitees: 36, newInvitees: 12,
})
const bgs = [
  'linear-gradient(135deg,#3b82f6,#2563eb)','linear-gradient(135deg,#10b981,#059669)','linear-gradient(135deg,#f59e0b,#d97706)',
  'linear-gradient(135deg,#8b5cf6,#7c3aed)','linear-gradient(135deg,#ef4444,#dc2626)',
]
const names = ['深圳·张店长','广州·李运营','杭州·王全栈','上海·赵工','宁波·陈总','东莞·刘主管','义乌·孙老板','成都·周运营']
const tiers = ['p0','p1','p2','p3','p4','p0','p0','p1']
const invitees = Array.from({ length: 8 }).map((_, i) => ({
  id: `USR${String(100000 + i*13).padStart(6,'0')}`,
  name: names[i], bg: bgs[i % bgs.length], vip: i === 4, tier: tiers[i],
  createdAt: new Date(Date.now() - i * 86400000 * 4).toLocaleString('zh-CN', { hour12: false }).slice(5),
  first: i % 3 === 0 ? '' : (100 + i * 50).toString(),
  total: (500 + i * 1888).toLocaleString(),
  comm: (20 + i * 86 + Math.random() * 50).toFixed(2),
}))
const types = [
  { t: '首充奖励 15%', tt: 'success' }, { t: '复购返佣 8%', tt: 'primary' },
  { t: '团队管理奖 2%', tt: 'warning' }, { t: '活动加成 150%', tt: 'danger' },
  { t: '提现到支付宝', tt: 'info' }, { t: '提现到微信', tt: 'info' },
]
const comms = Array.from({ length: 8 }).map((_, i) => {
  const wd = i === 4 || i === 7
  const tp = types[i % types.length]
  const vals = wd ? [1000, 2000, 3000, 500, 2500] : [280, 660, 1200, 1880, 3200, 4660, 8200, 10200]
  return {
    time: new Date(Date.now() - i * 3600 * 1000 * 12).toLocaleString('zh-CN', { hour12: false }).slice(5),
    type: tp.t, tt: tp.tt,
    from: wd ? '' : names[(i+2) % names.length],
    val: (wd ? vals[i % 5] : (vals[i]/100)).toFixed(2),
    wd,
    status: i < 3 ? 'ok' : (i < 6 ? 'pending' : 'process'),
  }
})
function cp(t) { navigator.clipboard.writeText(t); ElMessage.success('✅ 已复制到剪贴板·直接去微信群/朋友圈粘贴就行') }
function cpEl(refName) {
  const el = window.document.querySelector('[ref="' + refName + '"]') || window.document.getElementById(refName) || (function(){
    const map = { copy0Ref: 2, copy1Ref: 5, copy2Ref: 8, copy3Ref: 11, copy4Ref: 14 }
    const idx = map[refName] ?? 2
    return document.querySelectorAll('.copy-content')[idx]
  })()
  if (el && el.innerText) {
    navigator.clipboard.writeText(el.innerText).then(()=>ElMessage.success('✅ 话术已复制·粘贴即发'))
  } else cp(link.value)
}
function showLink() { cp(link.value) }
</script>
<style scoped>
.page-wrap { padding: 4px 2px 30px; }
.hero-card, .share-card, .level-card, .list-card, .persona-card { border-radius: 14px; }
.hero-card { background: linear-gradient(135deg,#faf5ff 0%,#eff6ff 50%,#ecfdf5 100%); border: none; }
.hero-row { display: flex; gap: 20px; align-items: flex-start; }
.hero-l { flex: 1; min-width: 0; }
.hero-title { display: flex; align-items: flex-start; gap: 12px; flex-wrap: wrap; margin-bottom: 10px; }
.hero-title h1 { margin: 0; font-size: 26px; color: #6b21a8; font-weight: 800; letter-spacing: -0.5px; }
.slogan-sub { margin: 4px 0 0; font-size: 13px; color: #7c3aed; font-weight: 600; letter-spacing: 0.3px; }
.hero-title .tag { font-weight: 700; }
.hero-sub { line-height: 1.9; margin-bottom: 18px; }
.hero-sub b.hl { color: #dc2626; }
.hero-sub b.hl2 { color: #b45309; }
.hero-sub .trust { display:inline-block; margin-top:8px; padding: 4px 10px; background:rgba(16,185,129,.12); color:#047857; border-radius:20px; font-size: 12.5px; font-weight:600; }
.hero-actions { display: flex; gap: 10px; flex-wrap: wrap; }
.hero-r { width: 500px; min-width: 440px; }
.h-box {
  padding: 14px 16px; border-radius: 12px; margin-bottom: 12px;
}
.h-box.ok { background: linear-gradient(135deg,#ecfdf5,#d1fae5); }
.h-box.prim { background: linear-gradient(135deg,#eff6ff,#dbeafe); }
.h-box.warn { background: linear-gradient(135deg,#fff7ed,#fed7aa); }
.h-box.info { background: linear-gradient(135deg,#faf5ff,#ede9fe); }
.hb-lbl { margin-bottom: 4px; }
.hb-val { font-size: 26px; font-weight: 800; color: #111827; letter-spacing: -0.5px; }
.hb-val .unit { font-size: 13px; color: #6b7280; margin-left: 4px; font-weight: 500; }
.hb-foot { font-size: 12px; margin-top: 6px; color: #374151; }
.hb-foot.up { color: #059669; }

.card-header { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
.link-row { display: flex; align-items: center; gap: 10px; }
.link-row .el-input { flex: 1; }
.qr-row { display: flex; gap: 20px; margin-top: 18px; }
.qr-box {
  width: 180px; height: 210px; padding: 14px;
  background: #fff; border-radius: 14px; text-align: center;
  border: 1px dashed #d1d5db; display: flex; flex-direction: column; justify-content: space-between; align-items: center;
}
.qr-ic {
  width: 140px; height: 140px;
  background: linear-gradient(135deg,#eff6ff,#ecfdf5); border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
}
.poster-hint { flex: 1; }
.poster-hint h3 { margin: 0 0 10px; color: #111827; }
.ph-list { line-height: 1.9; margin-bottom: 14px; }
.ph-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
.poster {
  aspect-ratio: 3/4; border-radius: 10px; padding: 8px;
  color: #fff; display: flex; flex-direction: column; justify-content: space-between; align-items: flex-start;
  position: relative; cursor: pointer;
  transition: all .2s ease;
}
.poster:hover { transform: translateY(-2px); }
.p-name { font-weight: 700; font-size: 12px; }

.persona-tabs :deep(.el-tabs__header) { margin-bottom: 14px; }
.persona-body { padding: 6px 4px 2px; }
.painter-row { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 14px; }
.tag-painter {
  flex: 1 1 320px; display: flex; align-items: flex-start; gap: 8px;
  padding: 10px 12px; border-radius: 10px;
  background: linear-gradient(135deg, rgba(239,68,68,.08), rgba(249,115,22,.08));
  border: 1px solid rgba(239,68,68,.18);
}
.tag-painter.ok {
  background: linear-gradient(135deg, rgba(16,185,129,.08), rgba(14,165,233,.08));
  border: 1px solid rgba(16,185,129,.22);
}
.tag-painter .txt { color:#374151; line-height:1.7; font-size: 13.5px; }
.copy-box {
  background: linear-gradient(135deg,#f9fafb,#f3f4f6);
  border: 1px dashed #9ca3af; border-radius: 12px; padding: 14px 16px;
}
.copy-title { font-weight: 700; color:#111827; margin-bottom: 8px; }
.copy-content {
  background: #fff; border:1px solid #e5e7eb; border-radius:8px; padding: 12px 14px;
  white-space: pre-wrap; line-height: 1.85; color:#1f2937; font-size: 13.5px;
  max-height: 280px; overflow: auto; margin-bottom: 10px;
}

.lvl-row { display: flex; gap: 14px; align-items: center; }
.lvl-badge { width: 72px; height: 72px; border-radius: 16px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; box-shadow: 0 10px 20px rgba(245,158,11,0.3); }
.lvl-name { font-size: 16px; font-weight: 800; color: #111827; margin-bottom: 4px; }
.lvl-rate b.ok { color: #059669; }
.lvl-rate b.vip { color: #7c3aed; }

.usr { display: flex; align-items: center; gap: 10px; }
b.ok { color: #059669; }
b.danger { color: #dc2626; }
.pager { margin-top: 14px; display: flex; justify-content: flex-end; }
.mono { font-family: Consolas, Monaco, monospace; }
.muted { color: #6b7280; } .small { font-size: 12px; }
</style>
