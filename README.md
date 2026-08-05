# 🚀 Lisa 主机出海节点自动化部署脚本

基于 [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) 的 **Sing-box 多协议 + Nginx 交付页一键部署脚本**。一次 `bash vpn.sh`，完成：

- Sing-box 协议部署（Vless-Reality、Vmess-WS、Vmess-WS-TLS、Hysteria-2、Tuic-v5、AnyTLS、Argo 隧道…——用于合法出海业务）
- 自动生成日期文件夹（`YYYYMMDD-N`）+ 二维码 + 链接 + 聚合节点
- 自动安装 Nginx 并配置静态站点，**直接访问服务器 IP 就能查看节点接入页面**
- 内含完整客户端工具说明（🚀 小火箭 Shadowrocket / NekoNG / NekoBox / Clash Verge / sing-box 官方 SFA·SFI·SFM…）和扫码导入教程

***

## 📁 文件清单

| 文件                     | 说明                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| **[vpn.sh](./vpn.sh)** | ✅ **唯一主脚本**，上传到服务器执行即可。`sb_output.sh` 辅助脚本、`sb.sh` 补丁、Nginx 配置、客户端工具/Hero/Badge/教程 HTML 模板都**内嵌其中**。 |
| **README.md**          | 本文档。                                                                                                 |

***

## 📰 更新日志（CHANGELOG）

| 日期             | 版本   | 更新内容                                                                                                                                                                                                                                              | 涉及文件 / 章节                                         |
| -------------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **2026-07-20** | v1.3 | ✅ **IPv6 双栈支持**：自动获取公网 IP 从「只支持 IPv4（`-4`）」改为「**IPv4 优先 → 失败自动 fallback 到 IPv6（`-6`）三源重试」；`ip-check.sh`** **新增** **`IP_VER`** **变量自动区分 v4/v6，IPv6 目标自动跳过 RBL（公开 DNSBL 对 IPv6 支持极少），其余 Geo/ASN/AbuseIPDB/IPQS/Scamalytics/Spur 6 项检测**对 IPv6 全部生效。 | `ip-check.sh` L38-L216、`vpn.sh` L827-L1005（内嵌段同步） |
| **2026-07-20** | v1.2 | 🔧 **变量引用加固**：修复 `chmod +x $SB_OUTPUT_PATH` 和 `chmod +x $IPCHECK_PATH` 两处**未加双引号保护**的隐患（如果路径含空格会拆分参数报错），统一为带引号的 `"$SB_OUTPUT_PATH"` / `"$IPCHECK_PATH"`。                                                                                          | `vpn.sh` L785、L1188                               |
| **2026-07-19** | v1.1 | 🆕 **多节点多国家汇聚指南**：新增 3 套「N 台 VPS 的节点 → 统一管理」方案：① 「一个订阅 URL」一键导入全部客户端；② 聚合二维码（手机扫一次导入所有节点）；③ 聚合总览 HTML 页（一页展示全部国家全部协议的二维码+复制按钮），附带完整 bash 脚本。                                                                                                      | README `## 🗺️ 多节点多国家汇聚指南`                        |
| **2026-07-19** | v1.0 | 🛒 **服务器推荐 + IP 健康检测 + 长期运营组合**：补齐国家/区域细分表格、按用途 Top5 推荐、长期运营三星到五星跨国家组合、VPS 到手 5 项必检 IP 工具对照表。                                                                                                                                                     | README `## 🛒 服务器购买推荐` + `## 🛡️ IP 健康体检`         |

***

## 🎯 脚本对比：原版 sb.sh vs 本仓库 vpn.sh

| 项目          | 原版 sing-box-yg（sb.sh）                                                                  | 本仓库 vpn.sh（✅ 推荐）                                                                                                                                                                                          |
| ----------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **一行执行命令**  | `bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)` | 海外：`bash <(curl -Ls https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)`国内：`bash <(curl -Ls https://gh-proxy.com/https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)` |
| **部署交互**    | 需手动按菜单：`9` 安装 → `15` 生成分享                                                              | **0 交互全自动**（内置 wget 预检查、sb.sh 补丁、Nginx 安装配置、防火墙放行…）                                                                                                                                                       |
| **产出物**     | 终端打印文字链接（无二维码 / 无 HTML 页面）                                                             | 日期文件夹 `YYYYMMDD-N/` + 二维码 `.png` + **完整响应式 HTML 页面**（Hero 6 平台 Tabs + 每张协议 5 色 Badge + 聚合节点⭐一键复制 + 扫码教程折叠面板 + FAQ/Ghelper 冲突说明 + 使用小贴士卡片）                                                                 |
| **访问方式**    | 一条条复制终端文字，手机粘贴                                                                         | 浏览器打开 `http://<IP>/latest/` → 扫码 / 一键复制全部                                                                                                                                                                 |
| **Nginx**   | 无                                                                                      | ✅ 自动安装（apt/yum/dnf 自适应）+ 覆盖默认站点 root → /etc/s-box/output + 302 `/` → `/latest/` 软链                                                                                                                        |
| **新机器依赖**   | 需要先手动 `yum install -y wget`                                                            | ✅ 自动补 wget / qrencode；CRLF 换行符自动修复                                                                                                                                                                        |
| **链接稳定性**   | 同（都基于 sb.json 只生成一次）                                                                   | 同                                                                                                                                                                                                         |
| **主页 / 仓库** | [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg)                      | **[doomsangle/Lisa-server](https://github.com/doomsangle/Lisa-server)**（你自己的仓库）                                                                                                                           |

***

## 🚀 部署步骤（3+1 种方式，任选其一）

### ⭐ 方式 A（最快，无需本地文件）：服务器直接从你的 GitHub 拉取

**不用本地下载 vpn.sh、不用 scp 传文件，SSH 进服务器粘贴 1 行就完事。**

> 💡 **如果提示** **`wget: command not found`**，先执行下面任意一条 bootstrap（任选其一）：
>
> ```bash
> # 方案 1：大多数系统自带 curl，优先用 curl（推荐）
> bash <(curl -Ls https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
>
> # 方案 2：先装 wget 再执行（Debian/Ubuntu）
> apt-get update -y && apt-get install -y wget && bash <(wget -qO- https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
>
> # 方案 3：先装 wget 再执行（CentOS/RHEL）
> yum install -y wget && bash <(wget -qO- https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
> ```

📋 **一键复制命令：**

```bash
# 1) 海外机器 / 能直接访问 GitHub raw —— 优先用 curl（自带率更高）
bash <(curl -Ls https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
#    或者用 wget：
#    bash <(wget -qO- https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)

# 2) 国内机器（GitHub raw 常超时）→ gh-proxy.com 加速镜像
bash <(curl -Ls https://gh-proxy.com/https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
#    或者用 wget：
#    bash <(wget -qO- https://gh-proxy.com/https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
```

> 跑完看输出里的部署完成提示 → 浏览器打开 `http://<服务器IP>/latest/` 就能看到配置页面。

### 方式 B（本地改了脚本 → 传服务器）：scp 上传 vpn.sh

#### 第 1 步：上传到服务器

📋 **一键复制命令：**

```bash
scp -O vpn.sh root@<你的服务器IP>:~
# 或用 Xftp / WinSCP 等工具（传完记得校验文件大小≈60KB）
```

> 💡 **Windows → Linux 必看**：本脚本已强制锁定为 **LF + UTF-8 无 BOM**。如果你用某些工具（如记事本、老版 SecureCRT）另存后上传出现下面的报错：
>
> ```
> set: usage: set [-abefhkmnptuvxBCHP] ...
> vpn.sh: line 4: $'\r': command not found
> ```
>
> 在服务器上当场 1 秒修复：
>
> ```bash
> sed -i 's/\r//' vpn.sh && chmod +x vpn.sh && bash vpn.sh
> ```

### 第 2 步：执行

📋 **一键复制命令：**

```bash
chmod +x vpn.sh
bash vpn.sh
```

全程无需任何交互（内置：

- ✅ 新机器自动 `yum install -y wget`
- ✅ 下载并 patch 原版 sb.sh（打 patch：在 sbshare 函数里调用 sb\_output.sh 生成 HTML 页面）
- ✅ 部署 sb\_output.sh 到 /etc/s-box/sb\_output.sh
- ✅ 一键安装 Sing-box（默认执行 sb.sh 选项 9 + 15 生成分享）
- ✅ 自动安装 Nginx（apt/yum/dnf 自适应）+ 覆盖默认站点（root → /etc/s-box/output，index /latest 302 跳到最新一份）
- ✅ 自动放行系统防火墙 ufw / firewalld / iptables）

### 第 3 步：访问页面

脚本结束时会输出：

```text
========================================
✅ 部署完成！请访问：
   http://<服务器IP>/latest/            ← 推荐，永远是最新一份
   http://<服务器IP>/<日期文件夹>/
========================================
```

浏览器打开即可看到：**Hero 客户端工具卡片 + 6 平台 Tabs + 每个协议客户端 Badge + 聚合节点 ⭐一键复制 + 协议详情卡 + 折叠扫码教程 + FAQ（Ghelper 冲突/502/二维码缺失…）+ Tips 卡片** —— 完整页面 💻📱

***

## 📂 服务器端输出目录结构

```text
/etc/s-box/
├── sb.json                     # sing-box 核心配置（端口/UUID/密码 都在这里，首次部署后就不动了）
├── vl_reality.txt              # Vless-Reality 单节点链接
├── vm_ws.txt                   # Vmess-WS 单节点链接
├── vm_ws_tls.txt               # Vmess-WS-TLS 单节点链接
├── vm_ws_argols.txt            # Argo 临时隧道链接
├── vm_ws_argogd.txt            # Argo 固定隧道链接
├── hy2.txt                     # Hysteria-2 单节点链接 (UDP · 弱网传家宝)
├── tuic5.txt                   # Tuic-v5 单节点链接 (UDP · 游戏低延迟)
├── an.txt                      # Anytls 单节点链接
├── jhsub.txt                   # ⭐ 聚合节点（全部协议一条链接）
├── sb_output.sh                # HTML 生成辅助脚本（由 vpn.sh 自动部署）
└── output/
    ├── latest -> 20260718-1    # 软链，始终指向最新一份（Nginx root）
    ├── 20260718-1/
    │   ├── index.html          # 你要访问的页面 🎨
    │   ├── vl_reality.png      # Vless-Reality 二维码
    │   ├── vm_ws.png  vm_ws_tls.png  vm_ws_argols.png ...
    │   ├── hy2.png  tuic5.png  an.png  jhsub.png
    │   └── *.txt               # 与 /etc/s-box 里各链接一一对应（备份用）
    ├── 20260718-2/             # 第二次执行
    └── 20260719-1/             # 第 N 次执行（sb.json 没变，链接/二维码都一样）
```

***

## ❓ 重复执行 FAQ

| 问题                                         | 答案                                                                                                                                                                                                                                                                                           |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 重新执行 `bash vpn.sh`，**已有的 VPN 链接/二维码会不会变？** | **不会**。Sing-box 的 `sb.json` 只在**第一次部署**时生成一份（在 `/etc/s-box/sb.json`），后续重复执行**不改动 sb.json**，只是把这些「已有的链接」重新收集成一份新的 HTML 页面，存到 `output/YYYYMMDD-N/` 新文件夹里。**正在使用的手机/电脑客户端完全不受影响**。                                                                                                              |
| 既然链接不变，为什么每次还要生成新的日期文件夹？                   | 方便回溯、方便分享给不同朋友（每份独立 URL），并保留一份历史快照（txt + png + html 三联备份）。                                                                                                                                                                                                                                   |
| 我想**重新生成端口/UUID/密码**可以吗？                   | 可以，但**会让旧链接全部失效**（手机上的节点要全部重新导入）。操作方法：先删 `/etc/s-box/sb.json` → 再 `bash vpn.sh`，脚本会走完整首次部署流程，生成全新的 sb.json 和对应的新链接。                                                                                                                                                                          |
| 改了 Nginx root 路径或服务器 IP，vpn.sh 需要同步改吗？     | **不需要**。vpn.sh 的 Nginx 配置固定把 `root /etc/s-box/output;` 写入 Nginx 默认站点，且用 `try_files /latest/index.html =404;` + 302 `/` → `/latest/`。只要你没动 `/etc/s-box/output` 目录本身，所有改动（换 IP、重启 Nginx、重装系统后恢复 output 目录）都无需重写 vpn.sh。                                                                        |
| 服务器上没有 qrencode，页面里二维码会不会破图？               | 不会。页面会显示**条纹占位图**（代替破图 ×）并写文字说明「请点复制链接，在客户端粘贴同样可用」，不影响使用。想要真二维码：`yum install -y qrencode` 后再 `bash /etc/s-box/sb_output.sh main_output` 重新生成一份 HTML。                                                                                                                                         |
| 为什么页面里「生成时间」/「主机名」有时是空？                    | 之前老版本是在 heredoc 里嵌 `$(date ...)`，中间层 SSH/代理会吞掉 `%`。**最新 vpn.sh 已修复**：① generate\_html 顶部先把 `gen_time` / `hostname` 算成 bash 变量+默认值兜底；② HTML 写完再 `sed -i` 横扫 8 条规则，把残留字面量（`$gen_time` / `$(date ...)` / `$hostname` / `$DATE_FOLDER`）全部替回真实值。只要用最新脚本就一定有值。                                     |
| 访问页面出现 **502 / DNS lookup failed**？        | 一般是浏览器装了 Ghelper / 或电脑走了别的代理 → 把「服务器 IP」加进 Ghelper「直连列表」或暂时关代理再访问；也可用手机 4G 直连验证。                                                                                                                                                                                                             |
| 部署完 Nginx 仍然看到 `Welcome to nginx!` 默认页？    | 不同发行版 Nginx 默认配置文件位置不同（`/etc/nginx/conf.d/default.conf` vs `/etc/nginx/sites-enabled/default`），vpn.sh 会**两处都覆盖 + 删 sites-enabled/default + nginx -t 检查 + systemctl reload nginx**。如果还是欢迎页：`ls -la /etc/nginx/conf.d/default.conf` 看里面 `root` 是不是 `/etc/s-box/output;`，再手动 `nginx -s reload`。 |

***

## 📱 客户端工具快速一览（页面里有完整 Tabs + 分步教程）

| 平台              | 首选工具                                                            | 其他选择                                                         |
| --------------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| 📱 iOS / iPadOS | 🚀 **Shadowrocket 小火箭**（App Store 国区搜" Shadowrocket"，约 18¥，终身用） | Stash、Quantumult X、sing-box SFI（TestFlight）                  |
| 🤖 Android      | 🟢 **v2rayNG**（GitHub 免费下载）                                     | NekoBox、Clash Verge Rev (ClashMeta For Android)、sing-box SFA |
| 🪟 Windows      | 🟢 **v2rayN**（.NET 版 / 自包含版 GitHub 免费）                          | NekoRay、Clash Verge Rev、sing-box SFM                         |
| 🍎 macOS        | 🚀 **Shadowrocket for Mac**（Mac App Store 同 iOS 版付费一次双端用）       | Clash Verge Rev、sing-box SFM、V2rayU                          |
| 🐧 Linux        | 🐱 **Clash Verge Rev**（deb/rpm/AppImage）                        | sing-box 命令行、NekoRay                                         |
| 🛰️ 路由器 OpenWrt | **PassWall2 / OpenClash**（需刷 OpenWrt 固件+安装对应插件）                 | luci-app-syncdial、sing-box-system                            |

> ⭐ **最省事操作（任何平台都推荐）**：打开页面 → 滑到最下面 **「聚合节点」卡片** → 点 **⭐ 一键复制全部** → 打开客户端粘贴 → 自动批量导入所有协议。比一条条扫码快 10 倍。

### 快速扫码导入对应关系

```
页面每张协议卡的底部 5 个彩色 Badge → 代表"哪些客户端能识别此协议的链接/二维码"
🚀 小火箭 / 🟢 v2rayNG·v2rayN / 📦 NekoBox·NekoRay / 🐱 Clash Verge / ✨ SFA·SFI·SFM
   ↑         ↑                        ↑                   ↑                ↑
  iOS全协议   Android/Win 全协议     跨平台小众首选     订阅/规则首选     sing-box 原生
```

***

## 🗺️ 多节点多国家汇聚指南（把 N 台 VPS 的节点 → 一个订阅 / 一个二维码 / 一个总览页）

> 适用场景：你按推荐买了日本 Vultr + 芬兰 UpCloud + 加拿大 OVH + 瑞士 Exoscale ……每台各跑一遍 `vpn.sh`，都有自己的 `index.html` 和二维码，现在想把这些分散在 N 台机器上的节点合到：① 一个订阅 URL（客户端一次导入全部）② 一个聚合二维码（手机扫一次全部导入）③ 一个总览页面（统一查看 N 台所有协议的二维码和复制按钮）。

### 先弄清楚：单台 vpn.sh 产出了哪些可汇聚的「原料

每台 VPS 在 `/etc/s-box/output/YYYYMMDD-N/` 下会有这 2 类核心文件，**后面所有汇聚方案都靠它们**：

| 产物文件         | 内容                                                                                | 在汇聚中的作用      |
| ------------ | --------------------------------------------------------------------------------- | ------------ |
| `jhsub.txt`  | **本台所有协议节点，每行一条**（原生 URI 链接格式：vless\://… / vmess\://… / hysteria2://… / tuic://…） | 方案一/二的「节点源」  |
| `*.png`      | vl\_reality.png / hy2.png / tuic5.png … 等二维码图片                                    | 方案三总览页显示用    |
| `index.html` | 本台节点的 HTML 卡片（6 协议 + 二维码 + 复制）                                                    | 方案三 ifram 嵌入 |

> 💡 **小提示**：如果你选一台作为「主控机」（建议选最便宜/最稳定的那台），以下所有操作都在**主控机**上做即可；其他 N-1 台只负责跑 sing-box 出节点。

***

### 方案一：汇聚成「一个订阅 URL」（⭐ 最推荐，所有客户端通用，5 分钟搞定）

**最终效果**：得到一个 `http://<主控IP>/all-nodes.txt`，在 **小火箭 / v2rayNG / Clash / NekoBox** 里选「**从 URL 添加订阅**」→ 一次导入所有国家所有协议的节点。

#### 步骤

📋 **一键复制命令：**

```bash#

# 1. 建立汇聚目录
mkdir -p /etc/s-box/merge/nodes

# 2. 把每台【子机】的 jhsub.txt 拉过来（3 种方式任选一种）
# 方式 A：SSH 密钥登录（推荐，自动 + 安全）
#    先在主控机 ssh-keygen，再 ssh-copy-id root@<子机IP> 配免密，然后：
scp -o StrictHostKeyChecking=no  root@1.2.3.4:"/etc/s-box/output/*/jhsub.txt"  /etc/s-box/merge/nodes/jp-vultr.txt
scp -o StrictHostKeyChecking=no  root@5.6.7.8:"/etc/s-box/output/*/jhsub.txt"  /etc/s-box/merge/nodes/fi-upcloud.txt
scp -o StrictHostKeyChecking=no  root@9.10.11.12:"/etc/s-box/output/*/jhsub.txt" /etc/s-box/merge/nodes/ca-ovh.txt
# 方式 B：子机暴露了 nginx（每台都跑 vpn.sh 默认有），直接 HTTP 拉（不用配 SSH Key）
# curl -sL "http://<子机IP>/latest/jhsub.txt" > /etc/s-box/merge/nodes/jp-vultr.txt
# 方式 C：手动复制 jhsub.txt 内容粘贴到主控机 /etc/s-box/merge/nodes/xx.txt

# 3. 合并成一个 all-nodes.txt（自动去重 + 保留注释行）
mkdir -p /etc/s-box/output
awk '!seen[$0]++' /etc/s-box/merge/nodes/*.txt > /etc/s-box/output/all-nodes.txt
# （主控机自己的节点也加进来（如果主控机自己也跑 sing-box）
cat /etc/s-box/output/*/jhsub.txt >> /etc/s-box/output/all-nodes.txt && awk -i inplace '!seen[$0]++' /etc/s-box/output/all-nodes.txt

# 4. 确认总条数
echo "✅ 汇聚完成，共 $(wc -l < /etc/s-box/output/all-nodes.txt) 条节点"

# 5. 生成【订阅 URL】（任何客户端填这个）
#    http://<主控公网IP>/all-nodes.txt
#    例：http://203.x.x.x/all-nodes.txt
```

客户端导入方法（对应本仓库「客户端工具指南」那一章）：

| 客户端                  | 怎么导入这个订阅 URL                          |
| -------------------- | ------------------------------------- |
| 🚀 小火箭（Shadowrocket） | 右上角➕ → 类型「Subscribe」→ URL 粘贴上面地址 → 完成 |
| 🟢 v2rayNG           | 左上角 ≡ → 订阅设置 → ➕ 粘贴 URL → 更新订阅        |
| 🐱 Clash Verge Rev   | 侧边栏 订阅 → 新建 → 粘贴 URL → 立即更新           |
| 📦 NekoBox / NekoRay | 分组 → ➕ → 从 URL 导入订阅                   |

***

### 方案二：汇聚成「一个聚合二维码」（手机扫一次，导入全部节点）

**最终效果**：生成一个大的 base64 二维码，手机打开小火箭 / v2rayNG 的相机 → 扫一下 → 全部 N 台所有节点一次导入。

#### 在【主控机】上跑（依赖方案一的 \`/etc/s-box/output/all-nodes.txt 已生成）：

📋 **一键复制命令：**

```bash#
command -v qrencode >/dev/null 2>&1 || { apt-get install -y qrencode >/dev/null 2>&1 || yum install -y qrencode >/dev/null 2>&1 || true; }

# 2. 生成聚合二维码（分两种格式，按你常用客户端选）
#    注意：统一输出到 /etc/s-box/output/ 根目录，方案三 merge.html 用相对路径直接访问
OUT_DIR="/etc/s-box/output"
mkdir -p "$OUT_DIR"

#  格式 A：小火箭 / v2rayNG / NekoBox 原生支持 → 每行 URI 直接转二维码（≤50 条节点内推荐，最通用）
cat /etc/s-box/output/all-nodes.txt | qrencode -o "$OUT_DIR/merge-qr.png" -s 6 -m 2
#  格式 B：Clash / sing-box 订阅 Base64（节点很多 >50 条时用，先 base64 再二维码）
cat /etc/s-box/output/all-nodes.txt | base64 -w0 | qrencode -o "$OUT_DIR/merge-qr-b64.png" -s 6 -m 2

echo "✅ 聚合二维码已生成"
echo "   格式 A（通用·直接 URI）  → $OUT_DIR/merge-qr.png       访问：http://<主控IP>/merge-qr.png"
echo "   格式 B（Base64 订阅）    → $OUT_DIR/merge-qr-b64.png   访问：http://<主控IP>/merge-qr-b64.png"
```

\*\*使用：打开客户端扫码 → 一次全部导入 → 然后客户端「分组」里可以按国家名命名节点自己命名分组（小火箭长按节点改备注）

***

### 方案三：汇聚成「一个聚合总览 HTML 页」（一页看遍 N 台所有协议的二维码/复制按钮）

**最终效果**：生成 \`http\://<主控IP>/merge.html 一个页面展示【日本 Vultr 6 协议卡片 + 芬兰 UpCloud 6 协议卡片 + ...】 等 N × 6 张卡片的总览，和单台 vpn.sh 的 index.html UI 一致。

#### 在【主控机】跑一次脚本（把下面脚本存成 /etc/s-box/merge-page.sh，chmod +x 执行）

📋 **一键复制命令：**

```bash
cat > /etc/s-box/merge-page.sh << 'SCRIPT_EOF'
#!/bin/bash
# 多节点多国家 聚合总览 HTML 生成器
# 前置：方案一已完成，/etc/s-box/merge/nodes/*.txt 已放好；并把每台子机的 output 目录名 按 国家缩写-供应商 命名，每台子机
# 用法：bash /etc/s-box/merge-page.sh
set -e

WORK_DIR="/etc/s-box/merge"
OUT_DIR="/etc/s-box/output"
INDEX="$OUT_DIR/merge.html"

mkdir -p "$WORK_DIR/html_parts"
> "$INDEX"

# ---------- 写 HTML 头部（复用 vpn.sh index.html 同款 CSS / 客户端工具导航 + 快捷复制）
cat >> "$INDEX" <<'HEAD_EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>🌍 多节点多国家 · 聚合总览</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif; background: linear-gradient(135deg,#0f172a 0%,#1e293b 60%,#0f172a 100%); min-height:100vh; padding:18px; color:#e2e8f0; }
  .container { max-width: 1200px; margin:0 auto; }
  .header { text-align:center; padding:24px 20px; margin-bottom:22px; border-radius:18px; background: linear-gradient(135deg, rgba(99,102,241,.25), rgba(236,72,153,.2)); border:1px solid rgba(148,163,184,.18); }
  .header h1 { font-size:28px; margin-bottom:8px; }
  .header p { color:#cbd5e1; font-size:14px; display:flex; flex-wrap:wrap; gap:14px; justify-content:center; margin-top:10px; }
  .header p span { background:rgba(255,255,255,.06); padding:4px 10px; border-radius:20px; }
  .hero { background: linear-gradient(135deg, rgba(14,165,233,.18), rgba(16,185,129,.18)); border:1px solid rgba(56,189,248,.3); border-radius:16px; padding:22px; margin-bottom:22px; }
  .hero h2 { font-size:20px; color:#7dd3fc; margin-bottom:10px; }
  .card { background:#1e293b; border-radius:14px; padding:22px; margin-bottom:18px; border:1px solid rgba(148,163,184,.12); box-shadow: 0 6px 18px rgba(0,0,0,.35); }
  .card-title { color:#34d399; font-size:19px; margin-bottom:14px; }
  .country-tag { display:inline-block; font-size:11px; padding:3px 9px; border-radius:6px; background:#facc15; color:#422006; font-weight:600; margin-left:8px; }
  .qrcode-container { display:flex; align-items:flex-start; gap:26px; flex-wrap:wrap; }
  .qrcode-box { background:#fff; padding:10px; border-radius:10px; flex-shrink:0; }
  .qrcode-box img { display:block; width:150px; height:150px; }
  .link-info { flex:1 1 320px; min-width:300px; }
  .link-label { color:#fbbf24; font-size:13px; margin-bottom:6px; }
  .link-value { background:#0f172a; color:#f1f5f9; padding:11px 13px; border-radius:8px; word-break:break-all; font-family: ui-monospace, Consolas, monospace; font-size:12.5px; line-height:1.7; border:1px solid rgba(148,163,184,.15); }
  .copy-btn { background: linear-gradient(135deg,#0984e3,#74b9ff); color:#fff; border:none; padding:8px 16px; border-radius:7px; cursor:pointer; margin-top:10px; font-size:13.5px; font-weight:500; }
  .copy-btn.primary { background: linear-gradient(135deg,#10b981,#14b8a6); }
  .client-badges { margin-top:12px; display:flex; flex-wrap:wrap; gap:6px; }
  .badge { display:inline-flex; align-items:center; gap:4px; font-size:12px; padding:4px 10px; border-radius:999px; font-weight:500; }
  .b-rocket { background: rgba(244,114,182,.18); color:#f9a8d4; border:1px solid rgba(244,114,182,.35); }
  .b-v2ray  { background: rgba(34,197,94,.15);  color:#86efac; border:1px solid rgba(34,197,94,.35); }
  .b-neko   { background: rgba(56,189,248,.15); color:#7dd3fc; border:1px solid rgba(56,189,248,.35); }
  .b-clash  { background: rgba(167,139,250,.16); color:#c4b5fd; border:1px solid rgba(167,139,250,.35); }
  .b-sfa    { background: rgba(251,191,36,.16);  color:#fcd34d; border:1px solid rgba(251,191,36,.35); }
  @media (max-width:768px){ .qrcode-container{flex-direction:column; align-items:center;} .link-info{width:100%;} }
  .toast{position:fixed;left:50%;bottom:40px;transform:translateX(-50%) translateY(80px);background:linear-gradient(135deg,#10b981,#14b8a6);color:#022c22;padding:10px 20px;border-radius:999px;font-weight:600;font-size:14px;box-shadow:0 10px 24px rgba(16,185,129,.5);opacity:0;transition:all .35s;z-index:99999;}
  .toast.show{opacity:1;transform:translateX(-50%) translateY(0);}
</style>
</head>
<body><div class="container">
<div class="header">
  <h1>🌍 多节点多国家 · 聚合总览</h1>
  <p>
    <span id="genTime">生成中…</span>
    <span id="nodeCount">0 台机器 · 0 条节点</span>
    <span>📁 合并目录：/etc/s-box/merge</span>
  </p>
</div>
<div class="hero">
  <h2>📱 客户端工具（扫本页底部「⭐ 一键复制全部」最快</h2>
  <div style="margin-top:10px;">
    <button class="copy-btn primary" onclick="copyAllNodes()">⭐ 一键复制 <b>全部节点</b>（所有节点 URI）</button>
    <button class="copy-btn" onclick="window.open('all-nodes.txt','_blank')">📡 打开订阅链接 all-nodes.txt</button>
    <button class="copy-btn" onclick="document.getElementById('mergeQR').scrollIntoView({behavior:'smooth'})">📱 扫聚合二维码（一次导入全部）</button>
  </div>
</div>
<textarea id="allNodesText" style="position:absolute;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;"></textarea>
<div class="card" id="mergeQR" style="background:linear-gradient(135deg, rgba(52,211,153,.12),rgba(234,179,8,.12)); border:1px solid rgba(52,211,153,.35));">
  <div class="card-title">📱 聚合二维码 <span class="country-tag" style="background:#22d3ee;color:#0b1e31;">ALL</span></div>
  <div class="qrcode-container">
    <div class="qrcode-box"><img src="merge-qr.png" onerror="this.style.display='none';this.parentNode.innerHTML+='<div class=\'qr-missing\' style=\'width:150px;height:150px;background:repeating-linear-gradient(45deg,#cbd5e1,#cbd5e1 8px,#e2e8f0 8px,#e2e8f0 16px\');display:flex;align-items:center;justify-content:center;color:#64748b;font-size:11.5px;text-align:center;line-height:1.5;border-radius:4px;\'>暂无聚合二维码\n先执行方案二生成</div>'"></div>
    <div class="link-info">
      <div class="link-label">💡 用法</div>
      <div class="link-value">手机打开小火箭 / v2rayNG / NekoBox → 右上角 ➕ → 扫码 → 对准左边二维码 → 所有节点一次导入。</div>
      <button class="copy-btn primary" onclick="copyAllNodes()">⭐ 或点此复制全部节点 URI</button>
    </div>
  </div>
  <div class="client-badges"><span class="badge b-rocket">🚀 小火箭</span><span class="badge b-v2ray">🟢 v2rayNG/v2rayN</span><span class="badge b-neko">📦 NekoBox/NekoRay</span></div>
</div>
HEAD_EOF

# ---------- 遍历每台节点：生成节点卡片
total_nodes=0
total_hosts=0
for node_dir in "$WORK_DIR"/nodes/*.txt; do
  [ -f "$node_dir" ] || continue
  name=$(basename "$node_dir" .txt)
  total_hosts=$((total_hosts + 1))
  # 解析文件名示例：jp-vultr → JP · Vultr Tokyo
  country_code=$(echo "$name" | awk -F'-' '{print toupper($1)}')
  vendor=$(echo "$name" | awk -F'-' '{print $2}')
  echo "<div class=\"card-title\">💻 $country_code · $vendor <span class=\"country-tag\">$name</span></div>" >> "$INDEX"
  echo "<div style=\"font-size:13px;color:#cbd5e1;margin-bottom:12px;\">节点来源：/etc/s-box/merge/nodes/$name.txt</div>" >> "$INDEX"
  line_no=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    line_no=$((line_no+1))
    total_nodes=$((total_nodes + 1))
    proto_raw="${line%%://*}"
    proto_upper="$(echo "$proto_raw" | tr '[:lower:]' '[:upper:]')"
    # 生成二维码 PNG（如果这台机器的 PNG 已经拷贝过来了就用，没有就留占位符）
    png_file="$WORK_DIR/pngs/${name}-${proto_raw}.png"
    if [ -f "$png_file" ]; then
      cp "$png_file" "$OUT_DIR/merge-${name}-${proto_raw}.png"
      png_display="merge-${name}-${proto_raw}.png"
    else
      png_display=""
    fi
    # 写到卡片
    cat >> "$INDEX" <<CARD_EOF
<div class="card" style="margin-bottom:14px;">
  <div class="card-title">🔗 $proto_upper · 节点 $line_no <span class="country-tag" style="background:#fb923c;color:#431407;">$proto_upper</span></div>
  <div class="qrcode-container">
CARD_EOF
    if [ -n "$png_display" ]; then
      echo "    <div class=\"qrcode-box\"><img src=\"$png_display\" onerror=\"this.style.display='none';this.parentNode.innerHTML+='<div class=\\\\\\\"qr-missing\\\\\\\" style=\\\\\\\"width:150px;height:150px;background:repeating-linear-gradient(45deg,#cbd5e1,#cbd5e1 8px,#e2e8f0 8px,#e2e8f0 16px);display:flex;align-items:center;justify-content:center;color:#64748b;font-size:11.5px;text-align:center;line-height:1.5;border-radius:4px;\\\\\\\">暂无</div>'\"></div>" >> "$INDEX"
    else
      echo "    <div class=\"qrcode-box\"><div class=\"qr-missing\" style=\"width:150px;height:150px;background:repeating-linear-gradient(45deg,#cbd5e1,#cbd5e1 8px,#e2e8f0 8px,#e2e8f0 16px);display:flex;align-items:center;justify-content:center;color:#64748b;font-size:11.5px;text-align:center;line-height:1.5;border-radius:4px;\">二维码未提供<br>将 /etc/s-box/merge/pngs/${name}-*.png</div></div>" >> "$INDEX"
    fi
    # JS 转义 &quot; 用于 onclick
    esc_line="${line//\"/\\\"}"
    # 链接显示：太长截断到 160 字符加省略号
    if [ ${#line} -gt 160 ]; then
      line_display="${line:0:160}……（共 ${#line} 字符）"
    else
      line_display="$line"
    fi
    cat >> "$INDEX" <<CARD_EOF2
    <div class="link-info">
      <div class="link-label">$proto_upper 链接</div>
      <div class="link-value">$line_display</div>
      <button class="copy-btn primary" onclick="copyText('$esc_line')">📋 复制此节点</button>
    </div>
  </div>
  <div class="client-badges"><span class="badge b-rocket">🚀 小火箭</span><span class="badge b-v2ray">🟢 v2rayNG</span><span class="badge b-neko">📦 NekoBox</span><span class="badge b-clash">🐱 Clash Verge</span><span class="badge b-sfa">✨ SFA/SFI/SFM</span></div>
</div>
CARD_EOF2
  done < "$node_dir"
done

# ---------- 页脚 + JS
cat >> "$INDEX" <<'TAIL_EOF'
<div style="margin-top:24px;padding:16px;border-radius:12px;background:rgba(15,23,42,.6);border:1px dashed rgba(148,163,184,.3);font-size:13px;line-height:1.9;">
  <b>🔧 重新生成命令：</b>
  <pre style="background:rgba(14,165,233,.14);color:#7dd3fc;padding:10px 14px;border-radius:6px;margin-top:8px;line-height:1.8;"># 每新增一台子机：<br>  scp root@&lt;子机IP&gt;:"/etc/s-box/output/*/jhsub.txt" /etc/s-box/merge/nodes/xx-country.txt<br># 再执行：<br>  bash /etc/s-box/merge-page.sh</pre>
</div>
</div>
<div class="toast" id="toastOK">✅ 已复制到剪贴板</div>
<script>
document.getElementById('genTime').textContent='📅 生成时间：'+new Date().toLocaleString('zh-CN');
function showToast(){const t=document.getElementById('toastOK');t.classList.add('show');setTimeout(()=>t.classList.remove('show'),1800);}
function copyText(s){navigator.clipboard.writeText(s).then(showToast).catch(()=>{const ta=document.createElement('textarea');ta.value=s;document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove();showToast();});}
function copyAllNodes(){const all=document.getElementById('allNodesText').value.trim();copyText(all||'暂无节点');}
// 页面加载时把所有 nodes 汇总到 textarea
window.addEventListener('DOMContentLoaded',()=>{const xhr=new XMLHttpRequest();xhr.open('GET','all-nodes.txt',true);xhr.onload=()=>{if(xhr.status===200){document.getElementById('allNodesText').value=xhr.responseText;const c=xhr.responseText.split('\n').filter(l=>l.trim().length).length;document.getElementById('nodeCount').textContent=${total_hosts}+' 台机器 · '+c+' 条节点'}};xhr.send();});
</script>
</body></html>
TAIL_EOF

chmod +r "$INDEX"
echo ""
echo "✅ 聚合总览 HTML 生成完毕"
echo "   页面： http://<主控IP>/merge.html"
echo "   节点： $total_hosts 台机器 · $total_nodes 条节点"
PAGE_EOF
SCRIPT_EOF
chmod +x /etc/s-box/merge-page.sh
```

执行：

📋 **一键复制命令：**

```bash
bash /etc/s-box/merge-page.sh
```

**如果每台子机的二维码也想显示出来，执行下面把 PNG 一起拉过来（可选）：**

📋 **一键复制命令：**

```bash#
mkdir -p /etc/s-box/merge/pngs

# 方式 A：scp 批量拉（例：日本 Vultr，IP 1.2.3.4）
for proto in vl_reality hy2 tuic5 vm_ws vm_ws_tls an; do
  scp -q "root@1.2.3.4:/etc/s-box/output/*/$proto.png" "/etc/s-box/merge/pngs/jp-vultr-$proto.png" 2>/dev/null || true
done

# 方式 B：子机暴露了 nginx，用 curl HTTP 拉（不用配 SSH Key，更省事）
for proto in vl_reality vm_ws vm_ws_tls hy2 tuic5 an; do
  curl -sL "http://1.2.3.4/latest/$proto.png" -o "/etc/s-box/merge/pngs/jp-vultr-$proto.png"
  # 文件 <500 字节视为失败（404 页），删掉
  [ -s "/etc/s-box/merge/pngs/jp-vultr-$proto.png" ] && [ $(wc -c < "/etc/s-box/merge/pngs/jp-vultr-$proto.png") -lt 500 ] && rm -f "/etc/s-box/merge/pngs/jp-vultr-$proto.png"
done

# 加完一台重新生成页面
bash /etc/s-box/merge-page.sh
```

***

## 🔧 故障排查 · 一行命令速查

📋 **一键复制命令：**

```bash#
ls -lt /etc/s-box/output/ | head -5
cat "/etc/s-box/output/$(ls -1 /etc/s-box/output/ | grep -v latest | tail -1)/index.html" | head -40

# 2. 手动再生成一份 HTML（不重装 sing-box，只重做页面/二维码）
bash /etc/s-box/sb_output.sh main_output

# 3. 检查 sb.json 是否存在（首次部署核心产物）
ls -la /etc/s-box/sb.json && echo "--- Vless端口 ---" && (command -v jq >/dev/null && jq '.inbounds[0].listen_port' /etc/s-box/sb.json || echo "没装jq：yum install -y jq")

# 4. Nginx 检查
nginx -t 2>&1 | head -10
systemctl status nginx --no-pager | head -15
curl -sI http://127.0.0.1/ | head -5        # 应返回 302 → /latest/
curl -s  http://127.0.0.1/latest/ | head -5   # 应返回 <!DOCTYPE html>

# 5. 防火墙检查
ss -lntp | grep -E ':(80|443)\s'   # nginx
ss -lntp | grep -E 'in\.sing|sing-' # sing-box 监听端口（或 ss -lunp 看 UDP）
```

***

## 🌐 其他 VPN 服务补充推荐

除了本脚本自建 Sing-box，以下服务可作备用/流媒体解锁/回国路线补充：

| 名称                                  | 入口                                      | 特点                                                                                                                                                       |
| ----------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NFSQ** (奈飞社区)                     | <https://www.nfsq.us/#/dashboard>       | 老牌流媒体解锁机场，节点稳定，常见奈飞/Disney+/ChatGPT 都有                                                                                                                   |
| **起飞加速**                            | <https://xn--gmqz83awjh.org/auth/login> | 中文域名老牌机场，国内中转线路多，电信/移动/联通都友好                                                                                                                             |
| **Ghelper** (Google Chrome/Edge 插件) | Chrome 商店搜「Ghelper」                     | 浏览器插件级轻量代理，**仅对网页流量生效**，无需安装客户端。注意：Ghelper 和本脚本的系统级代理（v2rayN/Clash/小火箭）**同开会冲突** → 如果已装 Ghelper 又想用系统级代理：进 Ghelper 设置 → 「全局直连」模式关掉或把需要的域名加到白名单，或者只开其中一个。 |

***

## 🛒 服务器购买推荐

- **轻量入门**：腾讯云轻量 / 阿里云 ECS（香港/新加坡区域，月付 30-60 元，1C1G 即够用）
- **高性价比防墙**：搬瓦工 BandwagonHost / RackNerd（年付 20-50 USD，美西/日本软银线路）
- **线路参考**：国内用 → 选 三网优化/CUG/CMI/软银 线路；跨境用 → 选 9929/4837/华为云 CN2 回程

### 四、按国家 / 区域细分精选（IP 更干净、冷门、适合对 ASN/信誉敏感的项目）

| 国家                 | 供应商             | 官网                                               | 主要节点             | 特点                      | 适合用途             | 推荐程度  |
| ------------------ | --------------- | ------------------------------------------------ | ---------------- | ----------------------- | ---------------- | ----- |
| 🇮🇸 冰岛            | 1984 Hosting    | [1984.hosting](https://1984.hosting)             | Reykjavik        | 冰岛本土、小众、隐私环境好、IP 池小     | 私人 VPN、小型服务、隐私项目 | ⭐⭐⭐⭐  |
| 🇨🇭 瑞士            | Exoscale        | [exoscale.com](https://www.exoscale.com)         | Zurich、Geneva    | 瑞士本土云、企业客户多、商业信誉高       | SaaS、API、企业 VPN  | ⭐⭐⭐⭐⭐ |
| 🇨🇭 瑞士            | CloudScale      | [cloudscale.ch](https://www.cloudscale.ch)       | Zurich           | 瑞士本土云，体验类似 DigitalOcean | Docker、网站、API 服务 | ⭐⭐⭐⭐  |
| 🇫🇮 芬兰            | UpCloud         | [upcloud.com](https://upcloud.com)               | Helsinki         | 北欧云服务商，性能稳定，企业用户多       | VPS、VPN、Web 服务   | ⭐⭐⭐⭐⭐ |
| 🇦🇹 奥地利 / 🇩🇪 德国 | netcup          | [netcup.com](https://www.netcup.com)             | Vienna、Nuremberg | 性价比高，欧洲老牌 VPS           | VPS、代理节点、网站      | ⭐⭐⭐⭐⭐ |
| 🇳🇴 挪威            | UpCloud         | [upcloud.com](https://upcloud.com)               | Nordic 区域        | 北欧网络，小众 IP 资源           | VPN、测试节点         | ⭐⭐⭐⭐  |
| 🇸🇪 瑞典            | Bahnhof         | [bahnhof.se](https://bahnhof.se)                 | Stockholm        | 瑞典本土 ISP，隐私领域知名         | 隐私服务、小型项目        | ⭐⭐⭐⭐  |
| 🇪🇪 爱沙尼亚          | Zone Media      | [zone.ee](https://www.zone.ee)                   | Tallinn          | 数字国家，本土 IT 企业多          | 欧洲网站、测试环境        | ⭐⭐⭐⭐  |
| 🇵🇱 波兰            | UpCloud         | [upcloud.com](https://upcloud.com)               | Warsaw           | 东欧节点，用户较少               | 欧洲业务、VPN         | ⭐⭐⭐⭐  |
| 🇨🇦 加拿大           | OVHcloud        | [ovhcloud.com](https://www.ovhcloud.com)         | Montreal、Toronto | 北美节点，比美国热门区域冷门          | 北美业务、服务器         | ⭐⭐⭐⭐  |
| 🇳🇿 新西兰           | SiteHost        | [sitehost.nz](https://www.sitehost.nz)           | Auckland         | 新西兰本土，用户少               | 新西兰业务、小型服务       | ⭐⭐⭐   |
| 🇦🇺 澳大利亚          | VPSBlocks       | [vpsblocks.com.au](https://www.vpsblocks.com.au) | Sydney、Melbourne | 澳洲本土 VPS                | 澳洲市场、Web 服务      | ⭐⭐⭐⭐  |
| 🇯🇵 日本            | Sakura Internet | [sakura.ad.jp](https://www.sakura.ad.jp)         | Tokyo、Osaka      | 日本老牌 IDC，本土客户多          | 亚洲访问、跨境业务        | ⭐⭐⭐⭐⭐ |
| 🇰🇷 韩国            | Cafe24 Cloud    | [cafe24.com](https://www.cafe24.com)             | Seoul            | 韩国电商生态强                 | 韩国市场、电商服务        | ⭐⭐⭐⭐  |

> 🔎 **用法建议**：先用上面清单挑好区域 + 供应商 → 买完拿到 IP → **立刻用** **`bash /etc/s-box/ip-check.sh`** **做体检**（或 `PRECHECK_IP=1 bash vpn.sh` 在部署前自动预检）→ PASS/WARNING 再继续部署；FAIL 直接删机重建换 IP。

### 五、按用途场景推荐（4 类核心用法）

#### 1️⃣ 个人 VPN / 科学上网 / 远程访问（日常使用优先级）

| 排名 | 服务器                   | 原因        |
| -- | --------------------- | --------- |
| 1  | 🇯🇵 Sakura Internet  | 亚洲延迟低     |
| 2  | 🇫🇮 UpCloud Helsinki | 稳定、IP 质量好 |
| 3  | 🇨🇭 Exoscale         | 商业信誉高     |
| 4  | 🇦🇹 netcup           | 便宜高性价比    |
| 5  | 🇮🇸 1984 Hosting     | 小众        |

#### 2️⃣ Amazon / TikTok / 跨境电商后台环境（节点 → 市场匹配）

| 用途（目标市场）        | 推荐节点                       |
| --------------- | -------------------------- |
| 美国市场            | 🇨🇦 加拿大 Toronto、🇺🇸 美国中部 |
| 欧洲市场            | 🇨🇭 瑞士、🇫🇮 芬兰、🇩🇪 德国    |
| 日本市场            | 🇯🇵 Tokyo                 |
| 韩国市场            | 🇰🇷 Seoul                 |
| 亚洲管理入口（跳板 / 中控） | 🇯🇵 日本、🇸🇬 新加坡           |

> ⚠️ **跨境运营重要提示**：上面只能解决「后台访问速度」和「IP 不脏」的问题；要**真正过 Amazon / TikTok 账号风控**，还需要：住宅 IP / 移动 IP 池（不是机房 IP）、浏览器指纹隔离（AdsPower / Multilogin / Dolphin{anty}）、独立的信用卡 / 收款 / 手机号段，和本仓库 `vpn.sh` 的机房 VPN 体系是两条线。

#### 3️⃣ 小众 IP 优先（避开热门 / 风控扫网段，排名越高越冷门）

| 排名 | 国家        | 原因        |
| -- | --------- | --------- |
| 🥇 | 🇮🇸 冰岛   | 用户少，IP 池小 |
| 🥈 | 🇨🇭 瑞士   | 商业用户比例高   |
| 🥉 | 🇫🇮 芬兰   | 北欧企业环境    |
| 4  | 🇳🇿 新西兰  | 非常小众      |
| 5  | 🇪🇪 爱沙尼亚 | 数字国家      |

#### 4️⃣ 性价比最高（固定预算 + 长期跑的首选）

| 供应商        | 价格区间          | 特点   |
| ---------- | ------------- | ---- |
| netcup     | €3 \~ 6 / 月   | 配置高  |
| UpCloud    | $5 \~ 10 / 月  | 性能强  |
| CloudScale | $5 / 月起       | 瑞士云  |
| Sakura     | 约 500 日元 / 月起 | 日本稳定 |
| OVH Canada | $5 / 月起       | 北美资源 |

### 六、长期运营（Amazon / TikTok / 广告账号 / SaaS）首选组合（从高到低）

| 优先级   | 组合（跨区域多节点）                                       | 适用场景说明                                                                     |
| ----- | ------------------------------------------------ | -------------------------------------------------------------------------- |
| ⭐⭐⭐⭐⭐ | 🇨🇭 瑞士 Exoscale + 🇯🇵 日本 Sakura + 🇨🇦 加拿大 OVH | 欧美 / 亚太 / 北美三地全覆盖；瑞士商业信誉 + 日本低延迟 + 加拿大冷门北美 IP，适合 SaaS + 跨境电商后台 + 多区域账号并行运营 |
| ⭐⭐⭐⭐  | 🇫🇮 芬兰 UpCloud + 🇦🇹 / 🇩🇪 netcup             | 欧洲双节点，性价比极高；芬兰企业级 IP + netcup 大带宽，适合欧洲站 Amazon / Otto / Zalando + 广告投放账户   |
| ⭐⭐⭐   | 🇮🇸 冰岛 1984 Hosting + 🇳🇿 新西兰 SiteHost         | 极其冷门的两极组合；冰岛隐私向 + 新西兰独立 IP 池，适合小众账号池、测试隔离环境、非热门区域小站点                       |

> 💡 **组合思路**：不要把鸡蛋放在同一个 ASN / 同一批子网 / 同一个机房。多供应商 + 多国家 + 多 ASN 是长期运营抗风控的第一原则；**单台 VPS 再便宜，也不如跨区域组合抗封禁**。

### 七、VPS 到手必做的 5 项 IP 检测（一个都不能省）

| 检测项目              | 推荐工具（手动查）                      | 本仓库 `vpn.sh` 自动检测对应项                                   |
| ----------------- | ------------------------------ | ------------------------------------------------------ |
| IP 信誉             | IPQualityScore                 | `ip-check.sh` 第 6 项 · IPQualityScore Fraud / VPN / Tor |
| 黑名单               | AbuseIPDB                      | `ip-check.sh` 第 5 项 · AbuseIPDB 90 天报告数 + 滥用评分         |
| 代理 / VPN 识别       | Scamalytics                    | `ip-check.sh` 第 7 项 · Scamalytics 欺诈评分 + Risk 标签       |
| ASN 归属 / 网段查询     | Hurricane Electric BGP Toolkit | `ip-check.sh` 第 2 项 · Geo + ASN 组织名 + 云商白名单校验          |
| 地理定位（国家 / 州 / 城市） | MaxMind GeoIP                  | `ip-check.sh` 第 1 项 · ip-api（MaxMind 兼容字段，免 API Key）   |

> 🔗 **手动查快捷入口**：
>
> - IPQualityScore：<https://www.ipqualityscore.com/free-ip-lookup-proxy-vpn-test>
> - AbuseIPDB：<https://www.abuseipdb.com/check/>
> - Scamalytics：<https://scamalytics.com/ip/>
> - Hurricane Electric BGP Toolkit：<https://bgp.he.net/>
> - MaxMind GeoIP Demo：<https://www.maxmind.com/en/geoip2-precision-demo>
>
> 一键自动跑（推荐，省掉 5 个网站逐一点）：
>
> ```bash
> PRECHECK_IP=1  bash vpn.sh                              # 部署 VPN 之前自动做全套体检
> # 或
> bash /etc/s-box/ip-check.sh  <公网IP>                   # 单独跑体检，JSON 档案自动落盘
> ```

> 🚨 **金句（跨境电商/账号运营一定要记住）**：
> **对于跨境电商环境，一个稳定、历史干净的 IP，比一个便宜 10 倍的 VPS 更有价值。**
> — IP 被标记一次 = 账号关联风险 = 损失可能是 VPS 年费的几十到上百倍。

***

## 📚 附录：自建 VPN / 代理服务 从 0 到 1 完整指南

如果想搭 VPN（更准确说是**自建代理 / VPN 服务**），核心就是：**一台有公网 IP 的服务器 + VPN/代理软件 + 域名/证书（可选）**。

### 一、海外云服务器（最推荐）

**适合**：个人使用、跨境电商、远程办公、访问海外资源、搭建代理节点。

| 服务商                       | 节点地区         | 特点              | 价格参考         |
| ------------------------- | ------------ | --------------- | ------------ |
| Vultr                     | 美国、日本、新加坡、欧洲 | 老牌 VPS，开通快，IP 多 | $3.5 \~ 5/月起 |
| DigitalOcean              | 美国、新加坡、德国等   | 稳定，文档丰富         | $4 \~ 6/月起   |
| Linode                    | 美国、日本、新加坡等   | 性能稳定            | $5/月起        |
| Hetzner                   | 德国、芬兰、新加坡    | 性价比极高           | €4 \~ 5/月起   |
| Amazon Web Services (AWS) | 全球           | 企业级，复杂度高        | 按量计费         |
| Google Cloud (GCP)        | 全球           | 免费额度，IP 资源丰富    | 按量计费         |
| Microsoft Azure           | 全球           | 企业用户多           | 按量计费         |

### 二、针对中国大陆访问速度优化的 VPS

如果主要用户在中国大陆，优先选下面的节点 + 服务商：

#### 1. 日本节点（东京 / 大阪）

- **优势**：延迟低、晚高峰相对稳定
- **推荐**：Vultr Tokyo / Linode Tokyo / AWS Tokyo

#### 2. 新加坡节点

- **优势**：亚洲线路较好，适合跨境电商（东南亚 Shopee / Lazada / TikTok）
- **推荐**：Vultr Singapore / DigitalOcean Singapore

#### 3. 香港节点

- **优势**：延迟最低（深圳 ping 香港 10ms 内）
- **缺点**：**贵 + IP 容易受限制**
- **推荐**：阿里云香港 / 腾讯云香港 / Vultr Hong Kong

### 三、常用 VPN / 代理软件选型

| 方案                          | 适用场景                          | 特点                                                                                                                      |
| --------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **🟢 WireGuard（优先推荐）**      | 自己用 / 家庭 VPN / 公司远程访问 RDP/SSH | ✅ 目前最先进：速度快、代码少、CPU 占用极低、手机原生支持好❌ 本身不伪装，用于跨境敏感流量建议配合外层 sing-box / 隧道                                                    |
| **OpenVPN**                 | 老设备 / 跨平台兼容性优先                | ✅ 最成熟、支持最广泛❌ 速度比 WireGuard 慢 30%\~50%                                                                                   |
| **Xray / V2Ray / sing-box** | 抗干扰 / 多协议伪装 / 跨境日常使用（本仓库采用）   | ✅ 抗干扰能力极强、灵活（VLESS / VMess / Trojan / Shadowsocks / Reality / Hysteria2 / Tuic …）、多用户管理方便❌ 配置略复杂（所以本仓库提供 `vpn.sh` 一键搞定） |

**sing-box（本仓库）数据流示意**：

```
 手机/电脑（小火箭 / v2rayNG / v2rayN / Clash Verge …）
        │
   sing-box 客户端
        │
   VLESS Reality / VMess-WS / Hysteria-2 / Tuic …
        │
  海外 VPS（sing-box 服务端 /etc/s-box/sb.json）
        │
     Internet
```

### 四、常用一键搭建脚本汇总

> 你之前用过的 [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) 就在下面👇。

#### 👉 WireGuard（简单场景 / 远程办公首选）

📋 **一键复制命令：**

```bash
curl -O https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh
```

#### 👉 sing-box / Xray（抗干扰 / 日常跨境首选）

📋 **一键复制命令：**

```bash#
bash <(curl -Ls https://raw.githubusercontent.com/233boy/sing-box/main/install.sh)

# ② yonggekkk sing-box-yg（本仓库 vpn.sh 的底层原型）
bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)

# ③ 本仓库 vpn.sh（上面两者优势 + Nginx 页面扫码 + 客户端说明 + 0 交互）
#    → 见文档顶部「🎯 脚本对比」章节，直接从 doomsangle/Lisa-server 拉取。
```

### 五、服务器配置建议

| 场景                     | 最低配置                                                 | 推荐配置                                       | 实例参考                                               |
| ---------------------- | ---------------------------------------------------- | ------------------------------------------ | -------------------------------------------------- |
| **个人使用（1-3 人）**        | 1 CPU / 512MB RAM / 10GB SSD / 500Mbps+ / 500GB/月 流量 | 1 CPU / 1GB RAM / 20GB SSD / 1TB/月         | Vultr $5/月：1C / 1GB / 25GB SSD / 1TB 流量 → **完全够用** |
| **多人 / 公司办公室（5-20 人）** | 2 CPU / 2GB RAM / 40GB SSD / 2TB+ 流量                 | 4 CPU / 4GB RAM / 80GB SSD / 5TB+ / 1Gbps+ | Hetzner CX22 / AWS Lightsail $10                   |

### 六、跨境电商场景（Amazon / TikTok Shop / 独立站）特别建议

如果是做 **Amazon Seller Central / TikTok US Shop / 美国广告账号 / 日本市场**，建议按业务目的**拆节点组合**，不要所有账号共用 1 个 IP：

```
              国内运营电脑（Clash / sing-box 规则分流）
                          │
          ┌───────────────┴───────────────┐
     美国 VPS 节点                    日本/新加坡 VPS 节点
          │                                    │
  ┌───────┼────────┐                   ┌──────┴──────┐
Amazon   TikTok   美国广告         日本乐天   亚洲采购
后台      Shop    账号            /Mercari  /客服日常
```

| 业务需求                                    | 节点位置                         |
| --------------------------------------- | ---------------------------- |
| Amazon Seller Central 美国站 / Vendor      | **美国西海岸（洛杉矶/西雅图/波特兰）**       |
| TikTok US Shop / Meta 美国广告 / Google Ads | **美国东海岸（弗吉尼亚/纽约）+ 住宅 IP 混跑** |
| 日本市场（Amazon JP / Rakuten / Mercari）     | **东京**                       |
| 东南亚电商（Shopee/Lazada/TikTok SG/MY/TH）    | **新加坡**                      |
| 国内运营人员日常访问 + 后台轻量切换                     | **香港 / 新加坡**（低延迟日常用）         |

### 七、❌ 不建议的 3 种方案

1. **家庭宽带搭 VPN / 代理** — IP 质量差、动态 IP 跳、上行带宽经常断；**完全不适合 Amazon / TikTok 多账号**。
2. **免费 VPS（Oracle 永久免费等）** — IP 被几十万人滥用，Google/Amazon 验证码极多，风控概率飙升到你怀疑人生。
3. **廉价共享 VPN（机场 9.9 元/月等）** — 100+ 人共用同一个 IP → 全部挤着登录 Amazon/TikTok → **必触发风控关联**。

### 八、给当前场景的推荐架构（Lisa 多账号管理系统）

如果你的核心用途是 **Amazon + TikTok 多账号管理 + 服务器日常部署**，建议长期架构：

```
            国内运营电脑（Clash Verge Rev 做规则分流）
                          │
        ┌─────────────────┴─────────────────┐
   美国 VPS 节点（1）                日本 VPS 节点（2）
   （洛杉矶 / 西雅图 / 纽约）           （东京 / 新加坡）
        │                                     │
 Amazon / TikTok Shop                 日本站 / 日常跨境访问
     多账号
```

**服务器推荐优先级**（从易到难 + 性价比递减）：

1. Vultr 美国 / 日本（**首选**，开通即有独立干净 IP、速度够、支付宝/微信能付）
2. Hetzner 欧洲（**性价比天花板**，€4/月起、带宽超大；缺点：IP 对 Amazon JP 风控略逊于东京本土 IP）
3. AWS Lightsail / DigitalOcean（流量少但线路干净）
4. 阿里云香港 / 腾讯云香港（国内日常访问最快，但给海外电商用 IP 容易被识别成"机房代理"）

***

### ⚠️ 特别警告：跨境电商多账号 & 普通 VPS VPN 不是一个体系

> 🚨 **普通 VPS + sing-box VPN（本仓库提供的体系）只能解决：日常浏览、看视频、远程办公、独立站后台访问速度问题。**
>
> 🚨 **不能 100% 解决 Amazon / TikTok 多账号运营的风控关联问题。**
>
> 如果你要做**规模化多账号矩阵**，还需要考虑：**IP 信誉 / ASN 归属 / 住宅 IP 或 移动 IP（不是机房 IP）/ 浏览器指纹隔离（AdsPower / Multilogin / 候鸟浏览器）/ 代理链路纯净度 / 账号注册环境（手机号 / 收货地址 / 信用卡 BIN）** 等一整套账号环境隔离体系 —— 这部分和本仓库的「纯网络层代理」是两个不同的技术栈。

***

## 🛡️ 专业流程：VPS 到手先做 IP 健康体检 → 再部署 VPN

无论你是日常跨境，还是做 **Amazon/TikTok 多账号风控**，都强烈建议严格按下面流程走一遍再部署 vpn.sh——能直接规避未来 70%+ 的**无理由风控 / 关联 / 验证码风暴**。

### 标准 5 步流程图

```
① 购买 VPS → ② 拿到公网 IP → ③ Geo + ASN + 黑名单 + 信誉 + 指纹 5 项检测
                                                               │
                                                               ├─ PASS / WARNING → ④ 部署 vpn.sh
                                                               │
                                                               └─ FAIL → ⑤ 换 IP（重建实例 / 换机房 / 换区域）→ 回到 ② 重测
```

### 一、5 大工具手动查（5 分钟看完，不用写脚本）

> 💡 全部**免费网页版**即可；如果以后要批量买机，可以直接套下面的 [ip-check.sh](./ip-check.sh) 一键跑完。

| # | 工具                                       | 手动查询入口                                                         | 查什么                                                                    | 免费额度               | 判定阈值（越干净越好）                                                                                                                                                                  |
| - | ---------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **MaxMind GeoIP2**（地理定位基准）               | <https://www.maxmind.com/en/geoip2-precision-demo>             | 国家 / 城市 / ISP / 运营商归属                                                  | 单个 IP 免费查          | ✅ 国家/城市 和你购买机房所在地一致； ❌ 显示 A 国实际是 B 国（AnyCast / 回带宽选）→ 换 IP                                                                                                                   |
| 2 | **AbuseIPDB**（滥用举报）                      | <https://www.abuseipdb.com/check/>                             | 90 天内暴力破解 / 扫描 / 邮件滥用 / 爬虫举报数 + 置信度                                    | 1000 次/天（注册后 API）  | ✅ 置信度 **≤5% 且报告数 ≤5**；⚠️ 5%\~25% 日常能用；❌ **>25% 直接换**                                                                                                                         |
| 3 | **IPQualityScore**（欺诈/VPN 指纹）            | <https://www.ipqualityscore.com/free-ip-lookup-proxy-vpn-test> | Fraud Score + VPN/Proxy/Bot + Recent Abuse                             | 5000 次/月（免费 API）   | ✅ Fraud **≤20 且 VPN=F & Proxy=F & Bot=F**；❌ **>40 或 RecentAbuse=true → 立刻换**                                                                                                 |
| 4 | **Scamalytics**（欺诈历史画像）                  | <https://scamalytics.com/ip/>                                  | Risk Score / 风险等级（越高越差）                                                | 网页无限查              | ✅ Risk **≤25**；⚠️ 26\~50 日常可用；❌ **>50 → 换 IP**                                                                                                                               |
| 5 | **Spur.us**（深度指纹：住宅 / 机房 / VPN 节点 / Tor） | `https://spur.us/app/context/<你的IP>`                           | Tag / vpnOperators / services（直接告诉你：这 IP 是哪家云厂商机房、还是谁家 VPN 节点、还是真住宅宽带） | 单查免费；教育/试用 API 可申请 | ✅ 电商多账号主节点优先选 Tag = **residential / business / isp / mobile**；⚠️ Tag = **datacenter / server**（典型 VPS）日常跨境可用，但不建议做多账号**主节点**；❌ Tag = **VPN / Proxy / Anonymous / Tor → 直接换** |
| 6 | **MxToolbox 综合 RBL 黑名单**                 | <https://mxtoolbox.com/SuperTool.aspx?action=blacklist>        | 60+ 个 DNSBL 黑名单命中率                                                     | 免费                 | ✅ 命中 ≤3 条；⚠️ 4\~10 条；❌ 超过 10 条                                                                                                                                               |

### 二、综合判定阈值

| 判定             | 门槛                                                                                                     | 下一步                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| ✅ **PASS**     | Geo 对得上 + AbuseIPDB ≤5% + RBL 0 命中 + Spur 非匿名/非 VPN + IPQS Fraud ≤20 + Scamalytics Risk ≤25            | 直接 `bash vpn.sh` 部署                                                        |
| ⚠️ **WARNING** | 典型机房 ASN（Vultr/Hetzner/DigitalOcean/Linode/AWS…这类云厂商本来就是 datacenter Tag，这很正常）+ Abuse/IPQS 有零星污点但未过红线   | 日常跨境 / 远程办公 / 独立站后台 → OK；**做 Amazon/TikTok 多账号核心主节点 → 建议换住宅 IP / 移动 IP 池** |
| ❌ **FAIL**     | Abuse Confidence >25% / IPQS Fraud >40 / Spur Tag=VPN·Anonymous·Tor / RBL >10 条 / Scamalytics Risk >75 | **VPS 面板「重建实例」拿新 IP，或换机房/换区域 → 重测直到 WARNING/PASS**                         |

### 三、一键脚本自动跑（附 JSON 落盘，留档给多账号系统）

项目里配套 **[ip-check.sh](./ip-check.sh)**（7 项检测 + 加权评分 + PASS/WARNING/FAIL 结论 + 落盘 JSON 档案）：

📋 **一键复制命令：**

```bash#
export ABUSEIPDB_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx      # https://www.abuseipdb.com/  → 1000 次/天
export IPQS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx              # https://ipqualityscore.com → 5000 次/月
export SCAMALYTICS_KEY=xxxxxxxx                                # https://scamalytics.com   → 有免费 API 层
export SPUR_TOKEN=xxxxxxxx                                     # https://spur.us           → 教育/试用额度可申请

# ② A. 自动检测本机公网 IP（部署前先跑这个）
bash ip-check.sh

# ② B. 或手动指定任意 IP 查
bash ip-check.sh 64.81.25.225
```

**脚本 7 项权重表：**

| # | 检测项                              | 是否必须 Key                    | 权重  |
| - | -------------------------------- | --------------------------- | --- |
| 1 | 🌍 Geo 定位（ip-api + ipinfo 双源互校）  | ❌ 免费                        | 10% |
| 2 | 🏢 ASN 归属（机房 / 住宅 / 校园 / 企业）     | ❌ 免费                        | 15% |
| 3 | 🚫 RBL（6 源 DNS 公开黑名单）            | ❌ 免费                        | 20% |
| 4 | 🛡 AbuseIPDB（滥用举报）               | ✅ ABUSEIPDB\_KEY            | 20% |
| 5 | ⚡ IPQualityScore（欺诈 / VPN / Bot） | ✅ IPQS\_KEY                 | 15% |
| 6 | 🔍 Scamalytics（Risk Score）       | ❌ 免费（网页 HTML 抓取）/ ✅ Key（更准） | 10% |
| 7 | 🕵️ Spur.us（深度指纹）                | ✅ SPUR\_TOKEN               | 10% |

脚本跑完落盘 JSON：`/tmp/ip-check-<目标IP>.json`，里面带 `verdict / final_score / geo / asn / rbl / abuseipdb / ipqualityscore / scamalytics / spur` 全部字段——方便 Lisa 多账号系统对接做「IP 档案」。

***

### 四、Amazon / TikTok 多账号场景额外提醒 ⚠️

1. **普通 VPS 机房 IP（= 本仓库 vpn.sh 的部署形态）只能解决：日常跨境、看视频、远程办公、独立站后台访问速度问题。**
2. **它不能 100% 解决电商多账号「风控关联」问题。**
3. 如果要做规模化多账号矩阵，还需要一整套完整体系：
   - **网络层**：住宅 IP / 移动 IP（不是机房 IP）+ 纯净链路，ASN/Spur Tag 都要 residential；
   - **指纹层**：AdsPower / Multilogin / 候鸟浏览器等指纹隔离工具，**每个账号绑定独立指纹环境**；
   - **账号层**：注册手机号、收货地址、信用卡 BIN、注册邮箱 / 辅助验证号都要独立；
   - **操作层**：操作轨迹、登录频率、下单/发货节奏要模拟真人；
4. 如果你只要日常跨境 + 偶尔登录 1\~2 个 Seller Central 后台，用本仓库 vpn.sh + WARNING 以上的 IP 就完全够用。

***

### 五、IPv6 双栈支持说明（2026-07-20 新增 ✅）

`ip-check.sh`（以及 `vpn.sh` 内嵌的预检逻辑）从**只支持 IPv4**升级为 **IPv4 优先 → 失败自动 fallback 到 IPv6** 的双栈模式：

| 阶段                         | 获取方式               | 3 个公网查询源                                         | 超时    |
| -------------------------- | ------------------ | ------------------------------------------------ | ----- |
| ① 第一优先                     | `curl -4`（强制 IPv4） | `ifconfig.me` → `icanhazip.com` → `ipinfo.io/ip` | 每个 8s |
| ② 自动 fallback（第①阶段取不到时才触发） | `curl -6`（强制 IPv6） | 同样 3 个源，再重试一遍                                    | 每个 8s |

#### IP 类型处理对照表（跑脚本后自动生效，不用手动配置）

| 类型   | 正则校验                                  | 自动取值变量                         | RBL 黑名单处理                                |
| ---- | ------------------------------------- | ------------------------------ | ---------------------------------------- |
| IPv4 | `^([0-9]{1,3}\.){3}[0-9]{1,3}$`       | `IP_VER="4"` + `REV_IP` 反向拼接   | ✅ 正常 6 源 DNS 查询（zen.spamhaus.org 等）      |
| IPv6 | `^[0-9a-fA-F:]{2,39}$` + 必须包含至少 1 个冒号 | `IP_VER="6"` + `REV_IP=""`（置空） | ⏭️ **自动跳过**（公开 DNSBL 对 IPv6 支持极少，计满分不扣分） |

> 💡 **说明**：除 RBL 之外的其余 6 项检测（🌍 Geo 定位 / 🏢 ASN 归属 / 🛡 AbuseIPDB / ⚡ IPQualityScore / 🔍 Scamalytics / 🕵️ Spur.us）对 **IPv4、IPv6 全部生效**，逻辑完全一致，不用额外配置。

#### 快速使用示例

📋 **一键复制命令：**

```bash#
PRECHECK_IP=1  bash vpn.sh

# 2) 手动指定 IPv6 地址进行体检
bash /etc/s-box/ip-check.sh  240c:xxxx:xxxx:xxxx::1

# 3) 看体检输出的标题栏，能看到「目标 IP」自动识别是 IPv4 还是 IPv6
```

***

购买 & 部署后有任何问题：把 `bash ip-check.sh` 的最终评分 + `bash vpn.sh` 的完整输出 + `curl -s http://127.0.0.1/latest/ | head -20` + `cat /etc/os-release | head -5` 贴出来即可快速定位 🐛。
