#!/bin/bash
export LANG=en_US.UTF-8
set +e

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
SB_OUTPUT_PATH="/etc/s-box/sb_output.sh"
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
    _inst wget; _inst curl; _inst jq; _inst python3
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

_CLIENT_BADGES_ALL='<div class="client-badges"><span class="badge b-rocket" title="Shadowrocket (小火箭)">🚀 小火箭</span><span class="badge b-v2ray" title="v2rayNG / v2rayN">🟢 v2rayNG / v2rayN</span><span class="badge b-neko" title="NekoBox / NekoRay">📦 NekoBox / NekoRay</span><span class="badge b-clash" title="Clash Verge Rev">🐱 Clash Verge</span><span class="badge b-sfa" title="sing-box 官方 SFA / SFI / SFM">✨ SFA · SFI · SFM</span></div>'

generate_html() {
    local html_file="$DATE_FOLDER/index.html"
    local hostname gen_time
    hostname=$(hostname 2>/dev/null || echo "vpn-server")
    gen_time=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    [ -n "$gen_time" ] || gen_time=$(date 2>/dev/null || date -u 2>/dev/null || echo "Unknown")

    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPN 节点配置 / 扫码导入 · ${gen_time}</title>
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
            <h1>🚀 VPN 节点配置中心 <small>扫码即连 · 复制即用</small></h1>
            <p>
                <span>📅 生成时间：${gen_time}</span>
                <span>🖥️ 主机名：${hostname}</span>
                <span>📦 输出目录：<code style="color:#7dd3fc;font-size:12px;">${DATE_FOLDER}</code></span>
            </p>
        </div>

        <!-- ===== Hero：客户端工具 & 快速上手 ===== -->
        <div class="hero">
            <h2>📱 用什么工具扫码 / 导入链接？</h2>
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
                <h4>⭐ 首选：v2rayNG（免费，全协议原生支持）</h4>
                <ol>
                    <li>GitHub 搜 v2rayNG 下载最新 release（.apk）或 F-Droid / Google Play 搜 <code>v2rayNG</code></li>
                    <li>首页右上角 <b>➕</b> →「<b>扫描二维码</b>」（相机权限允许）或「<b>从剪贴板导入</b>」</li>
                    <li>右下角 <b>V</b> 图标切换系统代理 → 选择节点即可</li>
                </ol>
                <h4>📦 新选：NekoBox（sing-box 内核，UI 更现代）</h4>
                <ol><li>首页右下角 ➕ →「Scan QR code」扫码 或 「Import from Clipboard」从剪贴板导入</li></ol>
                <h4>✨ 官方：SFA（sing-box for Android / Google TV / 车机）</h4>
            </div>
            <div id="plat-win" class="platform-panel">
                <h4>⭐ 首选：v2rayN（国内用户最多，免费开源）</h4>
                <ol>
                    <li>GitHub 搜 <code>2dust/v2rayN</code> 下载 zip，解压运行 <code>v2rayN.exe</code></li>
                    <li>顶部菜单「服务器」→「<b>扫描屏幕二维码</b>」（自动取当前屏任意二维码）</li>
                    <li>或点「<b>从剪贴板导入批量 URL</b>」→ 直接粘贴「聚合节点」复制的全部链接</li>
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
                小火箭选「配置 → 粘贴链接」、v2rayN/v2rayNG 按 <code>Ctrl+V</code> 或「从剪贴板导入批量 URL」、
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
                <summary>📱 详细扫码导入教程：小火箭 / v2rayNG / NekoBox / Clash Verge</summary>
                <div class="guide">
                    <h5>🚀 iOS · Shadowrocket（小火箭）扫码三步走</h5>
                    <ol>
                        <li>App Store 下载 <code>Shadowrocket</code>（美区/港区账号）</li>
                        <li>首页右上角 <b>➕ 加号</b> →「扫码」→ 对准上方任一协议二维码；字段自动填入后 <b>保存</b></li>
                        <li>App 顶部大开关拨到<b>开启</b>，第一次会弹「添加 VPN 配置」允许即可</li>
                    </ol>
                    <p style="margin:8px 0;color:#94a3b8;">💡 推荐一次性导入所有：点上方聚合节点按钮复制全部 → 发到 iPhone 备忘录 → 长按链接 → 选 <b>Shadowrocket 拷贝链接</b>。</p>

                    <h5>🤖 Android · v2rayNG 四步走</h5>
                    <ol>
                        <li>GitHub 下 v2rayNG 安装包 → 打开 App</li>
                        <li>首页右上角 ➕ →「扫码」 或「从剪贴板导入」</li>
                        <li>左上角菜单 →「服务器」选择对应节点</li>
                        <li>右下角圆形 <b>V 图标</b> 开启系统代理，状态栏出现 V 图标表示成功</li>
                    </ol>

                    <h5>📦 新选 Android · NekoBox（sing-box 内核）</h5>
                    <ul><li>右下角 ➕ → Scan QR code / Import from Clipboard → 底部切到「配置」选项卡 → 打开开关即可。</li></ul>

                    <h5>🪟 Windows · v2rayN 桌面端（最简单）</h5>
                    <ol>
                        <li>解压缩 v2rayN.zip 后运行 <code>v2rayN.exe</code>（托盘区会出现 V 图标）</li>
                        <li>双击托盘图标打开窗口 → 菜单「服务器 → 扫描屏幕二维码」（会自动截屏识别当前屏幕上所有二维码）</li>
                        <li>或「服务器 → 从剪贴板导入批量 URL」→ 粘贴聚合节点 → 一次性导入所有节点</li>
                        <li>托盘图标右键 →「系统代理 → 自动配置系统代理」→ 开始使用</li>
                    </ol>

                    <h5>🍏 macOS · Clash Verge Rev</h5>
                    <ol>
                        <li>安装 Clash Verge Rev → 左侧栏「订阅」→ 新建 → 粘贴你自己转换好的订阅链接</li>
                        <li>对于 v2rayNG / sb.sh 格式的分享链接：用在线工具转成 Clash 订阅格式，或安装 v2rayU 直接粘链接</li>
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
                    <h5>1. 小火箭 / v2rayNG 扫不到二维码？</h5>
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
                        <li>如果你装了 Chrome 插件 <b>Ghelper</b>：插件设置里把 VPN 服务器 IP 加入「直连域名列表」，或临时切到「仅国内加速」模式即可</li>
                        <li>云厂商安全组：确认 <b>TCP 80</b> 端口已放通（UDP 协议 VPN 端口也要放行对应端口段）</li>
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
                <li><b>路由器全屋代理：</b>OpenWrt + PassWall2 按上方「协议配置详情」填参数即可，电视 / Switch / PS5 / IoT 全设备不用单独装客户端</li>
                <li><b>定期备份：</b>备份 <code>/etc/s-box/sb.json</code> 和 <code>/etc/s-box/private.key</code>，即使 VPS 重装，把文件放回 → 重新跑 vpn.sh → <b>旧链接依然可用</b></li>
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
    green "  -> $SB_OUTPUT_PATH 已部署"
}

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
    blue "   🌐 访问地址（浏览器直接打开即可查看 VPN 配置页）："
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
