# 🚀 Lisa 主机 VPN 一键搭建脚本

基于 [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) 的 **sing-box 多协议 + Nginx 页面一键部署脚本**。一次 `bash vpn.sh`，完成：
- Sing-box 协议部署（Vless-Reality、Vmess-WS、Vmess-WS-TLS、Hysteria-2、Tuic-v5、Anytls、Argo 隧道…）
- 自动生成日期文件夹（`YYYYMMDD-N`）+ 二维码 + 链接 + 聚合节点
- 自动安装 Nginx 并配置静态站点，**直接访问服务器 IP 就能查看配置页面**
- 内含完整客户端工具说明（🚀 小火箭 Shadowrocket / v2rayNG / NekoBox / Clash Verge / sing-box 官方 SFA·SFI·SFM…）和扫码导入教程

---

## 📁 文件清单

| 文件 | 说明 |
|------|------|
| **[vpn.sh](./vpn.sh)** | ✅ **唯一主脚本**，上传到服务器执行即可。`sb_output.sh` 辅助脚本、`sb.sh` 补丁、Nginx 配置、客户端工具/Hero/Badge/教程 HTML 模板都**内嵌其中**。 |
| **README.md** | 本文档。 |

---

## 🎯 脚本对比：原版 sb.sh vs 本仓库 vpn.sh

| 项目 | 原版 sing-box-yg（sb.sh） | 本仓库 vpn.sh（✅ 推荐） |
|------|---------------------------|--------------------------|
| **一行执行命令** | ```bash
bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
``` | ✅ **海外服务器**（能直接访问 GitHub raw）：
```bash
bash <(wget -qO- https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
```
🐌 **国内服务器**（GitHub raw 超时）走 gh-proxy 加速：
```bash
bash <(wget -qO- https://gh-proxy.com/https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
``` |
| **部署交互** | 需手动按菜单：`9` 安装 → `15` 生成分享 | **0 交互全自动**（内置 wget 预检查、sb.sh 补丁、Nginx 安装配置、防火墙放行…） |
| **产出物** | 终端打印文字链接（无二维码 / 无 HTML 页面）| 日期文件夹 `YYYYMMDD-N/` + 二维码 `.png` + **完整响应式 HTML 页面**（Hero 6 平台 Tabs + 每张协议 5 色 Badge + 聚合节点⭐一键复制 + 扫码教程折叠面板 + FAQ/Ghelper 冲突说明 + 使用小贴士卡片）|
| **访问方式** | 一条条复制终端文字，手机粘贴 | 浏览器打开 `http://<IP>/latest/` → 扫码 / 一键复制全部 |
| **Nginx** | 无 | ✅ 自动安装（apt/yum/dnf 自适应）+ 覆盖默认站点 root → /etc/s-box/output + 302 `/` → `/latest/` 软链 |
| **新机器依赖** | 需要先手动 `yum install -y wget` | ✅ 自动补 wget / qrencode；CRLF 换行符自动修复 |
| **链接稳定性** | 同（都基于 sb.json 只生成一次）| 同 |
| **主页 / 仓库** | [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | **[doomsangle/Lisa-server](https://github.com/doomsangle/Lisa-server)**（你自己的仓库）|

---

## 🚀 部署步骤（3+1 种方式，任选其一）

### ⭐ 方式 A（最快，无需本地文件）：服务器直接从你的 GitHub 拉取
**不用本地下载 vpn.sh、不用 scp 传文件，SSH 进服务器粘贴 1 行就完事。**
```bash
# 1) 海外机器 / 能直接访问 GitHub raw
bash <(wget -qO- https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)

# 2) 国内机器（GitHub raw 常超时）→ gh-proxy.com 加速镜像
bash <(wget -qO- https://gh-proxy.com/https://raw.githubusercontent.com/doomsangle/Lisa-server/main/vpn.sh)
```
> 跑完看输出里的部署完成提示 → 浏览器打开 `http://<服务器IP>/latest/` 就能看到配置页面。

### 方式 B（本地改了脚本 → 传服务器）：scp 上传 vpn.sh

#### 第 1 步：上传到服务器

```bash
scp -O vpn.sh root@<你的服务器IP>:~
# 或用 Xftp / WinSCP 等工具（传完记得校验文件大小≈60KB）
```

> 💡 **Windows → Linux 必看**：本脚本已强制锁定为 **LF + UTF-8 无 BOM**。如果你用某些工具（如记事本、老版 SecureCRT）另存后上传出现下面的报错：
> ```
> set: usage: set [-abefhkmnptuvxBCHP] ...
> vpn.sh: line 4: $'\r': command not found
> ```
> 在服务器上当场 1 秒修复：
> ```bash
> sed -i 's/\r//' vpn.sh && chmod +x vpn.sh && bash vpn.sh
> ```

### 第 2 步：执行

```bash
ssh root@<你的服务器IP>
chmod +x vpn.sh
bash vpn.sh
```

全程无需任何交互（内置：
- ✅ 新机器自动 `yum install -y wget`
- ✅ 下载并 patch 原版 sb.sh（打 patch：在 sbshare 函数里调用 sb_output.sh 生成 HTML 页面）
- ✅ 部署 sb_output.sh 到 /etc/s-box/sb_output.sh
- ✅ 一键安装 Sing-box（默认执行 sb.sh 选项 9 + 15 生成分享）
- ✅ 自动安装 Nginx（apt/yum/dnf 自适应）+ 覆盖默认站点（root → /etc/s-box/output，index /latest 302 跳到最新一份）
- ✅ 自动放行系统防火墙 ufw / firewalld / iptables）

### 第 3 步：访问页面

脚本结束时会输出：

```
========================================
✅ 部署完成！请访问：
   http://<服务器IP>/latest/            ← 推荐，永远是最新一份
   http://<服务器IP>/<日期文件夹>/
========================================
```

浏览器打开即可看到：**Hero 客户端工具卡片 + 6 平台 Tabs + 每个协议客户端 Badge + 聚合节点 ⭐一键复制 + 协议详情卡 + 折叠扫码教程 + FAQ（Ghelper 冲突/502/二维码缺失…）+ Tips 卡片** —— 完整页面 💻📱

---

## 📂 服务器端输出目录结构

```
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

---

## ❓ 重复执行 FAQ

| 问题 | 答案 |
|------|------|
| 重新执行 `bash vpn.sh`，**已有的 VPN 链接/二维码会不会变？** | **不会**。Sing-box 的 `sb.json` 只在**第一次部署**时生成一份（在 `/etc/s-box/sb.json`），后续重复执行**不改动 sb.json**，只是把这些「已有的链接」重新收集成一份新的 HTML 页面，存到 `output/YYYYMMDD-N/` 新文件夹里。**正在使用的手机/电脑客户端完全不受影响**。 |
| 既然链接不变，为什么每次还要生成新的日期文件夹？ | 方便回溯、方便分享给不同朋友（每份独立 URL），并保留一份历史快照（txt + png + html 三联备份）。 |
| 我想**重新生成端口/UUID/密码**可以吗？ | 可以，但**会让旧链接全部失效**（手机上的节点要全部重新导入）。操作方法：先删 `/etc/s-box/sb.json` → 再 `bash vpn.sh`，脚本会走完整首次部署流程，生成全新的 sb.json 和对应的新链接。 |
| 改了 Nginx root 路径或服务器 IP，vpn.sh 需要同步改吗？ | **不需要**。vpn.sh 的 Nginx 配置固定把 `root /etc/s-box/output;` 写入 Nginx 默认站点，且用 `try_files /latest/index.html =404;` + 302 `/` → `/latest/`。只要你没动 `/etc/s-box/output` 目录本身，所有改动（换 IP、重启 Nginx、重装系统后恢复 output 目录）都无需重写 vpn.sh。 |
| 服务器上没有 qrencode，页面里二维码会不会破图？ | 不会。页面会显示**条纹占位图**（代替破图 ×）并写文字说明「请点复制链接，在客户端粘贴同样可用」，不影响使用。想要真二维码：`yum install -y qrencode` 后再 `bash /etc/s-box/sb_output.sh main_output` 重新生成一份 HTML。 |
| 为什么页面里「生成时间」/「主机名」有时是空？ | 之前老版本是在 heredoc 里嵌 `$(date ...)`，中间层 SSH/代理会吞掉 `%`。**最新 vpn.sh 已修复**：① generate_html 顶部先把 `gen_time` / `hostname` 算成 bash 变量+默认值兜底；② HTML 写完再 `sed -i` 横扫 8 条规则，把残留字面量（`$gen_time` / `$(date ...)` / `$hostname` / `$DATE_FOLDER`）全部替回真实值。只要用最新脚本就一定有值。 |
| 访问页面出现 **502 / DNS lookup failed**？ | 一般是浏览器装了 Ghelper / 或电脑走了别的代理 → 把「服务器 IP」加进 Ghelper「直连列表」或暂时关代理再访问；也可用手机 4G 直连验证。 |
| 部署完 Nginx 仍然看到 `Welcome to nginx!` 默认页？ | 不同发行版 Nginx 默认配置文件位置不同（`/etc/nginx/conf.d/default.conf` vs `/etc/nginx/sites-enabled/default`），vpn.sh 会**两处都覆盖 + 删 sites-enabled/default + nginx -t 检查 + systemctl reload nginx**。如果还是欢迎页：`ls -la /etc/nginx/conf.d/default.conf` 看里面 `root` 是不是 `/etc/s-box/output;`，再手动 `nginx -s reload`。 |

---

## 📱 客户端工具快速一览（页面里有完整 Tabs + 分步教程）

| 平台 | 首选工具 | 其他选择 |
|------|---------|---------|
| 📱 iOS / iPadOS | 🚀 **Shadowrocket 小火箭**（App Store 国区搜" Shadowrocket"，约 18¥，终身用） | Stash、Quantumult X、sing-box SFI（TestFlight） |
| 🤖 Android | 🟢 **v2rayNG**（GitHub 免费下载） | NekoBox、Clash Verge Rev (ClashMeta For Android)、sing-box SFA |
| 🪟 Windows | 🟢 **v2rayN**（.NET 版 / 自包含版 GitHub 免费） | NekoRay、Clash Verge Rev、sing-box SFM |
| 🍎 macOS | 🚀 **Shadowrocket for Mac**（Mac App Store 同 iOS 版付费一次双端用） | Clash Verge Rev、sing-box SFM、V2rayU |
| 🐧 Linux | 🐱 **Clash Verge Rev**（deb/rpm/AppImage） | sing-box 命令行、NekoRay |
| 🛰️ 路由器 OpenWrt | **PassWall2 / OpenClash**（需刷 OpenWrt 固件+安装对应插件） | luci-app-syncdial、sing-box-system |

> ⭐ **最省事操作（任何平台都推荐）**：打开页面 → 滑到最下面 **「聚合节点」卡片** → 点 **⭐ 一键复制全部** → 打开客户端粘贴 → 自动批量导入所有协议。比一条条扫码快 10 倍。

### 快速扫码导入对应关系
```
页面每张协议卡的底部 5 个彩色 Badge → 代表"哪些客户端能识别此协议的链接/二维码"
🚀 小火箭 / 🟢 v2rayNG·v2rayN / 📦 NekoBox·NekoRay / 🐱 Clash Verge / ✨ SFA·SFI·SFM
   ↑         ↑                        ↑                   ↑                ↑
  iOS全协议   Android/Win 全协议     跨平台小众首选     订阅/规则首选     sing-box 原生
```

---

## 🔧 故障排查 · 一行命令速查

```bash
# 1. 查看最新生成的 HTML（最近一次 vpn.sh 输出的路径）
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

---

## 🌐 其他 VPN 服务补充推荐

除了本脚本自建 Sing-box，以下服务可作备用/流媒体解锁/回国路线补充：

| 名称 | 入口 | 特点 |
|------|------|------|
| **NFSQ** (奈飞社区) | https://www.nfsq.us/#/dashboard | 老牌流媒体解锁机场，节点稳定，常见奈飞/Disney+/ChatGPT 都有 |
| **起飞加速** | https://xn--gmqz83awjh.org/auth/login | 中文域名老牌机场，国内中转线路多，电信/移动/联通都友好 |
| **Ghelper** (Google Chrome/Edge 插件) | Chrome 商店搜「Ghelper」 | 浏览器插件级轻量代理，**仅对网页流量生效**，无需安装客户端。注意：Ghelper 和本脚本的系统级代理（v2rayN/Clash/小火箭）**同开会冲突** → 如果已装 Ghelper 又想用系统级代理：进 Ghelper 设置 → 「全局直连」模式关掉或把需要的域名加到白名单，或者只开其中一个。 |

---

## 🛒 服务器购买推荐

- **轻量入门**：腾讯云轻量 / 阿里云 ECS（香港/新加坡区域，月付 30-60 元，1C1G 即够用）
- **高性价比防墙**：搬瓦工 BandwagonHost / RackNerd（年付 20-50 USD，美西/日本软银线路）
- **线路参考**：国内用 → 选 三网优化/CUG/CMI/软银 线路；跨境用 → 选 9929/4837/华为云 CN2 回程

购买 & 部署后有任何问题：把 `bash vpn.sh` 的完整输出、`curl -s http://127.0.0.1/latest/ | head -20`、服务器发行版 `cat /etc/os-release | head -5` 贴出来即可快速定位 🐛。
