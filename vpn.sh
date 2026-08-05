#!/bin/bash
export LANG=en_US.UTF-8
set +e

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
SB_OUTPUT_PATH="/etc/s-box/sb_output.sh"
IPCHECK_PATH="/etc/s-box/ip-check.sh"
OUTPUT_BASE="/etc/s-box/output"
NGINX_CONF_PATH=""

# =====================================================
# 彩色输出
# =====================================================
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}

[[ $EUID -ne 0 ]] && { red "请以 root 身份运行此脚本 (sudo -i)"; exit 1; }

# =====================================================
# Step 0. 基础依赖：wget / curl / jq / python3
# =====================================================
step0_install_base(){
    green "[0/7] 安装基础依赖 wget、curl、jq..."
    _inst(){
        local p=$1; command -v "$p" &>/dev/null && return 0
        if [ -x "$(command -v apt-get)" ]; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            yum install -y "$p" >/dev/null 2>&1
        elif [ -x "$(command -v dnf)" ]; then
            dnf install -y "$p" >/dev/null 2>&1
        elif command -v apk >/dev/null 2>&1; then
            apk add "$p" >/dev/null 2>&1
        fi
    }
    # apt 需要先 update
    if [ -x "$(command -v apt-get)" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
    elif [ -x "$(command -v yum)" ]; then
        # CentOS 没有 jq / python3 时装 epel
        yum install -y epel-release >/dev/null 2>&1 || true
    fi
    _inst wget; _inst curl; _inst jq; _inst python3; _inst gawk; _inst grep; _inst sed; _inst tr
    # ip-check.sh RBL needs dig
    if ! command -v dig &>/dev/null; then
        if [ -x "$(command -v apt-get)" ]; then DEBIAN_FRONTEND=noninteractive apt-get install -y dnsutils >/dev/null 2>&1 || true;
        elif [ -x "$(command -v yum)" ];     then yum install -y bind-utils >/dev/null 2>&1 || true;
        elif [ -x "$(command -v dnf)" ];     then dnf install -y bind-utils >/dev/null 2>&1 || true;
        elif command -v apk &>/dev/null;       then apk add bind-tools >/dev/null 2>&1 || true; fi
    fi
    command -v wget &>/dev/null && green "  -> wget OK"
    command -v curl &>/dev/null && green "  -> curl OK"
    command -v jq &>/dev/null   && green "  -> jq OK"
}

# =====================================================
# Step 1. 部署 sb_output.sh（二维码 + HTML 生成工具）
# =====================================================
step1_deploy_output_helper(){
    green "[1/7] 部署 sb_output.sh 辅助脚本..."
    mkdir -p /etc/s-box "$OUTPUT_BASE"

    cat > "$SB_OUTPUT_PATH" <<'SBOUT_EOF'
#!/bin/bash
export LANG=en_US.UTF-8

OUTPUT_BASE="/etc/s-box/output"
DATE_FOLDER=""

create_date_folder() {
    today=$(date +%Y%m%d)
    max_num=0
    for dir in "$OUTPUT_BASE"/"$today"-*; do
        if [ -d "$dir" ]; then
            num=$(echo "$dir" | sed "s|$OUTPUT_BASE/$today-||")
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt "$max_num" ]; then
                max_num=$num
            fi
        fi
    done
    new_num=$((max_num + 1))
    DATE_FOLDER="$OUTPUT_BASE/$today-$new_num"
    mkdir -p "$DATE_FOLDER"
    echo "DATE_FOLDER=$DATE_FOLDER"
}

generate_qr_codes() {
    local base_dir="/etc/s-box"
    local files=("vl_reality.txt" "vm_ws.txt" "vm_ws_tls.txt" "vm_ws_argols.txt" "vm_ws_argogd.txt" "hy2.txt" "tuic5.txt" "an.txt" "jhsub.txt")
    
    for file in "${files[@]}"; do
        if [ -f "$base_dir/$file" ]; then
            local content=$(cat "$base_dir/$file")
            local name=$(basename "$file" .txt)
            echo "$content" > "$DATE_FOLDER/$file"
            if command -v qrencode >/dev/null 2>&1 && [ -n "$content" ]; then
                qrencode -o "$DATE_FOLDER/$name.png" "$content"
            fi
        fi
    done
}

_CLIENT_BADGES_ALL='<div class="client-badges"><span class="badge b-rocket" title="Shadowrocket (通用接入客户端)">🚀 小火箭通用</span><span class="badge b-v2ray" title="NekoNG / Nekoray 通用客户端">🟢 NekoNG / Nekoray</span><span class="badge b-neko" title="NekoBox / NekoRay（通用内核）">📦 NekoBox / NekoRay</span><span class="badge b-clash" title="Clash Verge Rev（通用内核）">🐱 Clash Verge</span><span class="badge b-sfa" title="SFA / SFI / SFM 官方客户端">✨ SFA · SFI · SFM</span></div>'

generate_html() {
    local html_file="$DATE_FOLDER/index.html"
    local hostname gen_time
    hostname=$(hostname 2>/dev/null || echo "entry-server")
    gen_time=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    [ -n "$gen_time" ] || gen_time=$(date 2>/dev/null || date -u 2>/dev/null || echo "Unknown")

    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>出海节点接入中心 / 扫码即用 · ${gen_time}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body { font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #0f172a 0%, #1e293b 60%, #0f172a 100%); min-height: 100vh; padding: 18px; color: #e2e8f0; }
        .container { max-width: 1200px; margin: 0 auto; }

        /* ===== Header ===== */
        .header { text-align: center; color: #fff; margin-bottom: 22px; padding: 24px 20px; background: linear-gradient(135deg, rgba(99,102,241,0.25), rgba(236,72,153,0.2)); border: 1px solid rgba(148,163,184,0.18); border-radius: 18px; }
        .header h1 { font-size: 28px; margin-bottom: 8px; letter-spacing: 0.5px; }
        .header h1 small { font-size: 14px; color: #94a3b8; margin-left: 8px; font-weight: normal; }
        .header p { color: #cbd5e1; font-size: 14px; display: flex; flex-wrap: wrap; gap: 14px; justify-content: center; margin-top: 10px; }
        .header p span { background: rgba(255,255,255,0.06); padding: 4px 10px; border-radius: 20px; }

        /* ===== Hero: 客户端工具 + 快速上手 ===== */
        .hero { background: linear-gradient(135deg, rgba(14,165,233,0.18), rgba(16,185,129,0.18)); border: 1px solid rgba(56,189,248,0.3); border-radius: 16px; padding: 22px; margin-bottom: 22px; }
        .hero h2 { font-size: 20px; color: #7dd3fc; margin-bottom: 14px; display: flex; align-items: center; gap: 10px; }
        .hero .quick-tip { background: rgba(250,204,21,0.12); border-left: 4px solid #facc15; padding: 10px 14px; border-radius: 6px; color: #fde68a; font-size: 14px; margin: 12px 0 16px; line-height: 1.6; }
        .hero .quick-tip b { color: #fff; }
        .platform-tabs { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
        .platform-tabs button { background: rgba(30,41,59,0.75); color: #cbd5e1; border: 1px solid rgba(148,163,184,0.25); padding: 6px 14px; border-radius: 999px; cursor: pointer; font-size: 13px; transition: all .18s ease; }
        .platform-tabs button:hover { border-color: #38bdf8; color: #fff; }
        .platform-tabs button.active { background: linear-gradient(135deg, #0ea5e9, #10b981); color: #fff; border-color: transparent; box-shadow: 0 4px 10px rgba(14,165,233,0.4); }
        .platform-panel { display: none; background: rgba(15,23,42,0.55); padding: 14px 16px; border-radius: 12px; font-size: 14px; line-height: 1.8; border: 1px solid rgba(148,163,184,0.12); }
        .platform-panel.active { display: block; animation: fadeIn .3s ease; }
        .platform-panel h4 { color: #38bdf8; margin-bottom: 6px; font-size: 15px; }
        .platform-panel ol { padding-left: 22px; }
        .platform-panel code { background: rgba(14,165,233,0.15); color: #7dd3fc; padding: 2px 7px; border-radius: 4px; font-family: monospace; font-size: 12.5px; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(4px);} to { opacity: 1; transform: none;} }

        /* ===== Client badges (on every protocol card) ===== */
        .client-badges { margin-top: 12px; display: flex; flex-wrap: wrap; gap: 6px; }
        .badge { display: inline-flex; align-items: center; gap: 4px; font-size: 12px; padding: 4px 10px; border-radius: 999px; font-weight: 500; }
        .b-rocket { background: rgba(244,114,182,0.18); color: #f9a8d4; border: 1px solid rgba(244,114,182,0.35); }
        .b-v2ray  { background: rgba(34,197,94,0.15); color: #86efac; border: 1px solid rgba(34,197,94,0.35); }
        .b-neko   { background: rgba(56,189,248,0.15); color: #7dd3fc; border: 1px solid rgba(56,189,248,0.35); }
        .b-clash  { background: rgba(167,139,250,0.16); color: #c4b5fd; border: 1px solid rgba(167,139,250,0.35); }
        .b-sfa    { background: rgba(251,191,36,0.16); color: #fcd34d; border: 1px solid rgba(251,191,36,0.35); }

        /* ===== Cards ===== */
        .card { background: #1e293b; border-radius: 14px; padding: 22px 22px 18px; margin-bottom: 18px; box-shadow: 0 6px 18px rgba(0,0,0,0.35); border: 1px solid rgba(148,163,184,0.12); }
        .card.jh-card { background: linear-gradient(135deg, rgba(16,185,129,0.12), rgba(234,179,8,0.12)); border: 1px solid rgba(52,211,153,0.35); }
        .card-title { color: #34d399; font-size: 19px; margin-bottom: 14px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .card-title .tag { font-size: 11px; padding: 3px 9px; border-radius: 6px; background: #facc15; color: #422006; font-weight: 600; letter-spacing: 0.5px; }
        .card-title .udp { background: linear-gradient(135deg, #22d3ee, #0ea5e9); color: #0b1e31; }
        .qrcode-container { display: flex; align-items: flex-start; gap: 26px; flex-wrap: wrap; }
        .qrcode-box { background: #fff; padding: 10px; border-radius: 10px; flex-shrink: 0; box-shadow: 0 2px 8px rgba(0,0,0,0.4); }
        .qrcode-box .qr-missing { width: 150px; height: 150px; background: repeating-linear-gradient(45deg, #cbd5e1, #cbd5e1 8px, #e2e8f0 8px, #e2e8f0 16px); display: flex; align-items: center; justify-content: center; color: #64748b; font-size: 11.5px; text-align: center; line-height: 1.5; border-radius: 4px; }
        .qrcode-box img { display: block; width: 150px; height: 150px; }
        .link-info { flex: 1 1 320px; min-width: 300px; }
        .link-label { color: #fbbf24; font-size: 13px; margin-bottom: 6px; letter-spacing: 0.3px; }
        .link-value { background: #0f172a; color: #f1f5f9; padding: 11px 13px; border-radius: 8px; word-break: break-all; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 12.5px; line-height: 1.7; border: 1px solid rgba(148,163,184,0.15); }
        .copy-btn { background: linear-gradient(135deg, #0984e3, #74b9ff); color: #fff; border: none; padding: 8px 16px; border-radius: 7px; cursor: pointer; margin-top: 10px; font-size: 13.5px; font-weight: 500; box-shadow: 0 3px 10px rgba(14,165,233,0.35); transition: all .18s ease; }
        .copy-btn:hover { transform: translateY(-1px); box-shadow: 0 6px 14px rgba(14,165,233,0.5); }
        .copy-btn.primary { background: linear-gradient(135deg, #10b981, #14b8a6); box-shadow: 0 3px 10px rgba(16,185,129,0.4); }
        .jh-hint { margin-top: 14px; padding: 11px 14px; background: rgba(15,23,42,0.6); border-radius: 10px; font-size: 13px; line-height: 1.75; color: #cbd5e1; border: 1px dashed rgba(148,163,184,0.3); }
        .jh-hint b { color: #fcd34d; }

        /* ===== Protocol detail grid ===== */
        .protocol-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 16px; }
        .protocol-card { background: #334155; border-radius: 12px; padding: 18px; border: 1px solid rgba(148,163,184,0.12); }
        .protocol-name { color: #34d399; font-size: 17px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; }
        .info-row { display: flex; margin-bottom: 7px; font-size: 13.5px; }
        .info-label { color: #fbbf24; width: 82px; flex-shrink: 0; }
        .info-value { color: #e2e8f0; flex: 1; word-break: break-all; font-family: monospace; }

        /* ===== Tutorial accordion (折叠教程) ===== */
        .tutorial { margin-top: 6px; }
        .tutorial details { background: #1e293b; border: 1px solid rgba(148,163,184,0.15); border-radius: 12px; margin-bottom: 10px; overflow: hidden; }
        .tutorial summary { padding: 14px 18px; cursor: pointer; list-style: none; font-size: 15px; font-weight: 600; color: #e2e8f0; display: flex; align-items: center; gap: 10px; background: linear-gradient(90deg, rgba(99,102,241,0.14), transparent); user-select: none; }
        .tutorial summary::-webkit-details-marker { display: none; }
        .tutorial summary::before { content: '▶'; color: #60a5fa; font-size: 11px; transition: transform .2s ease; }
        .tutorial details[open] summary::before { transform: rotate(90deg); color: #34d399; }
        .tutorial .guide { padding: 14px 22px 20px; line-height: 1.85; font-size: 14px; }
        .tutorial .guide h5 { color: #60a5fa; font-size: 14px; margin: 10px 0 4px; }
        .tutorial .guide h5:first-child { margin-top: 0; }
        .tutorial .guide ol, .tutorial .guide ul { padding-left: 22px; }
        .tutorial .guide code { background: rgba(14,165,233,0.14); color: #7dd3fc; padding: 2px 7px; border-radius: 4px; font-family: monospace; font-size: 12.5px; }

        /* ===== Tips card ===== */
        .tips-card { background: linear-gradient(135deg, rgba(99,102,241,0.12), rgba(236,72,153,0.12)); border: 1px solid rgba(167,139,250,0.35); }
        .tips-card h3 { color: #a78bfa; margin-bottom: 12px; font-size: 17px; }
        .tips-card ul { padding-left: 20px; line-height: 1.9; font-size: 14px; }
        .tips-card li::marker { color: #a78bfa; }
        .tips-card b { color: #fde68a; }

        /* ===== Toast ===== */
        .toast { position: fixed; left: 50%; bottom: 40px; transform: translateX(-50%) translateY(80px); background: linear-gradient(135deg, #10b981, #14b8a6); color: #022c22; padding: 10px 20px; border-radius: 999px; font-weight: 600; font-size: 14px; box-shadow: 0 10px 24px rgba(16,185,129,0.5); opacity: 0; transition: all .35s ease; z-index: 9999; }
        .toast.show { opacity: 1; transform: translateX(-50%) translateY(0); }

        .footer { text-align: center; color: #64748b; margin-top: 28px; font-size: 13px; line-height: 1.7; }
        .footer a { color: #38bdf8; text-decoration: none; }
        @media (max-width: 768px) {
            .qrcode-container { flex-direction: column; align-items: center; }
            .qrcode-box { align-self: center; }
            .link-info { min-width: 100%; width: 100%; }
            .protocol-grid { grid-template-columns: 1fr; }
            .header h1 { font-size: 22px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- ===== Header ===== -->
        <div class="header">
            <h1>🌐 出海节点接入中心 <small>扫码即用 · 复制即连</small></h1>
            <p>
                <span>📅 生成时间：${gen_time}</span>
                <span>🖥️ 主机名：${hostname}</span>
                <span>📦 输出目录：<code style="color:#7dd3fc;font-size:12px;">${DATE_FOLDER}</code></span>
            </p>
        </div>

        <!-- ===== Hero：客户端工具 & 快速上手 ===== -->
        <div class="hero">
            <h2>📱 用什么客户端工具扫码 / 导入链接？</h2>
            <div class="quick-tip">
                👉 <b>最省事的操作（推荐）</b>：先滑到本页最下方的「<b>聚合节点</b>」卡片，点
                <b style="color:#fff;">⭐ 一键复制全部</b> → 打开客户端选「从剪贴板批量导入」，
                <b>一次导入 6 条协议节点</b>，不用一条一条扫二维码！
            </div>
            <div class="platform-tabs" id="platTabs">
                <button class="active" data-tab="ios">🍎 iOS / iPadOS</button>
                <button data-tab="android">🤖 Android</button>
                <button data-tab="win">🪟 Windows</button>
                <button data-tab="mac">🍏 macOS</button>
                <button data-tab="linux">🐧 Linux</button>
                <button data-tab="router">📡 路由器 (OpenWrt)</button>
            </div>
            <div id="plat-ios" class="platform-panel active">
                <h4>⭐ 首选：Shadowrocket（小火箭）— 买断制，三端通用（iPhone / iPad / Mac）</h4>
                <ol>
                    <li>App Store 搜 <code>Shadowrocket</code>（美区 / 港区 / 台区账号下载，约 \$2.99 一次买断）</li>
                    <li>打开 App → 右上角 <b>➕ 加号</b> → 类型选「<b>扫码</b>」→ 对准本页任意协议的二维码</li>
                    <li>识别后字段自动填入 → 右上角「保存」→ 打开 App 顶部的大开关即可使用</li>
                </ol>
                <h4>💡 一次导入全部协议节点（不用一条条扫）</h4>
                <ol>
                    <li>把本页下方「聚合节点」的链接复制到 iPhone 备忘录（可用 AirDrop / 微信发到手机）</li>
                    <li>备忘录里 <b>长按链接</b> → 选「Shadowrocket：拷贝链接」→ 所有节点自动导入</li>
                </ol>
                <h4>其他可选：Stash / Quantumult X / sing-box 官方 SFI / Surge for iOS</h4>
            </div>
            <div id="plat-android" class="platform-panel">
                <h4>⭐ 首选：NekoNG（免费开源，全协议原生支持）</h4>
                <ol>
                    <li>GitHub 搜 NekoNG / Nekoray 下载最新 release（.apk）或 F-Droid / Google Play 搜 <code>NekoNG</code></li>
                    <li>首页右上角 <b>➕</b> →「<b>扫描二维码</b>」（相机权限允许）或「<b>从剪贴板导入</b>」</li>
                    <li>右下角 <b>小猫</b> 图标切换系统接入 → 选择节点即可</li>
                </ol>
                <h4>📦 备选：NekoBox（sing-box 内核，UI 更现代）</h4>
                <ol><li>首页右下角 ➕ →「Scan QR code」扫码 或 「Import from Clipboard」从剪贴板导入</li></ol>
                <h4>✨ 官方：SFA（sing-box for Android / Google TV / 车机）</h4>
            </div>
            <div id="plat-win" class="platform-panel">
                <h4>⭐ 首选：NekoRay（桌面通用，免费开源）</h4>
                <ol>
                    <li>GitHub 搜 <code>NekoRay / NekoBox</code> 下载 zip，解压运行 <code>NekoRay.exe</code></li>
                    <li>顶部菜单「 Profiles → 「<b>扫描屏幕二维码</b>」（自动取当前屏任意二维码）</li>
                    <li>或点「<b>Import from Clipboard</b>」→ 直接粘贴「聚合节点」复制的全部链接</li>
                </ol>
                <h4>其他：NekoRay（跨平台 Qt 版，sing-box 内核）/ Clash Verge Rev（游戏 TUN 模式）/ SFM（sing-box 官方）</h4>
            </div>
            <div id="plat-mac" class="platform-panel">
                <h4>⭐ 首选：Clash Verge Rev（M 芯片原生，TUN 模式游戏丝滑）</h4>
                <ol><li>GitHub 搜 Clash Verge Rev 下载 .dmg 安装；订阅走侧边栏「订阅→新建」粘贴链接</li></ol>
                <h4>🚀 次选：Shadowrocket for macOS（和 iPhone 同一个 App Store 授权，免费再次安装）</h4>
                <h4>其他：V2rayU（菜单栏工具）/ Surge 5 for Mac / sing-box 官方 SFM</h4>
            </div>
            <div id="plat-linux" class="platform-panel">
                <h4>⭐ 首选：Clash Verge Rev（.AppImage 直接双击跑，最省心）</h4>
                <ol><li>GitHub 下 AppImage → <code>chmod +x *.AppImage</code> → 运行</li></ol>
                <h4>其他：NekoRay（Qt 跨平台，部分源里有 <code>nekoray</code> / <code>pacman -S nekoray</code>） / sing-box 命令行（高阶）</h4>
            </div>
            <div id="plat-router" class="platform-panel">
                <h4>⭐ 首选：OpenWrt 固件 + PassWall2 插件</h4>
                <ol>
                    <li>OpenWrt 后台 → 服务 → PassWall2 → 节点列表 →「<b>添加</b>」→ 类型选对应协议</li>
                    <li>手动填入下方「协议配置详情」卡片里的 <code>端口 / UUID / SNI / 密码</code> / Path 即可</li>
                    <li>或「订阅链接管理」→ 添加一个订阅，粘贴把本页内容转换后的订阅地址（支持订阅格式转换）</li>
                </ol>
                <h4>其他插件：Hello World (vssr) / ShadowSocksR Plus+ / 原生 sing-box / 梅林固件 Clash</h4>
            </div>
        </div>
EOF

    # ========== Vless-Reality ==========
    if [ -f "$DATE_FOLDER/vl_reality.txt" ]; then
        local vl_link=$(cat "$DATE_FOLDER/vl_reality.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Vless-Reality-Vision</span>
                <span class="tag">推荐</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/vl_reality.png" ] && echo '                    <img src="vl_reality.png" alt="Vless-Reality QR">' || echo '                    <div class="qr-missing">未生成二维码<br>（服务器需 qrencode）<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vl-link">$vl_link</div>
                    <button class="copy-btn" onclick="copyText('vl-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Vmess-WS ==========
    if [ -f "$DATE_FOLDER/vm_ws.txt" ]; then
        local vm_link=$(cat "$DATE_FOLDER/vm_ws.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Vmess-WS</span>
                <span class="tag">通用</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/vm_ws.png" ] && echo '                    <img src="vm_ws.png" alt="Vmess-WS QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-link">$vm_link</div>
                    <button class="copy-btn" onclick="copyText('vm-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Vmess-WS-TLS ==========
    if [ -f "$DATE_FOLDER/vm_ws_tls.txt" ]; then
        local vm_tls_link=$(cat "$DATE_FOLDER/vm_ws_tls.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Vmess-WS-TLS</span>
                <span class="tag">加密</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/vm_ws_tls.png" ] && echo '                    <img src="vm_ws_tls.png" alt="Vmess-WS-TLS QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-tls-link">$vm_tls_link</div>
                    <button class="copy-btn" onclick="copyText('vm-tls-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Vmess-WS + Argo 临时 ==========
    if [ -f "$DATE_FOLDER/vm_ws_argols.txt" ]; then
        local vm_argo_link=$(cat "$DATE_FOLDER/vm_ws_argols.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Vmess-WS + Argo 临时隧道</span>
                <span class="tag" style="background:#a78bfa;color:#1e1b4b;">CF 隧道</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/vm_ws_argols.png" ] && echo '                    <img src="vm_ws_argols.png" alt="Vmess-WS-Argo QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-argo-link">$vm_argo_link</div>
                    <button class="copy-btn" onclick="copyText('vm-argo-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Vmess-WS + Argo 固定 ==========
    if [ -f "$DATE_FOLDER/vm_ws_argogd.txt" ]; then
        local vm_argo_gd_link=$(cat "$DATE_FOLDER/vm_ws_argogd.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Vmess-WS + Argo 固定隧道</span>
                <span class="tag" style="background:#a78bfa;color:#1e1b4b;">CF 隧道</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/vm_ws_argogd.png" ] && echo '                    <img src="vm_ws_argogd.png" alt="Vmess-WS-Argo-fixed QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-argo-gd-link">$vm_argo_gd_link</div>
                    <button class="copy-btn" onclick="copyText('vm-argo-gd-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Hysteria-2 ==========
    if [ -f "$DATE_FOLDER/hy2.txt" ]; then
        local hy2_link=$(cat "$DATE_FOLDER/hy2.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Hysteria-2</span>
                <span class="tag udp">UDP · 弱网传家宝</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/hy2.png" ] && echo '                    <img src="hy2.png" alt="Hysteria-2 QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接（弱网/跨运营商首选，速度更快）</div>
                    <div class="link-value" id="hy2-link">$hy2_link</div>
                    <button class="copy-btn" onclick="copyText('hy2-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Tuic-v5 ==========
    if [ -f "$DATE_FOLDER/tuic5.txt" ]; then
        local tu5_link=$(cat "$DATE_FOLDER/tuic5.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Tuic-v5</span>
                <span class="tag udp">UDP · BBR 低延迟</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/tuic5.png" ] && echo '                    <img src="tuic5.png" alt="Tuic-v5 QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接（游戏/直播首选，延迟更低）</div>
                    <div class="link-value" id="tu5-link">$tu5_link</div>
                    <button class="copy-btn" onclick="copyText('tu5-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== Anytls ==========
    if [ -f "$DATE_FOLDER/an.txt" ]; then
        local an_link=$(cat "$DATE_FOLDER/an.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span><span>Anytls / ShadowTLS</span>
                <span class="tag" style="background:#fb7185;color:#4c0519;">伪装</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
$( [ -f "$DATE_FOLDER/an.png" ] && echo '                    <img src="an.png" alt="Anytls QR">' || echo '                    <div class="qr-missing">未生成二维码<br>右侧「复制链接」可用</div>' )
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="an-link">$an_link</div>
                    <button class="copy-btn" onclick="copyText('an-link')">复制链接</button>
                    $_CLIENT_BADGES_ALL
                </div>
            </div>
        </div>
EOF
    fi

    # ========== 聚合节点 ==========
    if [ -f "$DATE_FOLDER/jhsub.txt" ]; then
        local jh_link=$(cat "$DATE_FOLDER/jhsub.txt")
        cat >> "$html_file" <<EOF
        <div class="card jh-card">
            <div class="card-title">
                <span>📦</span><span>聚合节点（全部协议汇总）</span>
                <span class="tag" style="background:#f43f5e;color:#fff;">⭐ 一键复制全部（推荐）</span>
            </div>
            <div class="link-info" style="min-width:100%;">
                <div class="link-label">包含：Vless-Reality + Vmess-WS + Vmess-WS-TLS + Hysteria-2 + Tuic-v5 + Anytls（一行一个）</div>
                <div class="link-value" id="jh-link">$jh_link</div>
                <button class="copy-btn primary" onclick="copyText('jh-link')">⭐ 一键复制全部节点</button>
            </div>
            <div class="jh-hint">
                💡 <b>使用方法</b>：点上方按钮复制 → 打开对应客户端 →
                小火箭选「配置 → 粘贴链接」、Nekoray/NekoNG 按 <code>Ctrl+V</code> 或「从剪贴板导入批量 URL」、
                NekoBox/NekoRay 选「粘贴分享链接」、Clash 选转换工具转成订阅 → <b>一次导入 6 条</b>，
                以后客户端可以根据实际网络情况自动切换最快的协议。
            </div>
        </div>
EOF
    fi

    # ========== 协议配置详情 ==========
    cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>📋</span><span>协议配置详情（手动添加节点时参考）</span>
            </div>
            <div class="protocol-grid">
EOF

    if [ -f /etc/s-box/sb.json ]; then
        local vl_port=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[0].listen_port // empty' 2>/dev/null)
        local vm_port=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[1].listen_port // empty' 2>/dev/null)
        local hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[2].listen_port // empty' 2>/dev/null)
        local tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[3].listen_port // empty' 2>/dev/null)
        local vl_sni=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[0].tls.server_name // empty' 2>/dev/null)
        local uuid=$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[0].users[0].uuid // empty' 2>/dev/null)

        [ -z "$vl_port" ] && vl_port='—'
        [ -z "$vm_port" ] && vm_port='—'
        [ -z "$hy2_port" ] && hy2_port='—'
        [ -z "$tu5_port" ] && tu5_port='—'
        [ -z "$vl_sni"  ] && vl_sni='—'
        [ -z "$uuid"    ] && uuid='—'

        cat >> "$html_file" <<EOF
                <div class="protocol-card">
                    <div class="protocol-name">Vless-Reality <span class="badge b-rocket" style="font-size:10.5px;padding:2px 8px;">客户端支持</span></div>
                    <div class="info-row"><div class="info-label">端口：</div><div class="info-value">$vl_port</div></div>
                    <div class="info-row"><div class="info-label">SNI：</div><div class="info-value">$vl_sni</div></div>
                    <div class="info-row"><div class="info-label">UUID：</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">Flow：</div><div class="info-value">xtls-rprx-vision</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Vmess-WS <span class="badge b-v2ray" style="font-size:10.5px;padding:2px 8px;">客户端支持</span></div>
                    <div class="info-row"><div class="info-label">端口：</div><div class="info-value">$vm_port</div></div>
                    <div class="info-row"><div class="info-label">UUID：</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">WS Path：</div><div class="info-value">/${uuid}-vm</div></div>
                    <div class="info-row"><div class="info-label">加密：</div><div class="info-value">auto (aes-128-gcm / none)</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Hysteria-2 <span class="badge b-sfa" style="font-size:10.5px;padding:2px 8px;">UDP</span></div>
                    <div class="info-row"><div class="info-label">端口：</div><div class="info-value">$hy2_port</div></div>
                    <div class="info-row"><div class="info-label">密码：</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">TLS：</div><div class="info-value">insecure=1（自签证书）</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Tuic-v5 <span class="badge b-sfa" style="font-size:10.5px;padding:2px 8px;">BBR</span></div>
                    <div class="info-row"><div class="info-label">端口：</div><div class="info-value">$tu5_port</div></div>
                    <div class="info-row"><div class="info-label">UUID：</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">密码：</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">拥堵控制：</div><div class="info-value">bbr · ALPN: h3</div></div>
                </div>
EOF
    else
        cat >> "$html_file" <<EOF
                <div class="protocol-card" style="grid-column:1/-1;">
                    <div class="protocol-name">ℹ️  未发现 /etc/s-box/sb.json，已跳过详情渲染</div>
                    <div style="color:#94a3b8;font-size:13.5px;line-height:1.75;">
                        请运行 <code style="background:rgba(56,189,248,.15);color:#7dd3fc;padding:2px 6px;border-radius:4px;">bash /etc/s-box/sb_output.sh main</code>
                        在 VPS 上重新生成，即可显示端口、UUID、SNI 等手动配置信息。
                    </div>
                </div>
EOF
    fi

    # ========== 教程折叠区 ==========
    cat >> "$html_file" <<EOF
            </div>
        </div>

        <div class="tutorial">
            <details>
                <summary>📱 详细扫码接入教程：小火箭通用 / NekoNG / NekoBox / Clash Verge</summary>
                <div class="guide">
                    <h5>🚀 iOS · Shadowrocket（小火箭通用）扫码三步走</h5>
                    <ol>
                        <li>App Store 下载 <code>Shadowrocket</code>（美区/港区账号）</li>
                        <li>首页右上角 <b>➕ 加号</b> →「扫码」→ 对准上方任一协议二维码；字段自动填入后 <b>保存</b></li>
                        <li>App 顶部大开关拨到<b>开启</b>，第一次会弹「添加网络接入配置」允许即可</li>
                    </ol>
                    <p style="margin:8px 0;color:#94a3b8;">💡 推荐一次性导入所有：点上方聚合节点按钮复制全部 → 发到 iPhone 备忘录 → 长按链接 → 选 <b>Shadowrocket 拷贝链接</b>。</p>

                    <h5>🤖 Android · NekoNG 四步走（通用接入客户端）</h5>
                    <ol>
                        <li>GitHub 下 NekoNG 安装包 → 打开 App</li>
                        <li>首页右上角 ➕ →「扫码」 或「从剪贴板导入」</li>
                        <li>左上角菜单 →「服务器」选择对应节点</li>
                        <li>右下角圆形 <b>启动图标</b> 开启系统接入，状态栏出现 V 图标表示成功</li>
                    </ol>

                    <h5>📦 新选 Android · NekoBox（通用接入内核）</h5>
                    <ul><li>右下角 ➕ → Scan QR code / Import from Clipboard → 底部切到「配置」选项卡 → 打开开关即可。</li></ul>

                    <h5>🪟 Windows · Nekoray 桌面端（最简单）</h5>
                    <ol>
                        <li>解压缩 Nekoray.zip 后运行 <code>Nekoray.exe</code>（托盘区会出现 V 图标）</li>
                        <li>双击托盘图标打开窗口 → 菜单「服务器 → 扫描屏幕二维码」（会自动截屏识别当前屏幕上所有二维码）</li>
                        <li>或「服务器 → 从剪贴板导入批量 URL」→ 粘贴聚合节点 → 一次性导入所有节点</li>
                        <li>托盘图标右键 →「系统代理 → 自动配置系统代理」→ 开始使用</li>
                    </ol>

                    <h5>🍏 macOS · Clash Verge Rev</h5>
                    <ol>
                        <li>安装 Clash Verge Rev → 左侧栏「订阅」→ 新建 → 粘贴你自己转换好的订阅链接</li>
                        <li>对于通用链接 / sb.sh 格式的分享链接：用在线工具转成 Clash 订阅格式，或安装 Nekoray 直接粘链接</li>
                        <li>打开「系统代理」+「TUN 模式」：游戏、应用商店全局代理</li>
                    </ol>

                    <h5>🐱 所有客户端通用：手动配置参数</h5>
                    <p style="color:#cbd5e1;">
                        当分享链接不可用、或 OpenWrt 路由器需要手动填节点时，直接照上方「<b>协议配置详情</b>」卡片逐个填端口、UUID、SNI、密码、Path、ALPN 即可，值和链接里完全一致。
                    </p>
                </div>
            </details>

            <details>
                <summary>❓ 常见问题（扫码失败 / 连不上 / Ghelper 冲突）</summary>
                <div class="guide">
                    <h5>1. 小火箭通用 / NekoNG 扫不到二维码？</h5>
                    <ul>
                        <li>原因：浏览器缩放 / 截图被压缩、或二维码斜着拍</li>
                        <li>解决：直接点协议卡片里的 <b>「复制链接」按钮</b> → 粘贴到客户端，比扫码更稳 100%</li>
                    </ul>
                    <h5>2. 连成功了但没网？</h5>
                    <ul>
                        <li>先切换协议：Hysteria-2 / Tuic-v5 属于 UDP 协议，跨运营商/跨国家线路更快；Vmess-WS-TLS 兼容性更高</li>
                        <li>检查客户端里的「延迟测试」：选延迟最低的节点</li>
                    </ul>
                    <h5>3. 浏览器打开这一页 502 / 打不开？</h5>
                    <ul>
                        <li>如果你装了 Chrome 插件 <b>Ghelper</b>：插件设置里把节点服务器 IP 加入「直连域名列表」，或临时切到「仅国内加速」模式即可</li>
                        <li>云厂商安全组：确认 <b>TCP 80</b> 端口已放通（UDP 接入端口也要放行对应端口段）</li>
                    </ul>
                    <h5>4. 页面上的二维码显示为条纹占位图？</h5>
                    <ul>
                        <li>说明服务器没装 <code>qrencode</code>（不会影响使用）。装一下然后重新生成：
                            <pre style="background:#0f172a;color:#7dd3fc;padding:8px 12px;border-radius:6px;overflow:auto;margin-top:6px;">apt-get install -y qrencode 2>/dev/null || yum install -y qrencode 2>/dev/null
bash /etc/s-box/sb_output.sh main</pre>
                        </li>
                    </ul>
                    <h5>5. 想更换端口 / UUID 怎么办？</h5>
                    <ul><li>在服务器执行 <code>bash /root/sb.sh</code> → 选菜单 2 → 按提示改端口或 UUID → 再执行菜单 9→1 刷新分享；<b style="color:#f43f5e;">注意：改完参数后旧链接会失效，所有设备都要重新导入</b></li></ul>
                </div>
            </details>
        </div>

        <div class="card tips-card">
            <h3>💡 使用小贴士</h3>
            <ul>
                <li><b>客户端优先顺序：</b>日常刷视频用 Hysteria-2 / Tuic-v5（UDP 更快），办公内网兼容性优先用 Vmess-WS-TLS，追求最强伪装用 Vless-Reality</li>
                <li><b>iOS 扫码识别率低？</b> 不要扫，直接「复制链接 → AirDrop / 微信发到手机 → 备忘录长按粘到 Shadowrocket」</li>
                <li><b>多台设备共享？</b> 把这一页的 URL（http://服务器IP/latest/）直接发给家人朋友，他们也能自行扫码/导入；页面是只读静态页，很安全</li>
                <li><b>路由器全屋接入：</b>OpenWrt + PassWall2 按上方「协议配置详情」填参数即可，电视 / Switch / PS5 / IoT 全设备不用单独装客户端</li>
                <li><b>定期备份：</b>备份 <code>/etc/s-box/sb.json</code> 和 <code>/etc/s-box/private.key</code>，即使 VPS 重装，把文件放回 → 重新跑部署脚本 → <b>旧链接依然可用</b></li>
            </ul>
        </div>

        <div class="footer">
            <p>输出目录：<code>$DATE_FOLDER</code> · 本页面由 <a href="#">sb_output.sh</a> 自动生成</p>
            <p>🛒 主机购买：<a href="https://lisahost.com/" target="_blank" rel="noopener">lisahost.com</a> · 原脚本仓库 yonggekkk/sing-box-yg</p>
        </div>
    </div>

    <div id="toast" class="toast">✅ 已复制到剪贴板</div>

    <script>
    (function () {
        // ===== Platform tabs =====
        const tabs = document.querySelectorAll('#platTabs button');
        const panels = document.querySelectorAll('.platform-panel');
        tabs.forEach(btn => btn.addEventListener('click', () => {
            tabs.forEach(b => b.classList.remove('active'));
            panels.forEach(p => p.classList.remove('active'));
            btn.classList.add('active');
            const p = document.getElementById('plat-' + btn.dataset.tab);
            if (p) p.classList.add('active');
        }));

        // ===== Copy with toast (代替 alert 不打断) =====
        const toast = document.getElementById('toast');
        function showToast(msg) {
            if (msg) toast.textContent = msg;
            toast.classList.add('show');
            clearTimeout(window.__toastTimer);
            window.__toastTimer = setTimeout(() => toast.classList.remove('show'), 1800);
        }
        window.copyText = function (id) {
            const el = document.getElementById(id);
            if (!el) return;
            const text = el.textContent;
            try {
                navigator.clipboard.writeText(text).then(
                    () => showToast('✅ 已复制：' + (id === 'jh-link' ? '全部节点' : '链接') + '，去客户端粘贴吧～'),
                    () => fallback(text)
                );
            } catch (e) { fallback(text); }
            function fallback(t) {
                const ta = document.createElement('textarea');
                ta.value = t; document.body.appendChild(ta);
                ta.select(); try { document.execCommand('copy'); } catch (_) {}
                document.body.removeChild(ta);
                showToast('✅ 已复制到剪贴板');
            }
        };
    })();
    </script>
</body>
</html>
EOF
    # ============== 变量展开兜底 ==============
    # 防止 heredoc 中间有 '' 段没展开，或 ssh/shell 层吃掉 % 导致时间/主机名空白
    _gt_esc=$(printf '%s\n' "$gen_time" | sed 's/[&/\]/\\&/g')
    _hn_esc=$(printf '%s\n' "$hostname" | sed 's/[&/\]/\\&/g')
    _df_esc=$(printf '%s\n' "$DATE_FOLDER" | sed 's/[&/\]/\\&/g')
    sed -i \
      -e "s|\$(date +%Y-%m-%d %H:%M:%S)|${_gt_esc}|g" \
      -e "s|\\\$gen_time|${_gt_esc}|g" \
      -e "s|\\\${gen_time}|${_gt_esc}|g" \
      -e "s|\\\$hostname|${_hn_esc}|g" \
      -e "s|\\\${hostname}|${_hn_esc}|g" \
      -e "s|\\\$DATE_FOLDER|${_df_esc}|g" \
      -e "s|\\\${DATE_FOLDER}|${_df_esc}|g" \
      "$html_file" 2>/dev/null || true
    echo "HTML_FILE=$html_file"
}

update_latest() {
    local latest
    latest=$(ls -1d "$OUTPUT_BASE"/*/ 2>/dev/null | grep -v '/latest/' | sort | tail -n1 | sed 's|/$||')
    if [ -n "$latest" ]; then
        ln -sfn "$latest" "$OUTPUT_BASE/latest"
        echo "LATEST=$OUTPUT_BASE/latest"
    fi
}

main() {
    mkdir -p "$OUTPUT_BASE"
    eval "$(create_date_folder)"
    generate_qr_codes
    eval "$(generate_html)"
    echo "SUCCESS"
    echo "输出目录: $DATE_FOLDER"
    echo "HTML文件: $html_file"
    eval "$(update_latest)"
}

main_output() {
    mkdir -p "$OUTPUT_BASE"
    eval "$(create_date_folder)"
    generate_qr_codes
    eval "$(generate_html)"
    eval "$(update_latest)"
    echo "SUCCESS"
    echo "DATE_FOLDER=$DATE_FOLDER"
}

case "$1" in
    main) main ;;
    main_output) main_output ;;
    *) main_output ;;
esac
SBOUT_EOF
    chmod +x "$SB_OUTPUT_PATH"
    green "  -> sb_output.sh deployed to $SB_OUTPUT_PATH"

    # ---- Deploy ip-check.sh (IP health pre-check) ----
    cat > $IPCHECK_PATH <<'IPCHECK_EOF'
#!/bin/bash
#==============================================================================
# ip-check.sh  —  VPS IP 一键健康体检脚本
# 检测项目：Geo定位 / ASN(机房/住宅判断) / 多源黑名单 / AbuseIPDB /
#            IPQualityScore / Scamalytics / Spur.us(VPN指纹)  +  综合评分
#
# 使用方法：
#   bash ip-check.sh                       # 自动检测本机公网 IP
#   bash ip-check.sh 64.81.25.225          # 检测指定 IP
#
# 可选 API Key（设为环境变量即可，全部可选；不设则跳过对应付费源）：
#   export ABUSEIPDB_KEY=xxxxxxxxxx        # https://www.abuseipdb.com/  免费1000次/天
#   export IPQS_KEY=xxxxxxxxxx             # https://www.ipqualityscore.com/  免费5000次/月
#   export SCAMALYTICS_KEY=xxxxxxxxxx      # https://scamalytics.com/  有免费API层
#   export SPUR_TOKEN=xxxxxxxxxx           # https://spur.us/  学术/免费额度申请
#
# 最终综合评分：
#   PASS     85-100  → 干净 IP，可直接部署
#   WARNING  60-84   → 可日常使用，不建议做 Amazon/TikTok 多账号主节点
#   FAIL     <60     → 建议换 IP / 换机房（风控极高）
#==============================================================================
set -u
umask 022

# ------------ 颜色 ------------
RED='\033[0;31m';  YLW='\033[1;33m';  GRN='\033[0;32m';  BLU='\033[1;34m'
MGN='\033[1;35m';  CYN='\033[0;36m';   WHT='\033[1;37m';  DIM='\033[2m'
RST='\033[0m';     BOLD='\033[1m'

# ------------ 工具检查 ------------
for c in curl jq dig awk sed tr grep; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo -e "${RED}[ERR]${RST} 缺少命令：$c   →  yum install -y curl jq bind-utils gawk sed grep || apt install -y curl jq dnsutils"
    exit 2
  fi
done

# ------------ 1. 确定 IP（IPv4 优先，失败 fallback 到 IPv6） ------------
TARGET_IP="${1:-}"
if [ -z "$TARGET_IP" ]; then
  # 先取 IPv4（-4 强制 IPv4）
  TARGET_IP=$(curl -s --max-time 8 -4 ifconfig.me 2>/dev/null \
             || curl -s --max-time 8 -4 icanhazip.com 2>/dev/null \
             || curl -s --max-time 8 -4 ipinfo.io/ip 2>/dev/null)
  # IPv4 取不到 → 尝试 IPv6（-6 强制 IPv6）
  if [ -z "$TARGET_IP" ]; then
    TARGET_IP=$(curl -s --max-time 8 -6 ifconfig.me 2>/dev/null \
               || curl -s --max-time 8 -6 icanhazip.com 2>/dev/null \
               || curl -s --max-time 8 -6 ipinfo.io/ip 2>/dev/null)
  fi
fi
TARGET_IP=$(echo "$TARGET_IP" | tr -d '[:space:]')

# 判定是 IPv4 还是 IPv6
IP_VER=""
if [[ "$TARGET_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  IP_VER="4"
elif [[ "$TARGET_IP" =~ ^[0-9a-fA-F:]{2,39}$ ]] && echo "$TARGET_IP" | grep -qE ':'; then
  IP_VER="6"
fi

if [ -z "$IP_VER" ]; then
  echo -e "${RED}[ERR]${RST} 无法自动获取/识别目标 IP（v4 或 v6），请手动指定：  bash $0 <IPv4 或 IPv6>"
  exit 3
fi

# RBL 反查：仅 IPv4 支持（大多数 DNSBL 不支持 IPv6）
REV_IP=""
if [ "$IP_VER" = "4" ]; then
  REV_IP=$(echo "$TARGET_IP" | awk -F. '{print $4"."$3"."$2"."$1}')
fi
OUT_JSON="/tmp/ip-check-${TARGET_IP//\//-}.json"
rm -f "$OUT_JSON"

# 权重
W_GEO=10; W_ASN=15; W_RBL=20; W_ABUSE=20; W_IPQS=15; W_SCAM=10; W_SPUR=10

echo ""
echo -e "${BOLD}${MGN}╔════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${BOLD}${MGN}║          VPS IP 健康体检  v1.0      目标 IP: ${WHT}${TARGET_IP}${MGN}           ║${RST}"
echo -e "${BOLD}${MGN}╚════════════════════════════════════════════════════════════════╝${RST}"
echo ""

# ======================================================================
# 2. GEO 定位（免费双源：ip-api.com + ipinfo.io，互相对比）
# ======================================================================
echo -e "${BOLD}${BLU}[1/7]${RST} ${WHT}🌍 Geo 定位（ip-api + ipinfo 双重校验）${RST}"
GEO1=$(curl -s --max-time 10 "http://ip-api.com/json/${TARGET_IP}?fields=status,country,countryCode,regionName,city,isp,org,as,query,message" 2>/dev/null)
GEO2=$(curl -s --max-time 10 "https://ipinfo.io/${TARGET_IP}/json" 2>/dev/null)
GEO_OK="no"
GEO_CC=""; GEO_COUNTRY=""; GEO_CITY=""; GEO_ISP=""; GEO_ASN=""; GEO_ORG=""
if [ -n "$GEO1" ] && [ "$(echo "$GEO1" | jq -r .status 2>/dev/null)" = "success" ]; then
  GEO_OK="yes"
  GEO_CC=$(echo "$GEO1" | jq -r .countryCode)
  GEO_COUNTRY=$(echo "$GEO1" | jq -r .country)
  GEO_CITY=$(echo "$GEO1" | jq -r .regionName)
  [ -z "$GEO_CITY" ] || [ "$GEO_CITY" = "null" ] && GEO_CITY=$(echo "$GEO1" | jq -r .city)
  GEO_ISP=$(echo "$GEO1" | jq -r .isp)
  GEO_ASN_RAW=$(echo "$GEO1" | jq -r .as)
  GEO_ORG=$(echo "$GEO1" | jq -r .org)
  GEO_ASN=$(echo "$GEO_ASN_RAW" | grep -oE 'AS[0-9]+' | head -1)
fi
# ipinfo 兜底
[ -z "$GEO_CC" ] && GEO_CC=$(echo "$GEO2" | jq -r .country 2>/dev/null)
[ -z "$GEO_CITY" ] || [ "$GEO_CITY" = "null" ] && GEO_CITY=$(echo "$GEO2" | jq -r .region 2>/dev/null)
[ -z "$GEO_ISP" ] || [ "$GEO_ISP" = "null" ] && GEO_ISP=$(echo "$GEO2" | jq -r .org 2>/dev/null)
[ -z "$GEO_ASN" ] && GEO_ASN=$(echo "$GEO2" | jq -r .org 2>/dev/null | grep -oE 'AS[0-9]+' | head -1)

GEO_SCORE=100
if [ "$GEO_OK" != "yes" ]; then GEO_SCORE=40; fi
# 常见 Geo 不一致 → 扣 20
if [ -n "$GEO_CC" ] && [ -n "$GEO2" ]; then
  GEO2_CC=$(echo "$GEO2" | jq -r .country 2>/dev/null)
  if [ "$GEO2_CC" != "$GEO_CC" ] && [ "$GEO2_CC" != "null" ] && [ -n "$GEO2_CC" ]; then
    GEO_SCORE=$((GEO_SCORE-20))
    echo -e "  ${YLW}⚠ Geo不一致${RST}: ip-api=${GEO_CC} vs ipinfo=${GEO2_CC}  (常见于 AnyCast / 移动回带宽选)";
  fi
fi
echo -e "  国家：${GRN}${GEO_COUNTRY:-未知}${RST} (${WHT}${GEO_CC:-?}${RST})   地区：${GRN}${GEO_CITY:-未知}${RST}"
echo -e "  ISP：${CYN}${GEO_ISP:-未知}${RST}   ASN：${CYN}${GEO_ASN:-未知}${RST}"
echo -e "  组织：${DIM}${GEO_ORG:-未知}${RST}"
echo -e "  ${DIM}GEO 子项得分：${GEO_SCORE}/100${RST}"
echo ""

# ======================================================================
# 3. ASN 分析：机房 / 住宅 / 校园 / 移动运营商？
# ======================================================================
echo -e "${BOLD}${BLU}[2/7]${RST} ${WHT}🏢 ASN 归属分析（是否机房ASN？住宅？）${RST}"
ASN_NUM=$(echo "$GEO_ASN" | tr -d 'AS ')
ASN_TYPE="unknown"
ASN_NOTE=""
ASN_SCORE=80   # 默认中性
if [ -n "$ASN_NUM" ]; then
  # 用 ipinfo.io/json 里的 org 关键词 + 公开 ASN 特征词识别
  ORGLOW=$(echo "${GEO_ORG} ${GEO_ISP}" | tr '[:upper:]' '[:lower:]')
  case "$ORGLOW" in
    *hetzner*|*digitalocean*|*vultr*|*linode*|*ovh*|*leaseweb*|*choopa*|*amazon*|*google*cloud*|*microsoft*azure*|*alibaba*|*tencent*|*racknerd*|*bandwagon*|*host*|*server*|*data*center*|*vps*|*colocrossing*|*cloudflare*|*oracle*)
      ASN_TYPE="datacenter"
      ASN_NOTE="识别为典型机房/云厂商 ASN：日常跨境 / VLESS-Reality 部署无问题；多账号场景建议混住宅 IP 用"
      ASN_SCORE=65
      ;;
    *comcast*|*charter*|*cox*|*verizon*fios|*at&t*|*spectrum*|*vodafone*|*deutsche*telekom*|*orange*|*docomo*|*softbank*|*kddi*|*china*mobile*|*china*unicom*|*china*telecom*)
      ASN_TYPE="residential"
      ASN_NOTE="识别为住宅宽带 / 移动运营商 ASN：非常适合 Amazon/TikTok 多账号！"
      ASN_SCORE=100
      ;;
    *university*|*edu*|*school*|*college*)
      ASN_TYPE="education"
      ASN_NOTE="校园网 ASN：IP 干净度高但风控会识别成校园用户"
      ASN_SCORE=75
      ;;
    *)
      # 尝试 ipinfo 免费 API 拿 type（没 key 的话会给很粗的分类）
      IPINFO_ASN=$(curl -s --max-time 8 "https://ipinfo.io/${TARGET_IP}/org" 2>/dev/null | tr '[:upper:]' '[:lower:]')
      case "$IPINFO_ASN" in
        *hosting*|*datacenter*) ASN_TYPE="datacenter"; ASN_NOTE="ipinfo 分类：hosting/datacenter（机房）"; ASN_SCORE=60;;
        *residential*) ASN_TYPE="residential"; ASN_NOTE="ipinfo 分类：residential（住宅）"; ASN_SCORE=100;;
        *business*) ASN_TYPE="business"; ASN_NOTE="ipinfo 分类：business（企业宽带）"; ASN_SCORE=85;;
        *) ASN_TYPE="other"; ASN_NOTE="无法从关键词精准归类，建议网页查 bgp.he.net"; ASN_SCORE=75;;
      esac
  esac
fi
case "$ASN_TYPE" in
  residential) ASN_COLOR=$GRN;;
  datacenter)  ASN_COLOR=$CYN;;
  business)    ASN_COLOR=$BLU;;
  *)           ASN_COLOR=$YLW;;
esac
echo -e "  ASN 号：${WHT}AS${ASN_NUM:-未知}${RST}    类型：${ASN_COLOR}${ASN_TYPE}${RST}"
echo -e "  ${DIM}${ASN_NOTE}${RST}"
echo -e "  ${DIM}ASN 子项得分：${ASN_SCORE}/100${RST}"
echo ""

# ======================================================================
# 4. RBL 黑名单（仅 IPv4；多数 DNSBL 不支持 IPv6，IPv6 直接满分跳过）
# ======================================================================
if [ "$IP_VER" = "4" ]; then
echo -e "${BOLD}${BLU}[3/7]${RST} ${WHT}🚫 RBL 黑名单检查（6 源 DNS 查询，无需 key）${RST}"
RBL_ZONES=(
  "zen.spamhaus.org"
  "all.s5h.net"
  "bl.spamcop.net"
  "cbl.abuseat.org"
  "virbl.dnsbl.bit.nl"
  "dnsbl.sorbs.net"
)
RBL_HIT=0
RBL_HIT_ZONES=""
for zone in "${RBL_ZONES[@]}"; do
  result=$(dig +short -t a "${REV_IP}.${zone}." 2>/dev/null | head -1)
  if [ -n "$result" ]; then
    case "$result" in
      127.0.0.*)
        RBL_HIT=$((RBL_HIT+1))
        RBL_HIT_ZONES="$RBL_HIT_ZONES ${zone}(${result})";;
    esac
  fi
done
# 每命中 1 条扣 15 分
RBL_SCORE=$((100 - RBL_HIT*15))
[ $RBL_SCORE -lt 0 ] && RBL_SCORE=0
if [ $RBL_HIT -eq 0 ]; then
  echo -e "  ${GRN}✔ 未命中任何 DNSBL 黑名单${RST}"
else
  echo -e "  ${RED}✖ 命中 ${RBL_HIT} 条 RBL：${RBL_HIT_ZONES}${RST}"
fi
echo -e "  ${DIM}RBL 子项得分：${RBL_SCORE}/100${RST}"
else
echo -e "${BOLD}${BLU}[3/7]${RST} ${WHT}🚫 RBL 黑名单检查（IPv6 skip：多数 DNSBL 不支持 IPv6 查询）${RST}"
RBL_HIT=0
RBL_HIT_ZONES=""
RBL_SCORE=100
echo -e "  ${CYN}ℹ 目标为 IPv6 → 跳过 RBL 检查（公开 DNSBL 对 IPv6 支持极少），RBL 计满分${RST}"
echo -e "  ${DIM}RBL 子项得分：${RBL_SCORE}/100${RST}"
fi
echo ""

# ======================================================================
# 5. AbuseIPDB（需 key，免费 1000 次/天）
# ======================================================================
echo -e "${BOLD}${BLU}[4/7]${RST} ${WHT}🛡️ AbuseIPDB（滥用报告数/置信度）${RST}"
ABUSE_SCORE=100; ABUSE_REPORTED="未配置 Key 跳过"; ABUSE_CONF=""
if [ -n "${ABUSEIPDB_KEY:-}" ]; then
  ABUSE_RESP=$(curl -s --max-time 15 -G \
    -H "Key: ${ABUSEIPDB_KEY}" \
    -H "Accept: application/json" \
    --data-urlencode "ipAddress=${TARGET_IP}" \
    --data-urlencode "maxAgeInDays=90" \
    "https://api.abuseipdb.com/api/v2/check" 2>/dev/null)
  if echo "$ABUSE_RESP" | grep -q '"abuseConfidenceScore"'; then
    ABUSE_CONF=$(echo "$ABUSE_RESP" | jq -r '.data.abuseConfidenceScore // 0' 2>/dev/null)
    ABUSE_TOTAL=$(echo "$ABUSE_RESP" | jq -r '.data.totalReports // 0' 2>/dev/null)
    ABUSE_DOMAIN=$(echo "$ABUSE_RESP" | jq -r '.data.domain // ""' 2>/dev/null)
    ABUSE_USAGE=$(echo "$ABUSE_RESP" | jq -r '.data.usageType // ""' 2>/dev/null)
    # 置信度 0 → 100 分，每 1% 扣 1 分；报告数>50 再额外-10
    ABUSE_SCORE=$((100 - ABUSE_CONF))
    [ "$ABUSE_TOTAL" -gt 50 ] 2>/dev/null && ABUSE_SCORE=$((ABUSE_SCORE-10))
    [ $ABUSE_SCORE -lt 0 ] && ABUSE_SCORE=0
    ABUSE_REPORTED="${ABUSE_TOTAL:-?} 份报告（置信度 ${ABUSE_CONF}%）Usage=${ABUSE_USAGE:-?} Domain=${ABUSE_DOMAIN:-?}"
  else
    ABUSE_REPORTED="API 返回异常：$(echo "$ABUSE_RESP" | jq -r '.errors[0].detail // "unknown"' 2>/dev/null | cut -c1-60)"
    ABUSE_SCORE=60
  fi
else
  echo -e "  ${DIM}未设置 \$ABUSEIPDB_KEY → 跳过（免费申请：https://www.abuseipdb.com/  1000次/天）${RST}"
fi
if [ -n "${ABUSEIPDB_KEY:-}" ]; then
  if [ "$ABUSE_SCORE" -ge 85 ]; then echo -e "  ${GRN}✔ ${ABUSE_REPORTED}${RST}"
  elif [ "$ABUSE_SCORE" -ge 60 ]; then echo -e "  ${YLW}⚠ ${ABUSE_REPORTED}${RST}"
  else echo -e "  ${RED}✖ ${ABUSE_REPORTED}${RST}"; fi
fi
echo -e "  ${DIM}AbuseIPDB 子项得分：${ABUSE_SCORE}/100${RST}"
echo ""

# ======================================================================
# 6. IPQualityScore 欺诈评分（需 key，免费 5000 次/月）
# ======================================================================
echo -e "${BOLD}${BLU}[5/7]${RST} ${WHT}⚡ IPQualityScore（VPN/Proxy/ABOT/BOT 欺诈评分）${RST}"
IPQS_SCORE=100; IPQS_VPN=""; IPQS_PROXY=""; IPQS_BOT=""; IPQS_MSG="未配置 Key 跳过"
if [ -n "${IPQS_KEY:-}" ]; then
  IPQS_RESP=$(curl -s --max-time 15 \
    "https://ipqualityscore.com/api/json/ip/${IPQS_KEY}/${TARGET_IP}?strictness=1&allow_public_access_points=true" 2>/dev/null)
  if echo "$IPQS_RESP" | grep -q '"fraud_score"'; then
    FRAUD=$(echo "$IPQS_RESP" | jq -r '.fraud_score // 0' 2>/dev/null)
    IPQS_VPN=$(echo "$IPQS_RESP" | jq -r '.vpn // false' 2>/dev/null)
    IPQS_PROXY=$(echo "$IPQS_RESP" | jq -r '.proxy // false' 2>/dev/null)
    IPQS_BOT=$(echo "$IPQS_RESP" | jq -r '.bot_status // false' 2>/dev/null)
    IPQS_RECENT=$(echo "$IPQS_RESP" | jq -r '.recent_abuse // false' 2>/dev/null)
    # fraud_score 0 好 100 坏，每 1% 扣 1
    IPQS_SCORE=$((100 - FRAUD))
    [ "$IPQS_VPN" = "true" ] && IPQS_SCORE=$((IPQS_SCORE-10))
    [ "$IPQS_PROXY" = "true" ] && IPQS_SCORE=$((IPQS_SCORE-10))
    [ "$IPQS_BOT" = "true" ] && IPQS_SCORE=$((IPQS_SCORE-15))
    [ "$IPQS_RECENT" = "true" ] && IPQS_SCORE=$((IPQS_SCORE-20))
    [ $IPQS_SCORE -lt 0 ] && IPQS_SCORE=0
    IPQS_MSG="欺诈评分=${FRAUD}  VPN=${IPQS_VPN}  Proxy=${IPQS_PROXY}  Bot=${IPQS_BOT}  RecentAbuse=${IPQS_RECENT}"
  else
    IPQS_MSG="API 异常：$(echo "$IPQS_RESP" | jq -r '.message // "unknown"' 2>/dev/null | cut -c1-60)"
    IPQS_SCORE=60
  fi
else
  echo -e "  ${DIM}未设置 \$IPQS_KEY → 跳过（免费申请：https://www.ipqualityscore.com/  5000次/月）${RST}"
fi
if [ -n "${IPQS_KEY:-}" ]; then
  if [ "$IPQS_SCORE" -ge 85 ]; then echo -e "  ${GRN}✔ ${IPQS_MSG}${RST}"
  elif [ "$IPQS_SCORE" -ge 60 ]; then echo -e "  ${YLW}⚠ ${IPQS_MSG}${RST}"
  else echo -e "  ${RED}✖ ${IPQS_MSG}${RST}"; fi
fi
echo -e "  ${DIM}IPQualityScore 子项得分：${IPQS_SCORE}/100${RST}"
echo ""

# ======================================================================
# 7. Scamalytics（有免费 API 层；没 key 就用公开 HTML 解析拿分数）
# ======================================================================
echo -e "${BOLD}${BLU}[6/7]${RST} ${WHT}🔍 Scamalytics（IP 风险/欺诈指纹评分）${RST}"
SCAM_SCORE=100; SCAM_MSG="未配置 Key，尝试公开网页查询"
if [ -n "${SCAMALYTICS_KEY:-}" ]; then
  SCAM_RESP=$(curl -s --max-time 15 "https://api11.scamalytics.com/${SCAMALYTICS_KEY}/?ip=${TARGET_IP}" 2>/dev/null)
  RISK=$(echo "$SCAM_RESP" | jq -r '.score.risk // 0' 2>/dev/null)   # 0 低 100 高
  [ -n "$RISK" ] && SCAM_SCORE=$((100 - RISK))
  [ $SCAM_SCORE -lt 0 ] && SCAM_SCORE=0
  SCAM_MSG="RiskScore=${RISK}  原始分类：$(echo "$SCAM_RESP" | jq -r '.score.label // "?"' 2>/dev/null)"
else
  # 免费公开：走 HTML 页面解析，拿 <div class="score"> 里的风险分数
  SCAM_HTML=$(curl -s --max-time 15 -A "Mozilla/5.0 ip-check.sh" "https://scamalytics.com/ip/${TARGET_IP}" 2>/dev/null)
  FR_NUM=$(echo "$SCAM_HTML" | grep -oE 'Score[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  if [ -n "$FR_NUM" ]; then
    SCAM_SCORE=$((100 - FR_NUM))
    SCAM_MSG="公开页面抓取 RiskScore=${FR_NUM}（越高越差）"
  else
    SCAM_SCORE=75
    SCAM_MSG="公开页面抓取失败 → 给中性分 75"
  fi
fi
if [ "$SCAM_SCORE" -ge 85 ]; then echo -e "  ${GRN}✔ ${SCAM_MSG}${RST}"
elif [ "$SCAM_SCORE" -ge 60 ]; then echo -e "  ${YLW}⚠ ${SCAM_MSG}${RST}"
else echo -e "  ${RED}✖ ${SCAM_MSG}${RST}"; fi
echo -e "  ${DIM}Scamalytics 子项得分：${SCAM_SCORE}/100${RST}"
echo ""

# ======================================================================
# 8. Spur.us（VPN/代理/服务器 指纹检测，极其准；需 Token，有免费额度）
# ======================================================================
echo -e "${BOLD}${BLU}[7/7]${RST} ${WHT}🕵️ Spur.us（VPN/Residential/Server 深度指纹识别）${RST}"
SPUR_SCORE=100; SPUR_MSG="未配置 Token 跳过"
if [ -n "${SPUR_TOKEN:-}" ]; then
  SPUR_RESP=$(curl -s --max-time 15 -H "Token: ${SPUR_TOKEN}" "https://api.spur.us/v2/context/${TARGET_IP}" 2>/dev/null)
  if echo "$SPUR_RESP" | grep -qE '"ip"|"client"'; then
    TAG=$(echo "$SPUR_RESP" | jq -r '.infrastructure // .tag // .services[0] // "unknown"' 2>/dev/null | cut -c1-60)
    SVC=$(echo "$SPUR_RESP" | jq -r '[.services[]? // "none"] | join(",")' 2>/dev/null | cut -c1-80)
    VPN=$(echo "$SPUR_RESP" | jq -r '.vpnOperators // ""' 2>/dev/null)
    # tag 里出现 VPN/Anonymous/Proxy/Tor/Server → 扣分
    case "$(echo "$TAG $SVC $VPN $SPUR_RESP" | tr '[:upper:]' '[:lower:]')" in
      *tor*|*anon*) SPUR_SCORE=30;;
      *vpn*|*proxy*|*anonymizer*) SPUR_SCORE=50;;
      *datacenter*|*server*|*host*|*cloud*) SPUR_SCORE=70;;
      *residential*|*isp*|*mobile*) SPUR_SCORE=95;;
    esac
    SPUR_MSG="Tag=${TAG}  Services=${SVC}  VPN_Ops=${VPN:-无}"
  else
    SPUR_MSG="API 异常：$(echo "$SPUR_RESP" | head -c 80)"
    SPUR_SCORE=60
  fi
else
  echo -e "  ${DIM}未设置 \$SPUR_TOKEN → 跳过（申请：https://spur.us/  有免费教育/试用额度）${RST}"
fi
if [ -n "${SPUR_TOKEN:-}" ]; then
  if [ "$SPUR_SCORE" -ge 85 ]; then echo -e "  ${GRN}✔ ${SPUR_MSG}${RST}"
  elif [ "$SPUR_SCORE" -ge 60 ]; then echo -e "  ${YLW}⚠ ${SPUR_MSG}${RST}"
  else echo -e "  ${RED}✖ ${SPUR_MSG}${RST}"; fi
fi
echo -e "  ${DIM}Spur.us 子项得分：${SPUR_SCORE}/100${RST}"
echo ""

# ======================================================================
# 9. 综合加权评分 + 最终结论
# ======================================================================
FINAL=$((
  (GEO_SCORE*W_GEO
  + ASN_SCORE*W_ASN
  + RBL_SCORE*W_RBL
  + ABUSE_SCORE*W_ABUSE
  + IPQS_SCORE*W_IPQS
  + SCAM_SCORE*W_SCAM
  + SPUR_SCORE*W_SPUR) / 100
))
if   [ $FINAL -ge 85 ]; then VERDICT="PASS";   VC=$GRN
elif [ $FINAL -ge 60 ]; then VERDICT="WARNING";VC=$YLW
else                          VERDICT="FAIL";   VC=$RED
fi

echo ""
echo -e "${BOLD}${MGN}┌──────────────────────────────────────────────────────────────────┐${RST}"
echo -e "${BOLD}${MGN}│${RST}  ${BOLD}💯 综合评分（加权）：${WHT}${FINAL}/100${RST}   →  判定：${VC}${BOLD}${VERDICT}${RST}"
echo -e "${BOLD}${MGN}│${RST}"
echo -e "${BOLD}${MGN}│${RST}   ${DIM}GEO${RST}${DIM}(${W_GEO}%)${RST}:${GEO_SCORE}   ${DIM}ASN${RST}${DIM}(${W_ASN}%)${RST}:${ASN_SCORE}   ${DIM}RBL${RST}${DIM}(${W_RBL}%)${RST}:${RBL_SCORE}"
echo -e "${BOLD}${MGN}│${RST}   ${DIM}AbuseIPDB${RST}${DIM}(${W_ABUSE}%)${RST}:${ABUSE_SCORE}   ${DIM}IPQS${RST}${DIM}(${W_IPQS}%)${RST}:${IPQS_SCORE}"
echo -e "${BOLD}${MGN}│${RST}   ${DIM}Scamalytics${RST}${DIM}(${W_SCAM}%)${RST}:${SCAM_SCORE}   ${DIM}Spur${RST}${DIM}(${W_SPUR}%)${RST}:${SPUR_SCORE}"
echo -e "${BOLD}${MGN}└──────────────────────────────────────────────────────────────────┘${RST}"
case "$VERDICT" in
  PASS)
    echo ""
    echo -e "  ${GRN}✔ ${BOLD}PASS${RST}：IP 干净度优秀"
    echo -e "  ${GRN}   → 日常跨境 / VLESS-Reality / WireGuard 直接部署。${RST}"
    echo -e "  ${GRN}   → 做 Amazon/TikTok 多账号主节点前仍建议过 AdsPower/Multilogin 指纹环境验证。${RST}"
    ;;
  WARNING)
    echo ""
    echo -e "  ${YLW}⚠ ${BOLD}WARNING${RST}：有少量污点 / 典型机房 ASN（或未配置 Key 没跑全）"
    echo -e "  ${YLW}   → 日常看视频 / 远程办公 / ChatGPT：可以直接用。${RST}"
    echo -e "  ${YLW}   → 做电商多账号：不建议做【主节点】，建议换住宅IP/移动IP池，或至少换机房/重新开台拿新IP。${RST}"
    echo -e "  ${YLW}   → 把 ABUSEIPDB_KEY / IPQS_KEY / SPUR_TOKEN 配上，重新跑一次能更准。${RST}"
    ;;
  FAIL)
    echo ""
    echo -e "  ${RED}✖ ${BOLD}FAIL${RST}：这台机的 IP 历史极度脏，强风控环境必定触发关联"
    echo -e "  ${RED}   → 立刻行动：VPS 面板「重建实例」拿个新 IP，或开一台新区域机器；${RST}"
    echo -e "  ${RED}   → 再拿新 IP 重新跑 bash $0 $TARGET_IP 直到 PASS。${RST}"
    ;;
esac

# ======================================================================
# 10. 落盘 JSON，方便以后归档 / 给多账号系统做 IP 档案
# ======================================================================
jq -n \
  --arg ip "$TARGET_IP" \
  --arg ts "$(date '+%Y-%m-%d %H:%M:%S')" \
  --arg verdict "$VERDICT" \
  --arg final "$FINAL" \
  --arg geo_cc "$GEO_CC" --arg geo_country "$GEO_COUNTRY" --arg geo_city "$GEO_CITY" --arg geo_isp "$GEO_ISP" --arg geo_asn "$GEO_ASN" --arg geo_score "$GEO_SCORE" \
  --arg asn_type "$ASN_TYPE" --arg asn_note "$ASN_NOTE" --arg asn_score "$ASN_SCORE" \
  --arg rbl_hit "$RBL_HIT" --arg rbl_zones "$RBL_HIT_ZONES" --arg rbl_score "$RBL_SCORE" \
  --arg abuse_score "$ABUSE_SCORE" --arg abuse_note "$ABUSE_REPORTED" \
  --arg ipqs_score "$IPQS_SCORE" --arg ipqs_note "$IPQS_MSG" \
  --arg scam_score "$SCAM_SCORE" --arg scam_note "$SCAM_MSG" \
  --arg spur_score "$SPUR_SCORE" --arg spur_note "$SPUR_MSG" \
  '{ip:$ip, ts:$ts, verdict:$verdict, final_score:($final|tonumber),
    geo:{cc:$geo_cc, country:$geo_country, city:$geo_city, isp:$geo_isp, asn:$geo_asn, score:($geo_score|tonumber)},
    asn:{type:$asn_type, note:$asn_note, score:($asn_score|tonumber)},
    rbl:{hit:($rbl_hit|tonumber), zones:$rbl_zones, score:($rbl_score|tonumber)},
    abuseipdb:{score:($abuse_score|tonumber), note:$abuse_note},
    ipqualityscore:{score:($ipqs_score|tonumber), note:$ipqs_note},
    scamalytics:{score:($scam_score|tonumber), note:$scam_note},
    spur:{score:($spur_score|tonumber), note:$spur_note}}' > "$OUT_JSON" 2>/dev/null

echo ""
echo -e "${DIM}📄 完整 JSON 档案已保存：${OUT_JSON}${RST}"
echo -e "${DIM}下次部署 VPN 前建议：先跑一遍 ip-check.sh → 确认 PASS 或 WARNING，再 bash vpn.sh${RST}"
exit 0
IPCHECK_EOF
    chmod +x "$IPCHECK_PATH"
    green "  -> ip-check.sh deployed to $IPCHECK_PATH  (PRECHECK_IP=1 bash vpn.sh  OR  bash $IPCHECK_PATH)"

    # ---- Optional pre-check (opt-in via PRECHECK_IP=1) ----
    if [ "${PRECHECK_IP:-}" = "1" ]; then
        echo ""
        blue "========== [PRECHECK 0/7] IP Health Check Before Deploy =========="
        bash $IPCHECK_PATH || true
        echo ""
        blue "Pre-check done. If FAIL verdict, Ctrl+C now, rebuild instance for new IP, re-run."
        sleep 3
    fi}

# =====================================================
# 纯 bash 补丁工具：在第 N 行之后插入多行内容
# =====================================================
_insert_after_line() {
    local file="$1" match_line="$2" patch_text="$3" tmp="${1}.patch.$$"
    awk -v needle="$match_line" -v patch="$patch_text" '
    { print }
    $0 ~ needle { print patch }
    ' "$file" > "$tmp" && mv -f "$tmp" "$file"
}

# =====================================================
# Step 2. 准备并改造 sb.sh（纯 bash，避免正则陷阱）
# =====================================================
step2_prepare_patch_sbsh(){
    green "[2/7] 准备并改造 sb.sh..."
    local SB="$WORKDIR/sb.sh"

    if [ ! -f "$SB" ] || [ ! -s "$SB" ]; then
        yellow "  -> 本地未发现 sb.sh，尝试从网络下载..."
        ( curl -sL -o "$SB" "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" ) 2>/dev/null
        ( curl -sL -o "$SB.2" "https://fastly.jsdelivr.net/gh/yonggekkk/sing-box-yg@main/sb.sh" ) 2>/dev/null
        if [ -f "$SB.2" ] && [ -s "$SB.2" ]; then
            local sz1 sz2
            sz1=$(wc -c < "$SB" 2>/dev/null || echo 0)
            sz2=$(wc -c < "$SB.2")
            [ "$sz2" -gt "$sz1" ] && mv -f "$SB.2" "$SB" || rm -f "$SB.2"
        fi
    fi
    if [ ! -s "$SB" ]; then
        red "  -> sb.sh 获取失败，请手动把 sb.sh 放到和 vpn.sh 同目录后重试"
        exit 1
    fi
    green "  -> sb.sh 就绪 ($(wc -l < "$SB") 行)"

    if grep -q "_VPN_PATCH_MARK_" "$SB" 2>/dev/null; then
        green "  -> sb.sh 已打过补丁，跳过改造"
        return 0
    fi

    # 备份一份原始
    cp -f "$SB" "${SB}.orig" 2>/dev/null || true

    # ------------------------------------------------------------------
    # 补丁 1：替换 readp 函数（原单行定义）为：非交互 tty 时，read 加 0.3s 超时
    #         并且在替换前先插入 wget 预安装段
    # ------------------------------------------------------------------
    local wget_patch readp_patch
    wget_patch='# ===== _VPN_PATCH_MARK_ =====
if ! command -v wget &>/dev/null; then
    if [ -x "$(command -v apt-get)" ]; then apt-get update -y >/dev/null 2>&1; apt-get install -y wget curl >/dev/null 2>&1
    elif [ -x "$(command -v yum)" ]; then yum install -y wget curl >/dev/null 2>&1
    elif [ -x "$(command -v dnf)" ]; then dnf install -y wget curl >/dev/null 2>&1
    elif command -v apk >/dev/null 2>&1; then apk add wget curl >/dev/null 2>&1; fi
fi'
    readp_patch='readp(){
    if [ -t 0 ]; then
        read -p "$(yellow "$1")" $2
    else
        read -t 0.3 -r -p "$(yellow "$1")" $2 || true
        # 超时 / 空输入 -> 保持变量为空，脚本会走默认值分支
    fi
}'

    # 使用 awk：定位到第 14 行（原始 sb.sh 的 "readp(){ read ...}"），先输出 wget_patch，再输出 readp_patch，跳过原始单行
    local sb_tmp="${SB}.awk.$$"
    awk -v WP="$wget_patch" -v RP="$readp_patch" '
    BEGIN { done = 0 }
    {
        if (!done && $0 ~ /^readp\(\)\{/) {
            print WP
            print RP
            done = 1
            next
        }
        print
    }
    END { if (!done) { print WP; print RP } }
    ' "$SB" > "$sb_tmp" && mv -f "$sb_tmp" "$SB"
    green "  -> 补丁 1 已应用 (wget 预安装 + readp 超时)"

    # ------------------------------------------------------------------
    # 补丁 2：在 sbshare 函数中 "sb_client" 后面调用 sb_output.sh main
    # ------------------------------------------------------------------
    if ! grep -q "sb_output.sh" "$SB"; then
        local sb_tmp2="${SB}.hook.$$"
        # 只替换 sbshare 函数末尾处的那个 sb_client（只替换第 1 个匹配行 → sbshare 是最早调用 sb_client 的函数）
        awk '
        BEGIN { replaced = 0 }
        {
            if (!replaced && $0 ~ /^[[:space:]]*sb_client[[:space:]]*$/) {
                print
                print ""
                print "if [ -f /etc/s-box/sb_output.sh ]; then"
                print "    bash /etc/s-box/sb_output.sh main"
                print "elif [ -f sb_output.sh ]; then"
                print "    bash sb_output.sh main"
                print "fi"
                replaced = 1
                next
            }
            print
        }
        ' "$SB" > "$sb_tmp2" && mv -f "$sb_tmp2" "$SB"
        green "  -> 补丁 2 已应用 (sbshare 末尾追加 sb_output.sh hook)"
    else
        green "  -> 补丁 2 已存在 (sb_output.sh hook)"
    fi
    chmod +x "$SB"
}

# =====================================================
# Step 3. 无交互执行 sb.sh：安装 sing-box + 刷新分享
# =====================================================
step3_run_sbsh(){
    green "[3/7] 执行 sb.sh 一键安装 Sing-box + 生成分享..."
    local SB="$WORKDIR/sb.sh"

    if [ -f '/etc/systemd/system/sing-box.service' ] && [ -f /etc/s-box/sb.json ]; then
        yellow "  -> 检测到 sing-box 已安装，跳过安装"
    else
        green "  -> 安装 sing-box（全自动，3-8 分钟）..."
        # 菜单选项 1 进入安装；随后输出足够多的空行应对各子提示；sleep 5 再输出 0 退出菜单
        (
            echo "1"
            for _ in $(seq 1 40); do echo ""; done
            sleep 6
            echo "0"
        ) | bash "$SB" > /var/log/vpn_sb_install.log 2>&1 || true
        # 等 sb.json 生成
        local wait_n=0
        while [ $wait_n -lt 60 ]; do
            [ -f /etc/s-box/sb.json ] && break
            sleep 2; wait_n=$((wait_n+1))
        done
    fi

    # 刷新分享链接 & 生成 HTML：菜单 9 → 子菜单 1 → 0 → 0
    if [ -f /etc/s-box/sb.json ]; then
        green "  -> 刷新分享链接 / 生成 HTML 页面..."
        (
            echo "9"
            sleep 3
            echo "1"
            sleep 10
            echo "0"
            sleep 1
            echo "0"
        ) | bash "$SB" > /var/log/vpn_sb_share.log 2>&1 || true
    fi

    # 兜底：确保有 latest/index.html
    if [ ! -f "$OUTPUT_BASE/latest/index.html" ]; then
        yellow "  -> 兜底调用 sb_output.sh..."
        bash "$SB_OUTPUT_PATH" main >/dev/null 2>&1 || true
        local latest
        latest=$(ls -1d "$OUTPUT_BASE"/*/ 2>/dev/null | grep -v '/latest/' | sort | tail -n1 | sed 's|/$||')
        [ -n "$latest" ] && ln -sfn "$latest" "$OUTPUT_BASE/latest" 2>/dev/null || true
    fi

    if [ -f "$OUTPUT_BASE/latest/index.html" ]; then
        green "  -> HTML 生成成功: $(readlink -f "$OUTPUT_BASE/latest" 2>/dev/null)"
    else
        yellow "  -> HTML 未生成（可事后手动执行：bash $SB_OUTPUT_PATH main）"
    fi
}

# =====================================================
# Step 4. 安装 Nginx
# =====================================================
step4_install_nginx(){
    green "[4/7] 安装 Nginx..."
    if command -v nginx &>/dev/null; then green "  -> Nginx 已存在"; return 0; fi
    if [ -x "$(command -v apt-get)" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >/dev/null 2>&1
        NGINX_CONF_PATH="/etc/nginx/sites-available/default"
    elif [ -x "$(command -v yum)" ]; then
        yum install -y epel-release >/dev/null 2>&1 || true
        yum install -y nginx >/dev/null 2>&1
        NGINX_CONF_PATH="/etc/nginx/conf.d/default.conf"
    elif [ -x "$(command -v dnf)" ]; then
        dnf install -y nginx >/dev/null 2>&1
        NGINX_CONF_PATH="/etc/nginx/conf.d/default.conf"
    elif command -v apk >/dev/null 2>&1; then
        apk add nginx >/dev/null 2>&1
        NGINX_CONF_PATH="/etc/nginx/http.d/default.conf"
    else
        red "  -> 未识别的包管理器"
        return 1
    fi
    command -v nginx &>/dev/null && green "  -> Nginx 安装完成" || { red "  -> Nginx 安装失败"; return 1; }
}

# =====================================================
# Step 5. 覆盖写入 Nginx 默认配置
# =====================================================
step5_write_nginx_conf(){
    green "[5/7] 写入 Nginx 配置..."
    mkdir -p "$OUTPUT_BASE"
    # 推断默认配置路径
    if [ -z "$NGINX_CONF_PATH" ] || [ ! -d "$(dirname "$NGINX_CONF_PATH")" ]; then
        if [ -d /etc/nginx/sites-available ]; then
            NGINX_CONF_PATH="/etc/nginx/sites-available/default"
        elif [ -d /etc/nginx/conf.d ]; then
            NGINX_CONF_PATH="/etc/nginx/conf.d/default.conf"
        else
            NGINX_CONF_PATH="/etc/nginx/nginx.conf"
        fi
    fi
    # 备份原文件
    if [ -f "$NGINX_CONF_PATH" ]; then
        cp -f "$NGINX_CONF_PATH" "${NGINX_CONF_PATH}.vpn.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
    # 权限设置（nginx 运行用户）
    chmod -R 755 /etc/s-box 2>/dev/null || true
    if id nginx &>/dev/null; then
        chown -R nginx:nginx /etc/s-box/output 2>/dev/null || true
    elif id www-data &>/dev/null; then
        chown -R www-data:www-data /etc/s-box/output 2>/dev/null || true
    fi

    if [ "$NGINX_CONF_PATH" = "/etc/nginx/nginx.conf" ]; then
        cat > "$NGINX_CONF_PATH" <<'NGX_MAIN'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    sendfile on; tcp_nopush on; types_hash_max_size 2048;
    include /etc/nginx/mime.types; default_type application/octet-stream;
    access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log;
    server {
        listen 80 default_server; server_name _;
        root /etc/s-box/output; index index.html; autoindex on;
        location = / { return 302 /latest/; }
        location ^~ /latest/ { alias /etc/s-box/output/latest/; try_files $uri $uri/ =404; }
        location / { try_files $uri $uri/ =404; }
    }
}
NGX_MAIN
    else
        cat > "$NGINX_CONF_PATH" <<'NGX_SRV'
server {
    listen 80 default_server; server_name _;
    root /etc/s-box/output; index index.html; autoindex on;
    location = / { return 302 /latest/; }
    location ^~ /latest/ { alias /etc/s-box/output/latest/; try_files $uri $uri/ =404; }
    location / { try_files $uri $uri/ =404; }
}
NGX_SRV
        # Debian/Ubuntu 启用 sites-available
        if [ -d /etc/nginx/sites-enabled ] && [ ! -L /etc/nginx/sites-enabled/default ]; then
            ln -sfn /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
        fi
        # CentOS 的 nginx.conf 里可能默认 include /etc/nginx/conf.d/*.conf 之外还带了默认 server；保险起见删除 conf.d 中其他 default 冲突
        [ -f /etc/nginx/conf.d/default.conf ] && [ -f /etc/nginx/conf.d/ssl.conf ] && rm -f /etc/nginx/conf.d/ssl.conf 2>/dev/null || true
    fi
    green "  -> 配置写入: $NGINX_CONF_PATH"

    # 测试 & 重载
    nginx -t > /var/log/vpn_nginx_test.log 2>&1
    if [ $? -eq 0 ]; then
        systemctl enable nginx >/dev/null 2>&1 || true
        systemctl restart nginx >/dev/null 2>&1 || nginx -s reload 2>/dev/null || nginx 2>/dev/null || true
        green "  -> Nginx 已启动并载入新配置"
    else
        red "  -> Nginx 配置测试失败，详见 /var/log/vpn_nginx_test.log"
        cat /var/log/vpn_nginx_test.log 2>/dev/null
        return 1
    fi
}

# =====================================================
# Step 6. 关闭系统防火墙（如可用）
# =====================================================
step6_open_ports(){
    green "[6/7] 放开系统防火墙端口..."
    if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
        firewall-cmd --permanent --add-service=http >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port=1-65535/tcp >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port=1-65535/udp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        green "  -> firewalld 已放开端口"
    elif command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw --force allow 80/tcp >/dev/null 2>&1 || true
            ufw --force allow 1:65535/tcp >/dev/null 2>&1 || true
            ufw --force allow 1:65535/udp >/dev/null 2>&1 || true
            green "  -> ufw 已放开端口"
        else
            green "  -> ufw 未启用，跳过"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
        green "  -> iptables 放行 80 端口"
    fi
}

# =====================================================
# Step 7. 输出最终访问地址
# =====================================================
step7_show_result(){
    green "[7/7] 部署完成 ✅"
    echo
    local pub=""
    pub=$(curl -s4m5 icanhazip.com 2>/dev/null)
    [ -z "$pub" ] && pub=$(curl -s4m5 ifconfig.me 2>/dev/null)
    [ -z "$pub" ] && pub=$(curl -s4m5 ipv4.icanhazip.com 2>/dev/null)
    [ -z "$pub" ] && pub=$(hostname -I 2>/dev/null | awk '{print $1}')

    white "========================================================================"
    blue "   🌐 访问地址（浏览器直接打开即可查看节点接入页面 / 扫码即用）："
    green "      http://${pub}/               （自动跳转到最新配置）"
    yellow "      http://${pub}/latest/        （直接访问最新目录）"
    white "========================================================================"
    echo
    if [ -L "$OUTPUT_BASE/latest" ]; then
        blue "   📂 最新输出目录：$(readlink -f "$OUTPUT_BASE/latest" 2>/dev/null)"
    fi
    echo
    blue "   📜 日志文件："
    blue "      安装日志  /var/log/vpn_sb_install.log"
    blue "      分享日志  /var/log/vpn_sb_share.log"
    blue "      Nginx 日志 /var/log/vpn_nginx_test.log"
    echo
    yellow "   注意：如果无法访问页面，请确认云服务商安全组（或外部防火墙）"
    yellow "         已放行 TCP 80 端口和 TCP/UDP 10000-65535 全段端口。"
    echo
}

# =====================================================
# 主入口
# =====================================================
main(){
    echo
    red   "=================================================================="
    green "         VPN 一键部署脚本  (Sing-box + Nginx + HTML 配置页)"
    red   "=================================================================="
    echo
    if [ "${1:-}" = "--precheck" ]; then PRECHECK_IP=1; export PRECHECK_IP; fi

    step0_install_base
    step1_deploy_output_helper
    step2_prepare_patch_sbsh
    step3_run_sbsh
    step4_install_nginx
    step5_write_nginx_conf
    step6_open_ports
    step7_show_result
}

main "$@"
