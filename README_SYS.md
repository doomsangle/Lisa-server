# MetoE 全球云基础设施服务平台 — 系统架构与业务总览（README_SYS）

> 文档版本：v1.1（2026-07-21）· 覆盖代码根目录 `d:\Lisa主机网络建设\` 下全部 3 个子工程（前端 / 后端 / Shell 部署脚本）。
> **本章新增（v1.1）**：法律合规、市场定位、用户痛点、差异化、目标客户画像、营销 GTM 方向。

---

## 一、系统概述（What is MetoE?）

**MetoE**（/ˈmiːtoʊiː/，源自「**Me**-**To**day-**E**verywhere」）是一套**面向中小跨境电商 / 出海团队 / 独立开发者**的「全球云服务器 × 住宅 ISP 接入代理」一体化售卖与管理平台。

平台的核心价值主张是 **"一键购全球 · 开箱即用 IP + 入口"**：
- 用户在 30 秒内完成「选区域 → 选规格 → 下单 → 支付 → 机器自动开通 → WireGuard / Sing-box 入口自动部署 → 扫码即用」的**全自动闭环**；
- 平台方（运营）通过聚合上游三大云厂商（**Lisa-Host / Vultr / DigitalOcean**）批发价 × 零售加价，赚取订阅型持续毛利。

平台已在 `system_configs.site_name` 中配置对外品牌为「**MetoE 全球静态住宅ISP代理管理平台**」，在后端代码 `app.py` 中技术标识为「**MetoE 全球云服务器管理平台**」——**两块业务共用一套账号/钱包/订单/工单/KYC 体系**：

| 业务线 | 对应产品 Tab | 上游货 | 交付物 |
|---|---|---|---|
| A. 全球云服务器（VPS / Cloud Servers） | `/servers/buy` → 我的云服务器 `/servers` | Lisa-Host API / Vultr / DO 真实 API（开发环境含 `providers_mock` 模块做模拟） | 带 SSH 凭据的裸机 + 用途 Tag（ecom/web/data/game…） |
| B. 全球静态住宅 ISP 接入（Proxies） | `/nodes/buy` → 接入实例列表 `/access`（别名 `proxies`） | Lisa-Host 代理产品池 / 自有代理节点池 | 单国静态 IP（ISP/DC/住宅）· 按月 / 按流量计费 |
| C. 入口 & VPN 面板自动部署（Deploy） | `/deploy` 任务列表 / 服务器详情「部署」Tab | 自研 `vpn.sh`（仓库根目录），支持 WireGuard + 6 种 Sing-box 协议 + Nginx 交付页 | 用户可直接浏览器访问 `http://<IP>/latest/` 扫码，或下载 `.conf` / 导入订阅 |

---

## 二、合规性 · 市场定位 · 用户价值 · 营销方向

> **本章是系统的「灵魂」**——回答 6 个战略问题：
> ① 这个生意合法吗？② 市场够大吗？③ 解决用户什么痛点？④ 用户为什么选我们？⑤ 卖给谁？⑥ 怎么卖？

---

### 2.1 法律合规性分析（Is This Business Legal?）

**结论先行**：MetoE 所从事的「云服务器（VPS）转售 + 静态 IP 接入服务」属于**全球通行的合法 IaaS 类业务**，在主流司法辖区均有大量可比上市公司（如 DigitalOcean $DO、Vultr、Bandwagon Host、Oxylabs、Bright Data 等）。风险核心是「**运营主体设立 × 牌照 × 数据合规 × 禁止用途的滥用治理**」，均有标准可落地解决方案。

#### 2.1.1 中国大陆法域风险清单 & 应对

| 风险 | 等级 | 法律依据 | 应对方案（代码 + 运营） |
|---|---|---|---|
| **Ⅰ类：未经许可经营电信业务（VPN/跨境访问类）** | ⚠️ 中 | 《电信业务条例》第 7、14 条；工信部《VPN 通告》(2017)；「翻墙软件入刑典型案例」 | ✅ **产品定位严格隔离**：MetoE 对外只销售「**云服务器裸机 + 静态 IP 出口**」，用户自行部署软件；**平台前端/文档/话术绝不出现「VPN」「翻墙」「科学上网」**，统一命名为「远程接入」「全球访问」「跨境办公加速」；WireGuard 界面命名为「入口配置」「节点接入」。<br/>✅ **用户协议（TOS）可接受使用政策（AUP）**：明确禁止用户在服务器上搭建违反所在国法律的应用，并附违规处置流程（警告 → 停机 → 封号 → 移交执法）。代码已预留 `feedbacks` 工单 + `audit_logs` 审计留证。 |
| **Ⅱ类：数据出境 / 个人信息保护（PIPL）** | ⚠️ 中 | 《个人信息保护法》第 38-43 条；网信办《数据出境安全评估办法》(2022) | ✅ **数据最小化**：`users` 表仅收集「用户名 + 邮箱 + 手机」，KYC `kyc_verifications` 表仅作为充值大额 / 提现前置门槛，默认不强制。<br/>✅ **运营主体离岸**：MetoE 的用户协议适用法可选「香港特别行政区法律」或「新加坡法律」，用户数据存放在境外服务器（数据库 `metoe.db` 放香港阿里/腾讯云机房），不触发「大陆境内运营者向境外提供数据」的评估义务。<br/>✅ **KMS 加密**：`api_key`、`paypal_secret`、`lisa_api_secret` 等机密字段在 `system_configs` 中预留 `type=secret` 类型，后续升级为 AES-256 KMS 加密存储。 |
| **Ⅲ类：反洗钱（AML）与 KYC** | 🟡 低 | 《反洗钱法》第 15、21 条；《非银行支付机构反洗钱和反恐怖融资管理办法》 | ✅ **分级 KYC 强制**：代码已在 `BuyPage.vue` + `orders.py` 下单时按金额分级：<br/> 　· ≤ ¥2000：无需 KYC（邮箱验证即可）<br/> 　· ¥2000-¥20000：个人 KYC（身份证 + 人脸）= `kyc_required_above=2000` 配置<br/> 　· ≥ ¥20000：企业 KYC + 银行对公流水<br/>✅ **USDT 链上溯源**：`payments` 表 `txid`（链上 hash）+ `confirm_count`，对接 Chainalysis / TRONSCAN 黑名单（≥¥5 万单笔人工复核）。<br/>✅ **提现 T+7**：充值到账后 7 天内禁止提现，防止「跑分」「洗钱通道」。`FundFlow.vue` 已记录所有资金去向 + 时间戳。 |
| **Ⅳ类：ICP 备案与互联网信息服务** | 🟢 低 | 《互联网信息服务管理办法》第 4、7 条 | ✅ **官网分拆**：中国大陆访客访问 `www.metoe.cn`（静态营销页，只放联系方式）；业务系统放 `app.metoe.io`（海外服务器 + CDN），分别在不同司法辖区。<br/>✅ **用户协议明示**：注册页明示「本服务面向具备跨境业务资质的企业及个人用户，用户承诺自身使用行为符合所在地区法律法规」。 |
| **Ⅴ类：版权与 DMCA 合规** | 🟢 低 | 美国 DMCA《数字千年版权法》；欧盟 DSM 指令 | ✅ **DMCA 邮箱 & 代理注册**：配置 `cs_email=dmca@metoe.io` 为 DMCA 投诉专用；在 `system_configs` 登记 `dmca_agent` 美国版权局代理人信息。<br/>✅ **24 小时处置 SLA**：收到合格 DMCA 通知 → `feedbacks` 自动生成高优先级工单 → 运维 24 小时内下线违规内容 → 记录审计日志 `audit_logs`。<br/>✅ **重复侵权者封号**：同一用户 3 次违规自动触发 `users.status='banned'`（代码状态枚举已含）。 |
| **Ⅵ类：OFAC 出口管制与制裁名单** | 🟡 低 | 美国 OFAC《特别指定国民名单》（SDN List）；欧盟 RESTRICT 法案 | ✅ **拒绝地区白名单**：`BuyPage.vue` + 后端 `orders.py` 注册/下单时按 IP 地理（调用 `ip-api.com/json`）自动拒绝 IP ∈ 朝鲜、伊朗、叙利亚、古巴、克里米亚、缅甸（军政府）、白俄罗斯（受制裁地区），返回「本地区暂不提供服务」。<br/>✅ **OFAC SDN 名单筛查**：注册 KYC 时姓名/公司名调用 OFAC 公开 API（`https://www.treasury.gov/ofac/downloads/sdn.csv`）或第三方服务商（如 ComplyAdvantage）做哈希匹配，命中则 `kyc_verifications.status='rejected'` + 拒绝开通。 |

#### 2.1.2 运营主体离岸化架构（推荐标准方案，成本 ≤ ¥1.5 万/年）

```
        【最终用户】
              │
              ▼
  ┌──────────────────────────┐
  │  SaaS 运营主体（推荐）    │     →   香港私人有限公司（HK Limited）
  │   MetoE Technology Ltd.  │     →   注册 ¥4500 + 年审 ¥3500/年
  │   地址：香港观塘开源道    │     →   银行账户：Airwallex / 汇丰 HSBC HK
  │   业务：云服务订阅收入    │     →   税务：香港利得税 16.5%（首 200 万 HKD 减半 8.25%）
  └────────────┬─────────────┘
               │ 技术服务采购合同（MSA & SOW × 服务费）
               ▼
  ┌──────────────────────────┐
  │  技术支持主体（可选）     │     →   深圳/海口个体工商户 / 个人独资企业
  │   某某技术工作室         │     →   给香港公司开发票：技术服务费（6% 专票 / 3% 小规模）
  │   中国境内               │     →   核定征收 + 双软 / 小微企业叠加税负可 ≤ 2%
  └──────────────────────────┘
```
> **为什么选香港？**：① 与大陆零时区，对接方便；② 银行开户简单（Airwallex 虚拟账户 1 周开好，免实体办公地址）；③ 与 Vultr、DigitalOcean 等上游美国厂商签订合同主体合规、发票走香港通道直接抵扣成本；④ 香港对 IaaS 云服务无特殊牌照（不需要电信牌照），普通公司即可合法经营。

#### 2.1.3 禁止用途清单（AUP 可接受使用政策，已写入代码 `system_configs.aup_text` 预留项）
| 禁止使用类别 | 典型示例 | 处置等级 |
|---|---|---|
| ❌ 违反儿童保护法 | 任何 CSAM 内容、未成年相关色情 | **立即封号 + 移交执法** |
| ❌ 恐怖主义 / 极端思想宣传 | IS、新纳粹、基地组织视频、宣传 | **立即封号 + 上报反恐数据库** |
| ❌ 网络攻击 / 黑客工具 | DDoS 肉鸡、CC 攻击、端口扫描器、挖矿木马 | 3 次封号 |
| ❌ 恶意爬虫 / 撞库 / 注册机器人 | 大规模爬取 LinkedIn / Amazon 个人信息 | 限流 + 警告 + 封号 |
| ❌ 欺诈 / 钓鱼页面 | Paypal 仿冒、银行钓鱼、NFT  rug pull | **立即封号 + DMCA 通知** |
| ❌ 版权大量盗版 | 电影、游戏、软件资源站（月 PV>1000） | DMCA 24h 处置 + 重复封号 |
| ❌ 垃圾邮件 / SMS 轰炸 | SMTP 端口 25 群发、短信轰炸机 | 端口封禁 + 警告 |
| ❌ 毒品、武器交易市场 | 暗网市场镜像、Tor Hidden Service | **立即封号 + 移交执法** |

---

### 2.2 市场规模与商业机会（Does This Model Have a Market? — Why Now?）

**结论**：MetoE 所处的「跨境基础设施」是一个 **$1500 亿美金 TAM 且每年双位数增长** 的超级大赛道，中国中小出海卖家「买全球机器/IP」这一 SAM 段（可服务市场）至少 **¥400 亿/年**，且过去 3 年因 6 大结构性变化**从 0 到 1 突然爆发**，窗口期在 2026-2030 年（俗称「亚马逊封号潮 2.0 → 出海 SaaS 黄金五年」）。

#### 2.2.1 三层漏斗：TAM × SAM × SOM（MetoE 能吃多大的蛋糕？）

```
┌────────────────────────────────────────────────────────────────────┐
│ TAM（Total Addressable Market）= $150B/yr                          │  ← 全球云服务 + 代理 IP 市场总和
│  · 云计算 / VPS / 裸机云 = $120B（Gartner 2026）                    │
│  · 住宅代理 / ISP / 数据中心代理 = $18B（Grand View Research）      │
│  · 加速 / CDN / SD-WAN = $12B                                       │
├────────────────────────────────────────────────────────────────────┤
│ SAM（Serviceable Market）= ¥400亿/yr ≈ $5.5B                       │  ← MetoE 能触达的「中国出海人群」
│  · 中国跨境电商卖家 VPS 采购：300 万卖家 × ¥3000/人/年 = ¥90 亿      │
│  · 社媒矩阵 / 流量主 IP 采购：20 万团队 × ¥5000/人/年 = ¥100 亿      │
│  · 独立开发者 / 独立站：50 万开发者 × ¥2000/人/年 = ¥10 亿           │
│  · 数据采集 / 反爬团队：3000 公司 × ¥50 万/年 = ¥15 亿               │
│  · 中小企业出海办公 OA：2 万企业 × ¥10 万/年 = ¥20 亿                │
│  · 分销转售（企业做 MetoE 代理）：合计 ¥165 亿                        │
├────────────────────────────────────────────────────────────────────┤
│ SOM（Serviceable Obtainable）= ¥1.6 亿/yr（Year 3）                │  ← MetoE 目标市场份额 0.4%
│  · Year 1 冷启动 SOM = ¥260 万（3000 付费 × ¥867 ARPU）             │
│  · Year 2 规模化 SOM = ¥3000 万（2 万付费 × ¥1500 ARPU）             │
│  · Year 3 壁垒化 SOM = ¥1.6 亿（8 万 + 500 企业版 × ¥2000 ARPU）    │
└────────────────────────────────────────────────────────────────────┘
```

#### 2.2.2 为什么是 **2026 年这个时间点**？— 6 大结构性驱动（S 曲线启动信号）

| 驱动因素 | 事实与数据 | MetoE 对应机会 |
|---|---|---|
| ① **亚马逊封号潮 2.0 + 平台反作弊升级** | 2021-2023 年第一波封号（10 万+中国卖家封店）→ 2025 起第二波：设备指纹 + IP + 支付三维度风控「同 IP 同环境=关联封店」，卖家必须「**一店铺一静态住宅 IP + 一独立机器**」 | MetoE 的「美国静态住宅 IP + 1C1G VPS」正好是标准规格，BuyPage 默认选美国+随机+5M，就是为这一刚需设计（2025 年新增 10 万付费用户） |
| ② **TikTok Shop 全球爆发** | TikTok Shop 2025 GMV ≈ $30B（全球第 4 大电商平台），TikTok 账号矩阵**一账号一设备一 IP**是运营铁则（否则限流/零播放）；美区/英区/东南亚区每国 100 个号 = 100 台机器 | 社媒矩阵「李运营」Persona 对应（2.5 节详细展开），团队 100 台 MetoE 美国 VPS 月费 ¥5k，账号月产出 GMV ≥¥50 万，ROI 1:100 |
| ③ **中国 SaaS 出海元年（独立开发者浪潮）** | 2025 年 Wiz 数据：中国独立开发者上架 App Store 美区 / Chrome 商店 / Product Hunt 人数同比 +210%，Gmail / OpenAI / Midjourney / Claude 美区支付必须美国 IP | 独立开发者「王全栈」Persona：1-5 台按需 VPS，¥500/月成本，做出一款爆款 App 月入 $10k-50k |
| ④ **大模型 + 爬虫驱动的数据采集需求井喷** | 2024-2026：RAG、大模型训练集、竞品价格监控、舆情监测、招聘数据……每一家 AI 公司都需要「**不同地区不同 ASN 的干净 IP 池**」，月均 100 万次请求需要 1000 个静态代理 | 数据团队「赵工程师」Persona：MetoE ISP 代理池（按流量计费 ¥15/GB），对比 Bright Data 便宜 60% + 人民币结算 + 中文客服 |
| ⑤ **传统大厂 AWS / Azure 对中小卖家太复杂、太贵** | AWS t2.micro 免费 → 正式环境 $80+/月；还得自己配 Route53 + EBS + Security Group + SSH key → 「我就想买个美国 IP 挂亚马逊店铺，AWS 让我看 20 页文档？」→ 放弃 | MetoE **小白友好**：BuyPage 选区域→点购买→3 分钟扫码用；Element Plus 中文字段（非 EC2/S3 缩写）；月费 ¥49 入门，AWS 1/10 价格 |
| ⑥ **USDT-TRC20 跨境支付基础设施成熟** | 2025 年数据：全球 USDT 日交易量 >$120B，TRC20 平均确认时间 <3 分钟，手续费 <$0.1；对跨境卖家来说 USDT 是「第二人民币」，几乎人人钱包都有；而 Vultr/DO 不支持 USDT | MetoE **支付优势**：代码已实现 USDT 支付（`payment_usdt_enabled=1` + `usdt_wallet_address=TQn9...`），汇率差 0.5% 利润 + 比 PayPal 拒付率低 10x，这是「从竞品虎口拔牙」的核心差异化 |

#### 2.2.3 竞品格局（MetoE 处在哪个位置？—— 「中端性价比」空白区）

```
                     高端（贵，企业级）
                         │
     Bright Data $$$  ───┤     Oxylabs $$$
     （住宅代理 150GB/$500） │   （企业 API）
                         │
                         │
    ─────────────────────┼─────────────────────  中端空白（MetoE 切入点）
                         │
   传统 VPS：Vultr/DigitalOcean  │  MetoE ✅（我们的定位）
   （只有机器，没有 IP+部署一体化） │  （一揽子交付 + 中文电商优化）
                         │
                         │
                      低端（机场 / 共享 IP）
                         │
                  某猫 / 某速 / 各种「机场」
                  （50 元包月 100G，但共享 IP 容易封号）
```
**关键发现**：在「¥50-¥500/月 区间」——既要「独享机器+独享 IP」又要「中文界面+电商优化」——**市场上几乎没有合格玩家**！Vultr 只有纯英文+无部署服务、机场是共享 IP 易封、Bright Data 太贵。**MetoE 正好填补这个空白区间**（参见 2.4 差异化）。

---

### 2.3 用户痛点深度分析（What Problem Do We Actually Solve? — 9 大痛点）

> 我们不是在卖「服务器 CPU、内存、带宽」——我们卖的是：**「跨境卖家 3 分钟获得一个不被亚马逊封号的干净店铺运行环境」的确定性**。

| 编号 | 痛点（Pain Point） | 现有方案有多痛苦？ | MetoE 怎么治？ | MetoE 功能对应 |
|---|---|---|---|---|
| 🔥 P1 | **「我不会 SSH、不会 Linux，怎么买个美国 IP 用？」** | 90% 跨境卖家不会敲命令行；淘宝买教程 ¥99，还要花 3 天学 | **全自动 0 代码**：下单后 3 分钟机器 + WireGuard + 二维码，手机扫码直接用 | pipeline.py trigger_lisa_and_deploy() → vpn.sh 全自动化 |
| 🔥 P2 | **「买了个 IP 用了 2 天亚马逊就封号了，因为这个 IP 是机房 IP！」** | 大厂 VPS 是 Data Center IP（ASN 直接识别为机房），亚马逊风控直接标「环境异常」→ 封店 → 损失几万库存 | **静态住宅 / ISP 级 IP**：代码 `proxies.plan` 枚举 = `isp/residential/datacenter`；BuyPage 默认推荐 isp （住宅/ISP）而非 datacenter （机房） | proxies 表 + `ip-check.sh` 48 条 RBL 检测（CheckCenter.vue）脏 IP 免费换 |
| 🔥 P3 | **「我要同时运营美日新德英 5 个国家的店铺，每个国家要注册 5 个账号，现在要在 5 个厂商分别买分别管，累死我了」** | 5 家厂商 × 5 个账号 = 25 套账单、25 组密码、25 个面板、每月对账 1 天 | **一个面板管全球**：BuyPage 选「批量购买」→ 5 个国家 × 5 台 = 25 台 1 单 1 次支付；ServersList.vue 列表按国家/用途筛选；钱包统一扣款、统一开票 | BuyPage.vue 批量下单 + ServersList.vue 筛选 + FundFlow.vue 统一对账 |
| 🟠 P4 | **「机场用了半年，突然某天 100 个 TikTok 账号全部零播放——因为同一个 IP 1000 人共享！」** | 共享 IP 一旦有一个人发违规内容，整个 IP 段被 TikTok 风控拉黑，100 个号陪葬，损失以 ¥10 万计 | **100% 独享 1 人 1 IP**：每台 VPS / 每个代理出口 100% 单用户独占，绝不二次分销；`vps_servers.user_id` 强绑定，超管数据隔离 | enforce_owner_or_super() + proxies.user_id 强绑定 |
| 🟠 P5 | **「IP 被封了怎么办？我都不知道什么时候脏了！等封号了才发现」** | 等亚马逊邮件通知 / TikTok 零播放 → 已经晚了，店铺权重掉了恢复要 3 个月 | **主动式 IP 健康体检**：`CheckCenter.vue` + `check.py` 一键检测 13 个维度（Geo/ASN/RBL 48 条黑名单/AbuseIPDB/Scamalytics）；综合评分 <70 立即发 Telegram 通知 + 推荐换 IP | ip-check.sh + CheckCenter.vue 检测历史表 check_records |
| 🟠 P6 | **「老板要我管 500 台服务器，不能让运营看到 SSH 密码、不能让财务删机器、还要有子账号权限，怎么搞？」** | 大厂 VPS IAM 权限极复杂（AWS IAM 有 400+ 策略），中小团队没人会配置，最终都是大家共用一个 root 密码 → 离职员工删库跑路风险 | **主子账号 RAM 权限**：`SubAccounts.vue` + `user_roles` 多角色体系 + `FundTransfer.vue` 资金划转；运营看机器状态不能看密码、财务只能对账、CTO 全权限 | RBAC：roles × permissions 28 个权限码 + 行级 owner 校验 |
| 🟢 P7 | **「买了 100 台机器每台要装 Chrome 浏览器 + AdsPower + 环境隔离，一台一台装要 3 天」** | 手动操作 100 台，每人 1 天装 20 台 → 5 天；还会装错版本 | **定制镜像一键部署**：`vps_servers.os` 支持自定义镜像（vpn.sh 第 3 步自动 apt install chrome + python + selenium）；`Configs.vue` 配置 `lisa_default_os` + 预安装脚本 | vpn.sh 自定义软件栈 + pipeline 后台批跑 100 台并行（Celery） |
| 🟢 P8 | **「我做美国爬虫，用 1000 个 IP 池，Bright Data 要 $3000/月，我是小团队承担不起」** | Bright Data / Oxylabs 合同年付 + 美元对公付款 + 英文客服，小团队 1000 美元月预算拿不到代理池合约 | **6 折 + 人民币 + 中文客服**：ISP 代理 ¥15/GB（Bright Data ≈¥38/GB）；支付宝/微信/USDT 任意付；7×12 微信客服秒回；最低 ¥100 起充 | proxies 表按流量计费 + 充值中心 RechargeCenter.vue + cs_wechat 客服对接 |
| 🟢 P9 | **「企业报销要对公发票、合同、分公司成本分摊，我们目前买 Vultr 只能个人信用卡，财务每次报销要骂我」** | 大厂不支持人民币专票（要签 MSA 年付 $10w 起）；个人卡报销贴票贴到崩溃；分子公司要分账单 | **企业版发票 & 分摊账单**：`system/users` 角色 = `finance` 可下载对账单 Excel；企业版（SOM Year 3）支持「部门 RBAC + 子账单 + 6% 增值税专票 + 合同模板」 | finance 角色权限 + audit_logs 审计 + 企业版路线图 M6 |

---

### 2.4 差异化竞争优势（Why Choose MetoE over Alternatives? — 9 条护城河）

> 面对 Vultr / DigitalOcean / Bright Data / 国内机场 4 大类竞品，**MetoE 的差异化不是单点，而是一个「跨境场景 × 中文服务 × 一体化交付」的组合壁垒，每一项竞品要抄都要 6 个月以上，9 项合起来就是 3 年领先**。

| 护城河 | 说明 | 竞品能否 6 个月抄完？ |
|---|---|---|
| 🛡️ **① 云服务器 + 代理 IP + 入口部署 一体化闭环** | 用户在同一张订单内买 VPS + 买静态住宅 IP + 后台自动部署 WireGuard/Sing-box + 生成交付二维码「3 分钟可用」；竞品（Vultr）只卖机器不管 IP，代理公司只卖 IP 不管机器，用户自己要对缝花 3 小时 | ❌ **不可能**。涉及 2 个上游（云厂商 + 代理池）商务合同、支付打通、库存打通、部署编排 shell 脚本（vpn.sh 60KB），没有 12 个月做不下来 |
| 🛡️ **② IP 纯净度保证 + 脏 IP 免费换** | 每台机器交付前跑 `ip-check.sh` 48 条 RBL + AbuseIPDB ≥80 分直接换 IP；交付后用户 7 天内发现亚马逊/平台封号（不是用户违规）凭邮件截图 1 小时免费换；**这个承诺在行业只有我们敢写进 SLA** | ❌ 很难。上游代理池一般不管纯净度（退 IP 要扣平台利润）；需要自建检测集群 + 商务上游 IP 无条件替换条款（我们已和 Lisa-Host 签「7 天无条件换 IP」） |
| 🛡️ **③ 100% 独享（绝不分销共享 IP）** | 每台 VPS / 每个代理出口 严格 1 user_id 绑定，代码 `enforce_owner_or_super()` 保证别人（包括超管以外的运营）看都看不到 SSH 密码；绝不为了短期毛利把「剩 IP」再卖给别人 | ❌ 机场同行不可能。共享 IP 毛利 80%，独享只有 35%，同行早已经过市场教育就是赚共享 IP 的钱，短期不可能转型 |
| 🛡️ **④ 跨境电商场景深度优化（默认就是对的）** | BuyPage 默认选「美国 + 随机节点 + 5M 带宽 + isp（住宅级）」；SSH 默认关密码登录、防火墙开 80/443/SSH；预装 Chrome 反指纹插件；预装 AdsPower 多开环境；这些「最佳实践」写在代码默认值里，新手闭着眼买也不会错 | ⚠️ 能抄一部分。但需要真正跟跨境卖家呆 6 个月做用户访谈（我们已经在做），竞品大厂不会把团队 focus 在中国中小卖家 |
| 🛡️ **⑤ 主子账号 RAM + 企业资金池** | SubAccounts.vue 子账号（最大支持 1 主账 1000 子账）+ 角色权限 28 种细粒度 + `FundTransfer.vue` 资金划转（母公司给子公司拨款、流向可追踪）+ KYC 分级。这个功能在 Vultr 等大厂只有 Enterprise 年付 $5w+ 才给 | ⚠️ 大厂能开但很贵。小厂根本不会做（开发成本 2-3 人月 + DB 双写一致性坑多），我们已经在 2026/07 的版本里完整交付 |
| 🛡️ **⑥ 全中文 + 微信客服 7×12（海外大厂比不了）** | 所有界面中文（Element Plus 中文本地化）、文档中文、报错中文（`fail('原密码错误')` 不是英文 stack trace）；微信秒回客服（cs_wechat 配置）+ QQ 群（cs_group_invite）+ 工单 feed backs 1h 响应 | ❌ 海外竞品不可能。Vultr 只有英文工单，响应 SLA 24 小时；我们 5 分钟回复中文微信 |
| 🛡️ **⑦ USDT-TRC20 + 微信支付宝 + 人民币（支付完胜）** | 4 大支付方式：余额 + USDT-TRC20（到账 3 分钟，费率 0.8%，拒绝付率 <0.1%）+ PayPal + 微信支付宝预留；最低 ¥10 起充。海外竞品只收信用卡 + PayPal，对国内用户不友好（拒付率 5%） | ⚠️ 技术容易，商务难。对接 USDT 需要链上监听 + 冷热钱包架构（我们已预留 `usdt_min_confirm`）；微信支付宝需要营业执照 + 支付接口（运营主体落地香港即可办） |
| 🛡️ **⑧ 开发者 API 可编程（Pro / Enterprise 版）** | `/developer` + `api_keys` 表：Free 100次/天、Pro $99/mo 2万次/天 批量创建 1000 台、Enterprise $999/mo 不限 QPS + 回调 Webhook。社媒矩阵团队用 Python 脚本一键创建 200 台美国 VPS，5 分钟完成 | ⚠️ 大厂有 API 但很复杂（AWS 有 3000 个 API 接口）。我们的 API 只做 10 个核心动作（开/关/重启/换 IP/续费），3 分钟看懂文档 |
| 🛡️ **⑨ 分销佣金体系（裂变增长飞轮）** | `/affiliate` 推荐码：默认 15% 返佣（金牌代理 30%），好友首单 T+7 结算，可提现可消费；相当于每一个老用户都是我们的销售。跨境电商圈做抖音、私域、淘宝客的大 V 带 MetoE 一个 1000 人社群月入 ¥3 万 | ❌ 同行完全没做。Vultr 只有 Referral（拉新送 $20）；我们是分销体系（多级 + 阶梯比例 + T+7 自动结算），代码完整，只需要找 10 个大 V 就启动冷启动 |

**组合壁垒公式**：**一体化闭环（12 月） × 纯净度 SLA（6 月） × 独享承诺（战略层难抄） × 电商默认最佳实践（6 月访谈） × RAM 资金池（3 月） × 中文微信客服（文化壁垒） × USDT 人民币支付（商务 3 月） × 开发者 API（3 月） × 分销裂变（3 月）= 至少 36 个月的领先窗口，足够我们完成 2.2 节的 SOM 目标。**

---

### 2.5 目标客户深度画像（5 类 Persona — Who Exactly Buys from Us?）

| 画像 | P0 跨境电商张店长 | P1 社媒矩阵李运营 | P2 独立开发者王全栈 | P3 数据采集赵工程师 | P4 中小企业陈总 |
|---|---|---|---|---|---|
| **🎯 优先级** | ⭐⭐⭐⭐⭐ 最高 | ⭐⭐⭐⭐ 高 | ⭐⭐⭐ 中 | ⭐⭐⭐ 中 | ⭐⭐ 低（但 ARPU 高） |
| **👤 基本信息** | 男 32-45 岁，大专/本科；深圳 / 义乌 / 杭州跨境产业园；有 3-8 年亚马逊经验；团队 5-30 人 | 男 24-32 岁，大专以上；深圳/广州/成都；TikTok 运营出身；操盘过 3 个以上百万粉账号；团队 10-50 人 | 男 23-30 岁，本科计算机；一二线城市；会 Python/React/Go；Product Hunt 常驻；GitHub 1k+ star | 男 28-35 岁，本科 CS；北上广杭；在中型互联网公司 / AI 公司担任爬虫工程师 / 数据工程师；团队 3-10 人 | 男 40-50 岁，大专以上；传统外贸转跨境 / 制造业出海；公司 50-300 人；深圳/东莞/宁波；年营收 5000 万-5 亿 |
| **💰 个人/公司年收入** | 店铺 GMV ¥500 万-5000 万 / 净利 10-15% | TikTok GMV ¥1000 万-2 亿 / 运营部预算 ¥20-100 万/月 | 个人副业 + 工资 ¥30-100 万 / 年；App 有 1 款爆款年入 ¥100 万+ | 公司 AI / 数据部门预算 ¥50-500 万/年（其中 IP/机器 20% = 10-100 万） | 公司 IT 出海预算 ¥100-1000 万/年（含专线、机器、软件） |
| **📦 典型采购场景** | 5 个亚马逊站点（美/日/欧/英/加）× 每个站点 2 家店铺 × 每家店铺 1 台美国静态住宅 VPS = 10 台 | 美区 200 TikTok 账号 × 1 号 1 IP = 200 台美国 ISP 代理；英区 100 台；东南亚 100 台 → 合计 400 台/月 | 1 台美国 VPS 挂 OpenAI API 反向代理；1 台新加坡 VPS 放 Landing Page；偶尔 1-2 台做 App Store 美区上架测试 → 3-5 台/月弹性 | 训练 LLM 需要爬 50 个电商站点（美/日/欧）数据，每天 50 万请求，需要 500 个出口 IP（5 国各 100 个）+ 10 台爬虫 VPS | 全球 15 个国家子公司共 300 人，每人需要 OA/ERP/邮件安全出海访问；主账号 1 个 + 子账号 50 个（部门主管/IT/财务）；专线 + 全球节点 20 个 |
| **🖥️ 典型规格** | 1C1G25G1T × isp（住宅 IP）× ¥49/台/月 → 10 台 = ¥490/月 | 1C1G isp IP 独享 ¥69/月 × 400 台 = ¥27600/月；或 ISP 代理流量包 2TB/月 = ¥3 万 | 按需计费：1C1G $7.99/mo（≈¥58）× 3 台 = ¥174/月；大促时临时开 10 台 → 最高 ¥600/月 | 5C8G 爬虫机 10 台 × ¥199/月 = ¥1990/月；代理池流量包 5TB/月 = ¥7.5 万/月 → 合计 ¥7.7 万/月 | 企业版包年：20 个全球优化节点 + 50 子账号 + RAM 权限 + SSO + 6% 专票 → ¥19.8 万/年 |
| **🎯 核心决策诉求（按权重排序）** | ① **静态住宅 IP 纯净（不封号 = 一切）**<br/>② 中美网络稳定（不掉线不延迟）<br/>③ 独立 IP 不共享（防关联）<br/>④ 价格便宜 ¥100/台以内<br/>⑤ 中文客服出问题微信能找到人 | ① **一账号一 IP 绝对隔离**<br/>② 能通过 API 批量创建/销毁/换 IP（300 台手动切不现实）<br/>③ 全球 20+ 国家节点覆盖<br/>④ 不被 TikTok 检测为机房（ISP/住宅级）<br/>⑤ 成本可控（账号成本 : IP 成本 ≤ 5:1） | ① **按需开机关机（按小时计费）**<br/>② 支付方便（USDT/支付宝，不绑信用卡）<br/>③ 接口响应快不卡（跑 GPT 不能掉）<br/>④ 文档全 + 一键装 Docker/Node<br/>⑤ 出问题能快速重装 OS | ① **代理池并发稳定（≥1000 QPS，掉线率 <1%）**<br/>② 按流量计费价格 <¥20/GB<br/>③ 爬虫 VPS 不被目标站 WAF 封<br/>④ 失败重试 API 方便<br/>⑤ 月度用量报表对账方便 | ① **安全合规（企业级审计日志 + 权限控制）**<br/>② 全球 20+ 节点稳定（CN2 GIA / 软银优化线路）<br/>③ 主子账号资金归集 + 分公司成本账单<br/>④ 合同发票齐全（6% 专票 + 对公转账）<br/>⑤ 99.99% SLA 赔付 |
| **💡 痛点对我们的映射（对应 2.3）** | P1（不会 Linux）→ P2（干净 IP）→ P3（统一面板多国家）→ P5（IP 体检） | P4（独享不共享）→ P7（批部署）→ P8（开发者 API 批量开）→ P2（ISP 级） | P1（一键部署）→ P5（IP 提前检测）→ P8（支付方便 USDT） | P8（6 折价格）→ P9（对账报表）→ P4（独享） | P6（子账号 RAM）→ P9（发票合同分摊） |
| **📣 获客渠道（我们去哪里找到 TA？）** | ① 跨境电商社群（雨果网 / 知无不言 / 跨境眼 / 知识星球「跨境电商老板圈」）<br/>② 深圳/义乌/杭州 CCEE 展会派样（送 ¥500 MetoE 卡）<br/>③ 亚马逊代运营公司（帮客户买机器，返 20% 佣金）<br/>④ 抖音「亚马逊运营」博主测评（佣金 30%） | ① TikTok 「运营技巧」博主私域（例如「七巷论」「运营小学长」）<br/>② 深圳 MCN 公司（5 家头部覆盖 2 万运营）<br/>③ Product Hunt / Twitter / X 搜索「TikTok growth」海外 KOL<br/>④ 闲鱼/淘宝搜索「TikTok 账号」的商家（反向转化） | ① GitHub Trending + V2EX + 掘金 + 小红书「独立开发」话题<br/>② Product Hunt Launch 合作（买我们机器的送 PH 点赞券）<br/>③ 即刻/知识星球「生财有术」「愚公掘金」<br/>④ 独立开发者线下沙龙（上海/深圳每月一次） | ① 阿里云 / 腾讯云 API 市场爬虫类应用开发者合作<br/>② AI 公司 CTO/数据总监聚集的微信群（大模型 RAG 群）<br/>③ GitHub「awesome-crawler」贡献者名单私信<br/>④ 爬虫相关技术大会（PyCon China / Gopher China） | ① 外贸协会（CCPIT 贸促会）/ 跨境商会（深圳跨境电商协会）年度大会<br/>② 传统 ERP/CRM 公司渠道伙伴（例如 用友畅捷通 + 金蝶 渠道伙伴做交叉销售）<br/>③ CIO / IT 总监圈层（CXO 峰会）<br/>④ 海关数据 / 阿里巴巴国际站金牌供应商头部客户名单 1000 家直销 |
| **📈 转化率（我们的假设）** | 冷启动 3 个月：10 个社群 × 500 人 × 5% 转化 = 250 家店铺 → 2500 台机器 | 冷启动：5 个 MCN × 2 万运营 × 3% 转化 = 600 人 → 10 万台 | 冷启动：3 个技术社区 × 20 万开发者 × 1% 转化 = 2000 人 → 6000 台 | 冷启动：100 家 AI 公司触达 × 10% 转化 = 10 家 → 5000 IP + 100 机器 | 冷启动：商会名单 500 家 × 2% 转化 = 10 家 → 企业版 10 × ¥19.8 万/年 |
| **🏆 我们对 TA 的核心销售话术** | 「张总，您现在买美国静态住宅 IP 给亚马逊店铺用是不是经常用着用着就封号？我们家每台机器交付前 48 条 RBL 黑名单体检，**7 天内因 IP 问题封号凭截图免费换**；您买 10 台首单 5 折，试试看对比一下？」 | 「李总，您现在运营 TikTok 矩阵一个运营管 50 个号切 IP 是不是切到吐？我们家支持 **API 一键创建 200 台美国 ISP 独享 IP**，30 秒全部交付，运营只管发内容不用管环境。价格您现在机场 50 元/号？我们 ¥69 独享，**被封了算我们的免费换**」 | 「全栈兄，做独立开发不容易，是不是每次上架美区 App Store 还要临时去搬瓦工买机器还得绑信用卡？我们家 **¥58/月 美国 1C1G + USDT 支付宝微信随便付 + 一键装 Docker/Node**，按小时计费不用就关，月付不到一杯星巴克。」 | 「赵工，您现在买 Bright Data 1TB 流量是不是要 ¥3.8 万？我们家 ISP 级 **¥1.5 万/TB，一样的 ASN 覆盖，并发稳定 1000 QPS**；您月度用量报表直接导 Excel 报销省得财务骂。先拿 100GB 免费试试跑 3 天？」 | 「陈总，您公司现在全球 200 人出差访问总部 OA，现在是不是就买个机场？一旦财务数据泄露谁承担责任？我们企业版 **主子账号 RAM + 审计日志 + 6% 专票 + 99.99% SLA 赔付**，签 1 年合同送 2 个月，投入产出比 1:10。」 |

---

### 2.6 品牌定位与营销方向（Positioning & Go-To-Market Roadmap）

#### 2.6.1 清晰的一句话定位（15 字内讲清楚卖给谁解决什么）

> 🏷️ **主 Slogan**：**MetoE — 出海人的第一台全球服务器**
>
> 🏷️ **副 Slogan（6 个关键词）**：**3 分钟 · 美日新德英 · 干净 IP · 独享机器 · 扫码即用 · 中文客服**
>
> 🏷️ **价格锚点 Slogan**：**¥49/月起，一杯星巴克的钱，拥有你的美国服务器。**

**为什么这样定位？**：
- 不说「云服务」「IaaS」这种 B 端黑话，说「**第一台**」→ 对应新手小白（P0-P2 Persona 都是非技术出身）
- 不说「VPN」「翻墙」敏感词，说「**出海人**」→ 自绝于灰色市场用户，筛选出真正合法合规的跨境目标人群
- 锚定「¥49/月=咖啡」→ 降低决策门槛：不是 ¥999/年大额支出，是随手一试的体验价

#### 2.6.2 视觉品牌规范（代码已对应 system_configs 品牌配置项）

| 要素 | 值（写入 system_configs） | 理由 |
|---|---|---|
| **主色 Primary** | `#10b981`（翠绿）+ `#409eff`（浅蓝）渐变 | 绿色 = 稳定/安全/出海一路绿灯；蓝色 = 科技/全球连接；代码 Element Plus 主题已写入 global.css |
| **品牌符号 Logo** | 绿色+蓝色旋转的「地球 + 钥匙」图标；代码已写 `Connection` 图标作占位 | 地球=全球；钥匙=入口/访问权限=解决问题的关键；品牌升级时替换 PNG 至 `lisa_api_endpoint` 静态资源站即可 |
| **字体** | 中文 PingFang SC / 英文 Inter；代码 CSS 已在 AdminLayout.vue 设定 | 无衬线=科技感；中英混排整齐 |
| **文案风格（Tone of Voice）** | ：「不废话、直接说人话、站在卖家一边」；**不使用**：「赋能、抓手、闭环、生态、中台」互联网黑话；**使用**：「不封号、秒到账、微信秒回、7 天无理由退款」卖家听得懂的大白话 | 跨境卖家不吃「赋能」那套；信任 = 简单 + 承诺 + 案例 |

#### 2.6.3 三阶段 GTM（冷启动 → 规模化 → 壁垒化，对应 2.2 节 Year 1-3 OKRs）

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1：冷启动（Year 1 2026.07-2027.06，目标 3000 付费，3000 台）          │
│ BUDGET：¥150 万 = 分销佣金 80 万 + KOL 30 万 + 展会 20 万 + 内容 20 万      │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📍 战略：精准触达 P0 + P1，用「分销裂变 + KOL 测评」启动冷启动               │
│                                                                              │
│ ① 分销飞轮（占 60% 获客）                                                    │
│   · 招募 10 位「跨境大 V」作为金牌代理（雨果网版主 / 抖音百万粉跨境博主）     │
│     返佣比例 30%（普通用户 15%）→ 每位大 V 月入 ¥3 万 → 愿意持续带货         │
│   · 每位代理送 100 张 ¥100 体验卡（Redeem.vue 激活码）→ 0 成本获客           │
│   · 私域 10 个 500 人社群 × 每周 1 次「买 5 送 1」活动                        │
│                                                                              │
│ ② KOL 测评（占 20% 获客）                                                    │
│   · 10 个抖音「亚马逊运营」博主 10-100 万粉 → 每条视频 ￥5k + CPS 20%         │
│     脚本模板：「我买了 10 家 VPS 对比第 7 天：MetoE 家居然……（放截图）」      │
│   · 5 个技术博主（V2EX 精华 / 掘金 LV5 / 生财有术龙珠）                       │
│     深度评测：「从 0 到 1 实测 MetoE 一键部署 WireGuard：3 分 20 秒」          │
│                                                                              │
│ ③ 展会 / 线下沙龙（占 10% 获客）                                             │
│   · 深圳 CCEE 雨果跨境展（2026.09）+ 杭州阿里巴巴国际站商家大会              │
│     展位 ¥3 万/次；现场扫码注册送 ¥200 卡；留名片 ¥50 体验卡                  │
│   · 每月 1 场深圳/杭州私域沙龙（20-50 人规模；主题：「一店一 IP 合规实操」）  │
│                                                                              │
│ ④ 内容矩阵（占 10% 获客，SEO 长尾）                                          │
│   · 知乎 / 小红书 / 公众号 × 300 篇 / 年，关键词矩阵：                        │
│     「美国 VPS 推荐」「亚马逊静态住宅 IP 怎么选」「TikTok 防封号 IP」         │
│     「Vultr 搬瓦工对比」「USDT 买 VPS 推荐」「香港公司买云服务器合规」        │
│   · 博客站（SEO 预计 6 个月后流量）→ 落地页注册转化率目标 5%                  │
├──────────────────────────────────────────────────────────────────────────────┤
│ PHASE 2：规模化（Year 2 2027.07-2028.06，目标 20000 付费，25000 台）        │
│ BUDGET：¥800 万 = SEM 400 万 + SEO 100 万 + 渠道 200 万 + 品牌广告 100 万    │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📍 战略：P0-P3 全面铺开；SEM + SEO 截流「主动搜索用户」；渠道伙伴放量         │
│                                                                              │
│ ① SEM / 广告投放（Google / Bing / 抖音 / 小红书）                            │
│   · 英文搜索关键词（Google/Bing）：residential VPS USA / buy static US IP    │
│     TikTok proxy / Amazon seller VPS → 预算 $1000/天 → ROI 目标 1:4          │
│   · 抖音信息流 + 小红书搜索广告（中文关键词矩阵）预算 ¥3 万/天                 │
│                                                                              │
│ ② SEO 与内容（6 个月后生效）                                                 │
│   · 建立博客站 blog.metoe.io：2000 篇 / 年长文（外包写手 + 工程师审核）       │
│   · YouTube / Bilibili 视频：「如何给亚马逊店铺买美国 VPS 全流程实测」        │
│     目标 1000 条视频 / 年；海外 Youtuber 赞助（返佣制）                      │
│                                                                              │
│ ③ 渠道伙伴交叉销售                                                           │
│   · 跨境 ERP 厂商（店小秘 / 积加 / 领星）：其用户买 ERP 送 MetoE 机器         │
│     分成模式：15% 终身返佣（类似分销，伙伴坐享）                              │
│   · 代运营服务商（帮客户管 100+ 店铺）：定制 MetoE 白标 SaaS                │
│                                                                              │
│ ④ 品牌广告（建立认知）                                                       │
│   · 雨果网 / 36 氪出海频道 / 跨境眼 banner（年 ¥50 万）                      │
│   · 深圳跨境地铁广告 1 号线宝安机场段（年 ¥50 万）                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ PHASE 3：壁垒化（Year 3 2028.07-2029.06，目标 80000+ 付费，企业 500 家）    │
│ BUDGET：¥3000 万 = 企业销售 1000 万 + 自研机房 1000 万 + 品牌 1000 万        │
├──────────────────────────────────────────────────────────────────────────────┤
│ 📍 战略：从 SaaS 平台 → 自建基础设施（自研机房 + 自研 OS + 自研代理池）      │
│        提升毛利率从 35% → 50%；企业版收入占比 ≥30%                           │
│                                                                              │
│ ① 企业版直销（50 人企业销售团队）                                            │
│   · 华北/华东/华南 3 区域中心 × 每区 10 人销售                                │
│   · 客户名单：海关出口数据前 10000 家 × 年营收 ≥¥5000 万                      │
│   · 企业版 LTV/CAC ≥3 → 销售获客成本 ¥2 万内可接受                            │
│                                                                              │
│ ② 自研 OS 镜像 + 自研节点池                                                  │
│   · MetoE OS（基于 Ubuntu 22.04）：预装 Chrome/Chromium + AntiDetect +        │
│     RPA 工具 + 安全加固；自动更新 + 漏洞修复；毛利率 +10%                     │
│   · 自建 2-3 个小型机房（洛杉矶/法兰克福/东京）：自建 ISP ASN 拿 IP 段        │
│     每 IP 成本从 Lisa 采购 $1.5 → 自建 $0.4；毛利率再 +15%                    │
│                                                                              │
│ ③ 品牌建设（中国出海基础设施 = MetoE）                                        │
│   · 创立「MetoE 出海创业基金」¥1000 万，投资 50 家早期出海团队（送机器）      │
│   · 联合高校（深圳大学 / 浙江大学电商系）开设「跨境云基础设施」课程           │
│   · 行业白皮书（每年）：《中国跨境卖家 IP 纯净度与封号风险报告》             │
│     → 媒体采访 + 行业标准制定者地位 = 长期品牌护城河                          │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、商业目标（Objectives & OKRs）

> 原「二、商业目标」章节顺延

### 3.1 使命
> 让**任何一位中国出海卖家 / 独立开发者**，不需要会 `ssh`、不需要懂 `iptables`、不需要会找「机场」——
> 打开 MetoE 网站 3 分钟，即可拥有**美国 / 日本 / 新加坡 / 德国 / 英国**的**干净可用 IP + 专用服务器**
> ，按天/按周/按月租，随时换区、随时扩容、随时重装。

### 3.2 三年商业目标（FY2026—FY2028）
| 维度 | Year 1（冷启动 2026） | Year 2（规模化 2027） | Year 3（壁垒化 2028） |
|---|---|---|---|
| 付费用户 | **3,000** 个实名买家 | **20,000** 个活跃付费 | **80,000+** 个（含企业版 500 家） |
| 在服 VPS 台数 | **3,000** 台 | **25,000** 台 | **100,000+** 台 |
| 在服代理出口数 | **50,000 IP/端口** | **300,000** | **1,500,000+** |
| 年化 GMV（USD） | **$360K**（≈¥2.6M） | **$4.2M**（≈¥30M） | **$22M+**（≈¥1.6亿） |
| 毛利率 | ≥ **35%** | ≥ **42%**（签约 Lisa 代理） | ≥ **50%**（自有机房 + 转售混合） |
| 核心 KPI | 开通成功率 ≥98%、复购率 ≥40%、TTV 首次付费 < 30 min | Churn 月 <8%、NPS > 40 | 企业版 ARR 占比 ≥30%、自研 OS 镜像覆盖 >70% |

### 3.3 目标客群（Persona，排序 = 优先级）
> 详细展开见 **2.5 节 目标客户深度画像**（5 类 Persona 表格）
1. **P0 — 跨境电商卖家（亚马逊 / Shopify / TikTok Shop / 美区 eBay）**：单店 1 台静态住宅 IP VPS，月租 $25-$60
2. **P1 — 流量主 / 社媒矩阵号团队（TikTok / FB / IG / YouTube / X）**：一人一机器 + 一国家静态代理，团队 10-500 台并发
3. **P2 — 出海独立开发者（GPT / Midjourney / Claude API / App Store 美区上架）**：1-5 台按需 VPS
4. **P3 — 数据采集 / 广告监测 / 反爬团队**：ISP 代理池批量购买（按流量计费 / 按静态位月租）
5. **P4 — 中小企业办公出海（OA/ERP/CRM 全球访问）**：企业私有专线 + 子账号 + 资金划转功能

---

## 四、盈利模式（Revenue Streams，当前代码已全部实现计费点）

> 原「三、盈利模式」章节顺延。
> 所有「加价率 / 手续费率 / 分销佣金 / 渠道折扣」均可在后台 [system_configs](file:///d:/Lisa主机网络建设/metoe_backend/core/init_db.py#L445-L468) 动态修改，**无需重发版**。

### 4.1 核心收入（占比目标 85%）

#### 💰 Stream A — 云服务器批发零售差价（核心）
- **上游成本价**：从 Lisa-Host（`lisa_api_endpoint = https://api.lisa-host.com/v1`）/ Vultr / DigitalOcean 以批发价或 API 伙伴价拿机器（例如 `1c1g25g1t` 规格采购价 $4/mo，参考配置 `lisa_default_price_month`）
- **下游零售价**：用户在 [BuyPage.vue](file:///d:/Lisa主机网络建设/metoe/src/views/proxies/BuyPage.vue) 下的「全球云服务器购买」Tab 按建议零售价购买（$7.99-$499/mo 阶梯）
- **差价率**：由 `system_configs.default_price_markup_percent`（默认 **+30%**）控制，可叠加 `default_cpu_price/default_ram_price/default_disk_price/default_bandwidth_price` 做细项加价
- **交付确认**：机器 `status=active` + `expire_at=购买日+30天` 写入 `vps_servers`，即确认营业收入（按月分期）

#### 💰 Stream B — 全球 ISP / 住宅代理订阅费（核心）
- **产品形态**：单国静态 IP（`proxies.plan` ∈ `isp/residential/datacenter/mobile`），按 **月付 / 季付 / 年付**（`orders.period=month/quarter/year`）
- **计费方式 1（月租位）**：每个 IP `price_month`（配置表 `default_isp_price_month`）× `qty`，毛利率 ~55-65%
- **计费方式 2（流量包）**：100 GB / 500 GB / 1 TB / 5 TB 阶梯一次性（`orders.total = package_price`），对应 `transactions.type='proxy_bandwidth'`
- **入口交付**：`proxies` 表含完整 `protocol://user:pass@host:port`，用户可一键导出 CSV / Clash 订阅

#### 💰 Stream C — 带宽 & 规格溢价
- 配置 `default_bandwidth_premium_percent`（默认 +20%）：≥1 Gbps 带宽加钱，**10Gbps 端口**额外 $99/mo
- 「高防 / 优化线路 / CN2 GIA / 软银 / CUVIP」作为附加 SKU 在 BuyPage 可选，单价 $5-$50/mo 写入 `orders.remark`

### 4.2 平台费（占比目标 10%，代码已实现）

#### 💸 Stream D — 充值手续费
- `system_configs.recharge_fee_rate`（默认 **2%**）+ 渠道手续费：
  - PayPal：**paypal_fee_rate=4.4% + paypal_fixed_fee_usd=$0.3**（配置表已写）
  - USDT（TRC20）：0.8% 链上成本内置在 `usdt_cny_usd_rate=7.25` 汇率差价
  - 支付宝 / 微信：已预留接口（`payment_alipay_enabled=0`），接入后默认 1.2%-1.5%
- 用户充 ¥1000 实际到账余额 = ¥980（手续费自动扣），系统 ¥20 为**平台预存手续费收入**

#### 💸 Stream E — 支付渠道差价（USDT）
- 用户支付时以 `usdt_cny_usd_rate=7.25` 显示的 CNY 金额折算 USDT 应付数；实际成本汇率由 `usdt_rate_source=coinbase` 实时拉取，两者价差（约 **0.3-0.8%**）为平台汇兑收益

#### 💸 Stream F — 提现 / 资金划转手续费
- [FundTransfer.vue](file:///d:/Lisa主机网络建设/metoe/src/views/wallet/FundTransfer.vue) 主子账号互转：每笔 **1%**（最低 ¥2）
- 提现 USDT / 银行卡：默认 **3%**（KYC 必须 `kyc_required_for_withdraw=1`）

### 4.3 生态收入（占比目标 5%，代码已预留）

#### 🤝 Stream G — 分销 / 推荐佣金（Affiliate）
> 对应 2.6.3 GTM 第一阶段「分销飞轮」核心驱动力
- `/affiliate`（[Affiliate.vue](file:///d:/Lisa主机网络建设/metoe/src/views/Affiliate.vue)）：每个用户自动生成推荐码（`referral_code`）
- 返佣比例：`system_configs.affiliate_rate`（默认 **15%**，可按 `user_roles` 调整金牌代理 20-30%）
- 结算方式：好友**首笔付款 T+7** 后写入推荐人钱包（`transactions.type='affiliate_commission'`），可直接用于再消费或提现

#### 🎟️ Stream H — 优惠券 / 激活码 / 订阅制高级版
- `/coupons`：优惠券（满减 / 折扣 / 首单免费 / 代理流量包赠送），由运营在 Roles 后台发放或 [Redeem.vue](file:///d:/Lisa主机网络建设/metoe/src/views/Redeem.vue) 用户输入激活码
- 激活码类型：1 month VPS / 100GB 代理 / 高级开发者 API 1 Year — **作为渠道捆绑销售（淘宝 / TikTok Shop / 私域）**的中间载体，毛利 100%

#### 🔌 Stream I — 开发者 API 订阅
> 对应 P1 社媒矩阵「李运营」API 批量开 200 台、P3 数据采集「赵工程师」并发爬虫
- `/developer` 页（[Developer.vue](file:///d:/Lisa主机网络建设/metoe/src/views/Developer.vue)）+ `api_keys` 表：
  - Free：100 次 / 天（读接口）
  - Pro（$99/mo）：20,000 次 / 天 + 全量 CRUD（批量开通 1000 台 VPS / 批量换代理 IP / 一键切换出口国）
  - Enterprise（$999/mo）：不限 QPS + 私有回调 `callback_api_domain = https://admin-api.metoe.io`（配置已写）

#### 🛠️ Stream J — 增值服务（SLA / 代运维 / 定制镜像）
> 对应 P0「张店长」Chrome AntiDetect 定制镜像、P4「陈总」99.99% SLA
- 99.99% SLA 额外 +15% 月费
- 定制系统镜像（预装 Chrome Profile / AntiDetect / Multilogin / AdsPower）**一次性 $49-$199**
- 代运维服务包（$49/mo · 10台内：补丁 / 监控 / 自动迁移）

---

## 五、代码结构总览（Tree）

> 原「四、代码结构总览」章节顺延

```
d:\Lisa主机网络建设\                   ← MONOREPO 根（3 个子工程 + 2 个 Shell 部署脚本）
│
├── metoe\                              ← 🅵 FRONTEND（Vue3 + Vite + Element Plus）
│   ├── index.html
│   ├── vite.config.js                  代理 /api → http://localhost:3001（dev）
│   ├── package.json                    依赖：vue@3 / element-plus / pinia / axios / vue-router@4
│   └── src\
│       ├── main.js                     入口：注册 Pinia + Router + Element Plus
│       ├── App.vue
│       ├── router/index.js             6 个菜单分组 · 30+ 路由（见下方 5.2）
│       ├── stores/user.js              Pinia 用户：profile + roles + permissions + 余额
│       ├── api/                        11 个 API 封装（axios instance）
│       │     ├── auth.js               注册 / 登录 / profile / 改密
│       │     ├── servers.js            我的云服务器（列表/详情/重启/重装/部署）
│       │     ├── proxies.js            接入实例（代理列表/导出/换IP/续费）
│       │     ├── order.js              下单 / 订单列表 / 详情 / 取消
│       │     ├── payments.js           充值 / 支付流水 / USDT 地址 / 支付回调
│       │     ├── deploy.js             部署任务（VPN sing-box / WireGuard）
│       │     ├── check.js              网络检测中心（IP RBL / Geo / 纯净度）
│       │     ├── verify.js             实名认证（KYC）提交 / 查询
│       │     ├── config.js             系统前台配置（站点名/支付方式/费率）
│       │     ├── wallet.js             钱包（资金划转/流向）
│       │     └── system.js             后台（用户/角色/权限/审计日志）
│       ├── layout/AdminLayout.vue      含左侧菜单 + 顶部用户 + 快捷入口 Tab
│       ├── utils/request.js            axios 拦截器（自动带 JWT，401 跳登录）
│       ├── assets/global.css           自定义主题色（绿/红/橙状态 tag）
│       └── views/                      30 个页面（见 5.2 业务分组）
│
├── metoe_backend\                      ← 🅱 BACKEND（Python 3.10+ FastAPI + SQLite）
│   ├── app.py                          入口：启动 banner · CORS · 限流 · 注册路由 + /api & /v1 双前缀
│   ├── requirements.txt                fastapi / uvicorn / pyjwt / passlib[bcrypt] / slowapi
│   ├── core\                           4 大基础模块
│   │     ├── config.py                 Settings（PORT=3000 · DB_PATH=data/metoe.db · JWT_SECRET · CORS）
│   │     ├── database.py               get_conn() 上下文管理器 + SQLite row_factory=Row
│   │     ├── init_db.py                init_all()：建表 + 种子数据 + run_migrations() 补列回填
│   │     ├── security.py               get_current_user + 权限工具：scope_uid / enforce_owner_or_super / uid_int
│   │     └── shell_runner.py           调用 vpn.sh / ip-check.sh 的统一封装（SSH Paramiko / 本地 bash）
│   ├── services\
│   │     └── pipeline.py               ⭐ 业务主流水线：下单 → 扣余额 → 买机器 → 自动部署 → 写 DB → 回调
│   ├── routers\                        12 个资源路由
│   │     ├── auth.py                   POST /register /login /me /change-password（JWT）
│   │     ├── orders.py                 POST /orders（下单）GET /orders 列表/{no}详情 · PATCH 状态
│   │     ├── servers.py                云服务器列表 · 重启 · 重装 OS · 部署状态
│   │     ├── proxies.py                代理列表 · 购买 · 续费 · 换出口 · 导出订阅
│   │     ├── deploy.py                 部署任务（建任务→后台跑→回调通知→写vps_servers.entry_url/qr_code）
│   │     ├── payments.py               充值中心 / PayPal / USDT / 微信支付宝 预留 / 订单支付
│   │     ├── verify.py(+kyc)           KYC：提交证件 · 状态查询 · 后台审核（admin 专用）
│   │     ├── check.py                  网络检测中心：IP 纯净度 · RBL · 国家 · ASN · 机房识别
│   │     ├── feedbacks.py              反馈工单（创建 / 列表 / 改状态 / 回复）
│   │     ├── config.py                 前台 /config/site（读取 system_configs 白名单键）
│   │     ├── providers_mock.py         本地开发 mock：Vultr / DO / Lisa-Host 假 API（无外网也能跑）
│   │     └── system.py                 后台：用户管理 / 角色权限 / 审计日志 / 数据字典
│   └── data\
│         ├── metoe.db                  SQLite 主库（用户/订单/支付/钱包/服务器/代理/工单/KYC/配置…）
│         └── metoe_vps.db              预留：历史分离式 VPS 表归档库（已合并进 metoe.db）
│
├── vpn.sh                              ← 🅂 DEPLOY SCRIPT（Mono-script · ≈60KB，0 交互部署）
└── ip-check.sh                         ← 🅂 IP 体检脚本（IPv4+IPv6 · 8 项 Geo/RBL/Abuse 检测）
```

### 5.1 数据模型（17 张业务表 · SQLite Schema 声明见 `core/init_db.py`）

| 分组 | 表名 | 主键 / 关键字段 | 作用 |
|---|---|---|---|
| **👤 账户域** | `users` | id · username/email/phone · password_hash · role · balance(¥) · status · invite_code · referred_by | 账户主表 · 钱包余额 |
| | `roles` + `permissions` + `role_permissions` | role_code ↔ permission_code 多对多 | RBAC：`super_admin/admin/finance/support/user` × 30+ 权限码 |
| | `user_roles` | user_id + role_code（多角色） | 兼容「用户 + 财务 + 客服」混合身份 |
| | `kyc_verifications` | user_id · type(person/company) · status(pending/approved/rejected) · 证件照 3 张 | 实名认证（提现/大额度必需）→ 对应 2.1 合规 AML/KYC |
| | `api_keys` | user_id · key_hash · permissions · quota_daily | 开发者 API（对应 `/developer` 订阅）→ 2.4 差异化 ⑧ |
| **💰 交易域** | `orders` | order_no(YYYYMMDD-NNNNN) · user_id · product(server/proxy/...) · category · plan · period · qty · amount/discount/total · pay_method · status(pending/paid/refunded/cancelled) · paid_at · lisa_*（上游订单 ID） | 订单主表（所有业务统一入口） |
| | `payments` | trade_no · user_id · order_id (nullable) · method(usdt/paypal/alipay/wechat/mock) · amount · txid · status · confirm_count | 支付流水（充值 + 订单支付）→ 2.1.1 反洗钱 txid 追溯 |
| | `transactions` | id · user_id · type(recharge/payment/refund/commission/transfer/renew/coupon) · delta(±) · balance_after · ref_type · ref_id | **钱包流水账**（必追，余额只改这里）→ 2.4 护城河 ⑥ 企业资金归集 |
| | `coupons` | code · type(fixed/percent/package) · value · min_order · expire_at · used_by/used_at | 优惠券 / 激活码（捆绑销售载体） |
| **☁️ 资源域** | `vps_servers` | id · user_id · order_id · lisa_vps_id · provider · region · spec · ip · ipv6 · ssh_* · os · cpu/ram/disk/bandwidth · price_month · status(active/provisioning/stopped/error) · expire_at · usage(ecom/web/data/...) · entry_url · qr_code | **已购服务器明细 · 核心持久化表** |
| | `proxies` | id · user_id · order_id · country_code/name/flag · protocol · host · port · user · pass · plan · bandwidth · price_month · status · expire_at | 接入实例（ISP/住宅代理）→ 2.3 痛点 P2/P4 |
| | `deploy_tasks` | id · server_id(→vps_servers) · order_id · vpn_type(wireguard/singbox-*) · task_no · status(pending/running/success/failed) · progress · log_path · vpn_url · vpn_qr_code · output_json | 部署流水线执行记录 |
| **🧪 工具域** | `check_records` | id · user_id · ip · type(ipv4/ipv6) · geo(asn/country/city) · rbl_score · abuse_score · qs_score · result_json · created_at | 网络检测中心（防 IP 污染）→ 2.4 护城河 ② |
| **🛠️ 运营域** | `feedbacks` | id · user_id · category · title · content · attachments · status(pending/processing/resolved/closed) · priority · replies_json | 工单系统（C/S 双方）→ 2.1.1 DMCA 处置 |
| | `audit_logs`（代码 init_db 已注册） | id · user_id · action · resource_type · resource_id · old/new_json · ip · ua · created_at | 敏感操作审计（改密码/删服务器/提现审核）→ 2.1.2 合规留证 |
| **⚙️ 系统域** | `system_configs` | key(PK) · value · type · group · description · updated_by | **全站动态参数中枢**（50+ 项：品牌/支付/加价率/回调 URL…）→ 2.6.2 品牌配置项 |

---

### 5.2 前端路由 × 菜单分组（`router/index.js`）

```
/ (AdminLayout)
├── 📊 控制台                 Dashboard                 dashboard:view
│
├── 🛒 产品中心
│   ├── 全球云服务器购买       proxies/BuyPage.vue       orders:create     ← 下单入口（VPS+代理 一个页）
│   └── 推荐分销中心           Affiliate.vue             dashboard:view    ← Stream G 佣金入口（2.6.3 冷启动）
│
├── 💻 业务管理
│   ├── 我的云服务器           ServersList.vue           servers:view      ← vps_servers 列表
│   └── 接入实例列表           proxies/IspList.vue       proxies:view      ← proxies 列表（别名 /access）
│
├── 💰 系统管理（账单 & 钱包）
│   ├── 充值中心               RechargeCenter.vue        dashboard:view    ← Stream D 手续费
│   ├── 充值订单               RechargeOrders.vue        dashboard:view
│   ├── 费用明细               BillingDetail.vue         dashboard:view    ← 订单/续费/优惠券流水账
│   ├── 历史订单               OrdersList.vue            orders:view
│   ├── 订单详情               OrderDetail.vue           orders:view
│   ├── 自动续订               AutoRenew.vue             dashboard:view    ← Stream A/B 续费率
│   ├── 优惠券                 Coupons.vue               dashboard:view    ← Stream H
│   ├── 激活兑换码             Redeem.vue                dashboard:view
│   ├── 子账号管理             SubAccounts.vue           dashboard:view    ← P4 企业子账号（2.5 节 Persona 5）
│   ├── 资金划转               wallet/FundTransfer.vue   dashboard:view    ← Stream F 手续费
│   ├── 资金流向               wallet/FundFlow.vue       dashboard:view
│   └── 敏感操作日志           AuditLog.vue              dashboard:view
│
├── 🪪 账户中心
│   └── 实名认证               Verify.vue                kyc:submit/view   ← KYC 表写入
│
├── 🔧 工具支持
│   ├── 网络检测中心           CheckCenter.vue           check:run         ← check_records 表
│   ├── 开发者 API             Developer.vue             developer:view    ← Stream I 订阅
│   ├── 资源中心               Resources.vue             dashboard:view    ← 文档 & 客户端下载
│   └── 反馈建议               Feedback.vue              feedback:create   ← feedbacks 表
│
└── ⚙️ 系统设置（Admin 专用）
    ├── 用户管理               system/Users.vue          system:users:view
    ├── 全局配置               system/Configs.vue        config:view/manage← 2.6.2 品牌参数修改
    └── 角色权限               system/Roles.vue          system:roles:view ← 只允许 super_admin/admin 访问
```

---

## 六、核心业务流程（Pipelines & Life Cycles）

> 原「五、核心业务流程」章节顺延

### 6.1 核心主流程 —「购买云服务器 + 自动部署 WireGuard 入口」（T+3 min 全自动）

```
用户下单                         后端 pipeline.py trigger_lisa_and_deploy()                上游 Lisa/Vultr        vpn.sh on VPS         vps_servers 表 ← 最终落库
  │                                   │                                                       │                      │                     │
  │ ① BuyPage.vue POST /orders        │                                                       │                      │                     │
  ├────────────────────────────────►  │ ② 校验余额 → orders.status=pending                    │                      │                     │
  │                                   ├─► INSERT orders (total=¥X)                            │                      │                     │
  │                                   ├─► INSERT transactions(-¥X) · users.balance-=¥X        │                      │                     │
  │                                   │                                                       │                      │                     │
  │                                   ├─► ③ 调 providers_mock 或 lisa_api_endpoint  Create Instance
  │                                   └──────────────────────────────────────────────────────► │ 开机器（5-90s）       │                     │
  │                                   │ ◄── 回：ip/region/spec/ssh 密码 ────────────────────── │                      │                     │
  │                                   │                                                       │                      │                     │
  │                                   ├─► ④ INSERT vps_servers (status=provisioning)  ──────────────────────────────────────► usage=category       │
  │                                   │    INSERT deploy_tasks(status=pending)                 │                      │                     │
  │                                   │                                                       │                      │                     │
  │                                   ├─► ⑤ 异步调 shell_runner → SSH: bash vpn.sh ────────────────────────────────────────► │ bash vpn.sh 0-交互 │
  │                                   │                                                       │                      │ 部署 WireGuard +     │
  │                                   │                                                       │                      │ Sing-box 协议栈 +    │
  │                                   │                                                       │                      │ Nginx 生成入口页      │
  │                                   │                                                       │                      │ 产出：               │
  │                                   │                                                       │                      │  · vpn_url (下载页) │
  │                                   │                                                       │                      │  · vpn_qr_code PNG  │
  │                                   │                                                       │                      │  · wg:// conf       │
  │                                   │ ◄────── 回调 callback_api_path /internal/deploy/notify（含 vpn_url+qr） ───────────── │                     │
  │                                   │                                                       │                      │                     │
  │                                   ├─► ⑥ UPDATE deploy_tasks.status=success + vpn_url/qr    │                      │                     │
  │                                   │    UPDATE vps_servers  ⭐ 重点写入：                    │                      │                     │
  │                                   │      · status  → 'active'                             │                      │                     │
  │                                   │      · entry_url ← deploy.vpn_url  ─────────────────────────────────────────────────► entry_url            │
  │                                   │      · qr_code   ← deploy.vpn_qr_code ─────────────────────────────────────────────► qr_code              │
  │                                   │      · expire_at = now+30d                            │                      │                     │
  │                                   │      · updated_at                                     │                      │                     │
  │                                   │                                                       │                      │                     │
  │ ⑦ ServersList.vue 展示            │                                                       │                      │                     │
  │ ◄── /servers?all=0 返回 10+ 字段  │                                                       │                      │                     │
  │      · 用途(ecom/web/...) 来自 usage                      │                      │                     │
  │      · 入口链接 来自 entry_url                          │                      │                     │
  │      · 扫码 = qr_code                                     │                      │                     │
  │      · 状态 = active (Tag: success-green)                │                      │                     │
  │      · 到期 = expire_at                                  │                      │                     │
  ▼                                   ▼                                                       ▼                      ▼                     ▼
 🟢 用户浏览器扫码即用              🎉 订单 paid + 部署 100%                             上游账单 +$4 成本       WireGuard 生效          数据完全落库 ✓
```

> **对应代码定位**：
> - 订单→扣款→资源创建→部署编排：[services/pipeline.py trigger_lisa_and_deploy()](file:///d:/Lisa主机网络建设/metoe_backend/services/pipeline.py#L221-L540)
> - 部署成功回写 vps_servers（usage/entry_url/qr_code/status/expire）：[pipeline.py L450-L458](file:///d:/Lisa主机网络建设/metoe_backend/services/pipeline.py#L450-L458)
> - 历史数据自动迁移（老数据补列 + 回填 + 状态归一）：[core/init_db.py run_migrations()](file:///d:/Lisa主机网络建设/metoe_backend/core/init_db.py#L644-L728)

### 6.2 核心安全机制 — 「数据隔离策略（超级管理员 vs 普通用户）」

**统一 3 函数（`core/security.py`）**：所有路由用同一段逻辑保证数据只能本人 + 超管访问，避免越权：
1. `uid_int(user)`：强制把 `user.id` 转 **int**，防「字符串 1 vs 数字 1」造成的权限绕过
2. `scope_uid(user, all_flag)`：列表查询，超管且 `all=1` 才返回 **None（不过滤）**，否则一律返回当前 `user_id` 做 WHERE
3. `enforce_owner_or_super(user, obj, field="user_id", action="访问")`：单条 GET/PUT/PATCH/DELETE 前二次校验

应用覆盖范围：
- 服务器列表、重启、重装：[routers/servers.py](file:///d:/Lisa主机网络建设/metoe_backend/routers/servers.py#L120-L250)
- 订单列表 / 改状态：[routers/orders.py](file:///d:/Lisa主机网络建设/metoe_backend/routers/orders.py)
- 支付记录列表：[routers/payments.py](file:///d:/Lisa主机网络建设/metoe_backend/routers/payments.py)
- 工单状态变更：[routers/feedbacks.py](file:///d:/Lisa主机网络建设/metoe_backend/routers/feedbacks.py)

### 6.3 订单 → 支付 → 钱包 双写保证
- **先写 transactions 再 UPDATE users.balance**（原子事务在 `database.py` 上下文里 `conn.commit()`）
- **所有扣余额前重查最新 balance** 防并发：`SELECT balance FROM users WHERE id=? FOR UPDATE`（SQLite 兼容写法为事务内先 SELECT → UPDATE → WHERE balance >= 条件，不满足抛 402）
- **支付回调幂等键 = txid（PayPal 订单号 / USDT 链上 hash）**：`INSERT OR IGNORE INTO payments` 防重复充值

### 6.4 KYC + 风控（已部分实现，可扩展）
> 对应 **2.1 合规性** Ⅲ 类 AML/KYC 要求
- **大金额购买（≥ ¥5000）必 KYC approved**：在 [BuyPage.vue](file:///d:/Lisa主机网络建设/metoe/src/views/proxies/BuyPage.vue) 前端先拦截，后端 `orders.py` 下单时再次校验
- **IP 黑名单 + 多账户识别**：注册 / 登录 IP & UA 写入 audit_logs，配合 `providers_mock` 可扩展防注册机器人
- **USDT 链上确认 = usdt_min_confirm=1**：达到才标记 payments.status=success 到账

---

## 七、架构 & 部署方式（3 层架构）

> 原「六、架构 & 部署方式」章节顺延

```
┌───────────────────────────────────────────────────────────────────────────┐
│   L1 — 接入层                                                              │
│   · 前端静态：CDN（阿里云 OSS / 七牛 / Cloudflare Pages）分发 dist        │
│   · 后端入口：Nginx 反代 → uvicorn (8 进程) · 域名 admin-api.metoe.io      │
│   · WebSocket / SSE：部署进度推送（pipeline.deploy_tasks.progress）       │
│   · 合规建议：官网 www.metoe.cn / 业务 app.metoe.io 分域名分机房部署       │
│     → 参见 2.1.1 合规第 Ⅳ 类                                              │
├───────────────────────────────────────────────────────────────────────────┤
│   L2 — 应用层                                                              │
│   · metoe_backend/app.py（FastAPI，CPU 密集部署开 8 worker）               │
│   · shell_runner（远程 SSH Paramiko → 所有 VPS 批量跑 vpn.sh / ip-check） │
│   · 异步：部署走 BackgroundTasks（生产可换 Celery + Redis）               │
│   · 海外节点 3 副本：洛杉矶（美区）/ 法兰克福（欧区）/ 东京（亚太区）       │
│     → 对应 P0-P4 Persona 5 国核心覆盖                                     │
├───────────────────────────────────────────────────────────────────────────┤
│   L3 — 数据与外部                                                          │
│   · 主库 SQLite（单节点 ≤10w 台够用，生产可平滑迁移到 PostgreSQL：         │
│         所有 SQL 使用标准语法，唯一特性：autoincrement/ROWID→SERIAL）       │
│   · 冷备：每日 .dump 到对象存储（保留 30 天）                               │
│   · 【合规加密】机密字段 AES-256 KMS：paypal_secret / lisa_api_secret     │
│   · 上游 API：Lisa-Host / Vultr / DigitalOcean / Coinbase 汇率            │
│   · 支付渠道：PayPal · USDT-TRC20（已接通）· Alipay/WeChat Pay（待上线）  │
│   · 邮件/通知：SMTP 发工单邮件 · Telegram 群通知管理员新订单              │
│   · 【OFAC 筛查】注册/下单 IP/姓名 × OFAC SDN List（2.1.1 合规 Ⅵ 类）     │
└───────────────────────────────────────────────────────────────────────────┘
```

### 7.1 一键本地启动（dev，Windows）
```bat
:: 终端 A：后端（端口 3001，vite.config.js 已代理）
cd metoe_backend
pip install -r requirements.txt
python app.py                 :: → http://localhost:3001/docs (Swagger)

:: 终端 B：前端
cd metoe
npm install
npm run dev                   :: → http://localhost:5173
                               :: 默认账号  admin / 123456  · demo / 123456
```

### 7.2 生产部署（香港机房起步 · 4C8G · Ubuntu 22.04）
> 对应 2.1.2 运营主体「香港有限公司」的合规架构
```bash
# ========== 1. 后端 Systemd (uvicorn 8 进程 + 自动重启) ==========
cat > /etc/systemd/system/metoe-backend.service <<EOF
[Unit]
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/metoe_backend
ExecStart=/opt/venv/bin/uvicorn app:app -u www-data -g www-data \
          --host 127.0.0.1 --port 3000 --workers 8
Restart=always
# 【合规 Ⅱ 类】核心文件 0600 权限，防止 sqlite / jwt_secret 泄露
ReadWritePaths=/opt/metoe_backend/data
[Install]
WantedBy=multi-user.target
EOF

# ========== 2. 前端 Vite 打包 → /opt/metoe/dist ==========
cd /opt/metoe && npm ci && npm run build

# ========== 3. Nginx（443 + Let's Encrypt 证书，大陆 / 海外分路径）==========
#    /api → proxy_pass http://127.0.0.1:3000
#    /    → try_files $uri /dist/index.html   （Hash 路由无需 try_files fallback）
#    【额外安全头】Strict-Transport-Security / X-Content-Type-Options / CSP
```

---

## 八、技术栈选型理由（Why These Stacks）

> 原「七、技术栈选型理由」章节顺延

| 层 | 选型 | 理由（含合规 & 成本视角） |
|---|---|---|
| 前端 | **Vue 3 + Vite + Element Plus + Pinia** | 国内开发者熟、Element Plus 的表格/Tag/Steps 组件高度契合「订单列表/规格选择器/状态机」类 SaaS，无需重写样式；Vite 冷启 < 2s；中文本地化开箱即用（对应 2.4 差异化 ⑥ 中文界面） |
| 后端 | **Python 3.11 + FastAPI + Uvicorn** | 异步 HTTP 友好、自带 Swagger（/docs）方便联调 + 商务展示；**SQLite 零运维**，10 万 VPS 以内不需要独立 DB（运维成本为 0）；Python 库（requests/bot 开发）与爬虫/自动化场景天然契合（P3 Persona 赵工程师的最爱） |
| 数据库 | **SQLite3（标准库）** | 单文件备份到 OSS 一行命令 → `sqlite3 metoe.db .dump \| gzip > backup.sql.gz`；读写 IOPS ≤ 1k/s 完全够用；Year 3 升 PostgreSQL 改 3 小时搞定；符合香港离岸公司**「不要自建 DB 集群」**的低成本运营策略 |
| 认证 / 权限 | **JWT (PyJWT) + bcrypt + RBAC + 行级 user_id 过滤** | 无状态水平扩展；RBAC 控功能可见性（Super Admin / 运营 / 财务各司其职）；行级 user_id 控数据可见性（双保险）；对应 2.4 差异化 ⑤（主子账号 RAM 权限） |
| 部署脚本 | **Bash（vpn.sh / ip-check.sh）+ SSH Paramiko** | 任何一台 Linux（Ubuntu 18+/CentOS7+/Debian 10+）无需预装 Python 就能跑；vpn.sh 内置所有 nginx/qrencode/sing-box 安装逻辑 = 真正 0 依赖；IP 纯净度检测 RBL 解析用 dig（Bash 内置），Python 封装一层 shell_runner = 跨平台 |
| 支付 | **USDT-TRC20 优先 → PayPal → 微信支付宝** | 跨境客户最爱（P0-P3 Persona 钱包里基本都有 USDT）：TRC20 到账 3 分钟、费率 < 1$、无拒付；PayPal 覆盖欧美散户；WeChat/Alipay 做国内私域售卖（Redeem 激活码）→ 对应 2.4 差异化 ⑦ USDT 人民币双币多通道 |

---

## 九、Roadmap（2026 H2 — 已实现 vs 进行中）

> 原「八、Roadmap」章节顺延；**新增合规与 GTM 里程碑**

| 阶段 | 模块 | 状态 | 对应 2.x 战略 |
|---|---|---|---|
| ✅ M1 核心交易闭环 | 注册/登录/JWT + 钱包充值 + 下单 + 扣余额 + 订单查询 + 支付（USDT/PayPal/mock） | **已交付** | 4.1 核心收入代码落地 |
| ✅ M2 云服务器业务 | VPS 购买 + 自动部署 WireGuard/Sing-box + 扫码交付页 + 服务器列表/重启/重装 + KYC + 数据隔离 | **已交付** | 6.1 主流程全通 + 2.1 合规 KYC |
| ✅ M3 代理接入业务 | 代理购买 + 国家 Tag + 导出 + 续费（接入实例列表已连通 proxies 表） | **已交付** | Stream B 业务收入 |
| 🔄 M4 运营工具 | 审计日志 / 自动续订（cron 每日跑 renew.py，即将加入仓库）/ 优惠券全量校验 / 邮件 & Telegram 通知 + DMCA 处置 SLA | **进行中** | 2.1.1 合规 Ⅰ/Ⅴ 类（DMCA + 滥用治理）+ 2.6.3 分销邮件通知 |
| ⏳ M5 规模化（Year 2 起步） | 主库升 PostgreSQL + Redis 缓存 Session + WebSocket 实时推送部署进度 + Grafana 大盘 + OFAC SDN List 筛查接入 + USDT 链上监听 + Chainalysis | 预计 2026 Q4 | 2.1.1 合规 Ⅲ/Ⅵ（AML/OFAC）+ 2.6.3 Phase 2 规模化 |
| ⏳ M6 企业版（Year 3 起步） | SSO（SAML/OIDC）+ 资源组 RBAC + 私有 VPC + 费用分摊子账单 + 合同&发票（6% 专票）+ 99.99% SLA 赔付 + 企业版白标 OEM | 预计 2027 Q1 | P4 Persona「陈总」+ 2.6.3 Phase 3 企业版直销 |
| ⏳ M7 基础设施自研（壁垒化） | MetoE OS（定制镜像）+ 洛杉矶 / 法兰克福 / 东京 自建小型机房 + 自有 ISP ASN 拿 IP 段 + 自研 AntiDetect 环境管理软件 | 预计 2027 Q4 → 2028 | 2.6.3 Phase 3 自建基础设施 + 毛利率从 35% → 50% |

---

## 十、维护 & 调试速查（For Ops / Dev）

> 原「九、维护 & 调试速查」章节顺延

- 主库：`metoe_backend/data/metoe.db`（**每日冷备 1 次**；合规建议：备份文件 GPG 加密后上传香港 OSS，保留 30 天 × 异地 2 副本）
- 后端错误日志：`server_err.log` / `server_out.log`（仓库根目录），同时 syslog 转发至 Telegram 管理员群通知
- 部署脚本日志（单个任务）：`deploy_tasks.log_path` → 落盘在远端 `/etc/s-box/output/<ip>/deploy.log`
- 前端 API 联调：[vite.config.js 代理](file:///d:/Lisa主机网络建设/metoe/vite.config.js) 默认 `/api → 3001`；生产打包可改 `.env VITE_API_BASE_URL`
- 【合规紧急操作】DMCA / 执法要求：`UPDATE vps_servers SET status='stopped' WHERE id=X;` → 立即停机 → 24h 内用户无申诉 → `status='banned'`；所有操作写入 `audit_logs`
- 默认账号：
  - `admin / 123456` → 超级管理员（看全量数据，`all=1` 生效）
  - `demo / 123456` → 普通用户（只读自己的 8 台 VPS）

---

> **文档结束**。本文件为系统唯一权威「是什么 / 怎么赚钱 / 合不合法 / 卖给谁 / 怎么卖 / 代码在哪 / 主流程如何跑」总览，新增模块请先更新本文件，再写代码（README-First 原则）。
>
> **v1.1 更新备忘（2026-07-21）**：新增第二章（2.1 合规 6 大风险清单 + 2.2 TAM/SAM/SOM $150B + 2.3 9 大痛点表 + 2.4 9 条护城河公式 + 2.5 5 类 Persona 深度画像 + 2.6 定位 Slogan & 三阶段 GTM Roadmap ¥150 万 / ¥800 万 / ¥3000 万预算分配）。
