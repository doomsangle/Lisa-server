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
    local today max_num new_num dir num
    mkdir -p "$OUTPUT_BASE"
    today=$(date +%Y%m%d)
    max_num=0
    for dir in "$OUTPUT_BASE"/"$today"-*; do
        [ -d "$dir" ] || continue
        num=$(basename "$dir" | sed "s/^$today-//")
        [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt "$max_num" ] && max_num="$num"
    done
    new_num=$((max_num + 1))
    DATE_FOLDER="$OUTPUT_BASE/${today}-${new_num}"
    mkdir -p "$DATE_FOLDER"
    echo "DATE_FOLDER=$DATE_FOLDER"
}

generate_qr_codes() {
    local base_dir="/etc/s-box"
    local files=("vl_reality.txt" "vm_ws.txt" "vm_ws_tls.txt" "vm_ws_argols.txt" "vm_ws_argogd.txt" "hy2.txt" "tuic5.txt" "an.txt" "jhsub.txt")
    local file content name
    for file in "${files[@]}"; do
        [ -f "$base_dir/$file" ] || continue
        content=$(cat "$base_dir/$file" 2>/dev/null)
        name="${file%.txt}"
        [ -n "$content" ] && echo "$content" > "$DATE_FOLDER/$file"
        if command -v qrencode >/dev/null 2>&1 && [ -n "$content" ]; then
            qrencode -o "$DATE_FOLDER/${name}.png" "$content" 2>/dev/null || true
        fi
    done
}

write_html_section(){
    local html_file="$1" name="$2" title="$3" txt="$4" link id
    [ -f "$DATE_FOLDER/$txt" ] || return 0
    link=$(cat "$DATE_FOLDER/$txt")
    id="${name//-/_}_link"
    cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title"><span>🔹</span><span>$title</span></div>
            <div class="qrcode-container">
                <div class="qrcode-box"><img src="${name}.png" alt="$title QR Code"></div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="$id">$link</div>
                    <button class="copy-btn" onclick="copyText('$id')">复制链接</button>
                </div>
            </div>
        </div>
EOF
}

generate_html() {
    local html_file="$DATE_FOLDER/index.html"
    local hostname uuid vl_port vm_port hy2_port tu5_port vl_sni jh
    hostname=$(hostname)
    cat > "$html_file" <<'HTOP'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sing-box 节点配置</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#1a1a2e 0%,#16213e 100%);min-height:100vh;padding:20px;color:#fff}
.container{max-width:1200px;margin:0 auto}
.header{text-align:center;color:#fff;margin-bottom:30px}
.header h1{font-size:28px;margin-bottom:10px}
.header p{color:#aaa}
.card{background:#2d3436;border-radius:12px;padding:24px;margin-bottom:20px;box-shadow:0 4px 15px rgba(0,0,0,.3)}
.card-title{color:#00b894;font-size:20px;margin-bottom:20px;display:flex;align-items:center;gap:10px}
.card-title span{font-size:24px}
.qrcode-container{display:flex;align-items:center;gap:30px;flex-wrap:wrap}
.qrcode-box{background:#fff;padding:10px;border-radius:8px}
.qrcode-box img{display:block;width:150px;height:150px}
.link-info{flex:1;min-width:300px}
.link-label{color:#fdcb6e;font-size:14px;margin-bottom:8px}
.link-value{background:#1a1a2e;color:#fff;padding:12px;border-radius:8px;word-break:break-all;font-family:monospace;font-size:13px;line-height:1.6}
.copy-btn{background:#0984e3;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;margin-top:10px;font-size:14px}
.copy-btn:hover{background:#74b9ff}
.protocol-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px}
.protocol-card{background:#34495e;border-radius:10px;padding:20px}
.protocol-name{color:#00b894;font-size:18px;margin-bottom:15px}
.info-row{display:flex;margin-bottom:10px}
.info-label{color:#fdcb6e;width:100px;flex-shrink:0}
.info-value{color:#fff;flex:1;word-break:break-all}
.footer{text-align:center;color:#636e72;margin-top:30px;font-size:14px}
@media(max-width:768px){.qrcode-container{flex-direction:column}.protocol-grid{grid-template-columns:1fr}}
</style>
</head>
<body><div class="container">
HTOP
    cat >> "$html_file" <<EOF
    <div class="header">
        <h1>🚀 Sing-box 节点配置信息</h1>
        <p>生成时间: $(date '+%Y-%m-%d %H:%M:%S') | 主机名: $hostname</p>
    </div>
EOF
    write_html_section "$html_file" "vl_reality"      "Vless-Reality-Vision"   "vl_reality.txt"
    write_html_section "$html_file" "vm_ws"            "Vmess-WS"               "vm_ws.txt"
    write_html_section "$html_file" "vm_ws_tls"        "Vmess-WS-TLS"           "vm_ws_tls.txt"
    write_html_section "$html_file" "vm_ws_argols"     "Vmess-WS + Argo 临时"   "vm_ws_argols.txt"
    write_html_section "$html_file" "vm_ws_argogd"     "Vmess-WS + Argo 固定"   "vm_ws_argogd.txt"
    write_html_section "$html_file" "hy2"              "Hysteria-2"             "hy2.txt"
    write_html_section "$html_file" "tuic5"            "Tuic-v5"                "tuic5.txt"
    write_html_section "$html_file" "an"               "Anytls"                 "an.txt"
    if [ -f "$DATE_FOLDER/jhsub.txt" ]; then
        jh=$(cat "$DATE_FOLDER/jhsub.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title"><span>🔹</span><span>聚合节点</span></div>
            <div class="link-info">
                <div class="link-label">聚合链接</div>
                <div class="link-value" id="jh_link">$jh</div>
                <button class="copy-btn" onclick="copyText('jh_link')">复制链接</button>
            </div>
        </div>
EOF
    fi
    cat >> "$html_file" <<'HPROTO1'
    <div class="card">
        <div class="card-title"><span>📋</span><span>协议配置详情</span></div>
        <div class="protocol-grid">
HPROTO1
    if [ -f /etc/s-box/sb.json ] && command -v jq >/dev/null 2>&1; then
        vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port' 2>/dev/null)
        vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port' 2>/dev/null)
        hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port' 2>/dev/null)
        tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port' 2>/dev/null)
        vl_sni=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name' 2>/dev/null)
        uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid' 2>/dev/null)
        cat >> "$html_file" <<EOF
            <div class="protocol-card"><div class="protocol-name">Vless-Reality</div>
                <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$vl_port</div></div>
                <div class="info-row"><div class="info-label">SNI:</div><div class="info-value">$vl_sni</div></div>
                <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
            </div>
            <div class="protocol-card"><div class="protocol-name">Vmess-WS</div>
                <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$vm_port</div></div>
                <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
                <div class="info-row"><div class="info-label">Path:</div><div class="info-value">${uuid}-vm</div></div>
            </div>
            <div class="protocol-card"><div class="protocol-name">Hysteria-2</div>
                <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$hy2_port</div></div>
                <div class="info-row"><div class="info-label">密码:</div><div class="info-value">$uuid</div></div>
            </div>
            <div class="protocol-card"><div class="protocol-name">Tuic-v5</div>
                <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$tu5_port</div></div>
                <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
                <div class="info-row"><div class="info-label">密码:</div><div class="info-value">$uuid</div></div>
            </div>
EOF
    fi
    cat >> "$html_file" <<'HBOT'
        </div>
    </div>
    <div class="footer"><p>输出目录: __DATE_FOLDER__</p></div>
</div>
<script>
function copyText(id){var t=document.getElementById(id).textContent;navigator.clipboard.writeText(t).then(function(){alert('链接已复制到剪贴板！')}).catch(function(){var ta=document.createElement('textarea');ta.value=t;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);alert('链接已复制到剪贴板！')})}
</script></body></html>
HBOT
    sed -i "s|__DATE_FOLDER__|$DATE_FOLDER|g" "$html_file"
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

main_output() {
    mkdir -p "$OUTPUT_BASE"
    eval "$(create_date_folder)"
    generate_qr_codes
    eval "$(generate_html)"
    eval "$(update_latest)"
    echo "SUCCESS"
    echo "DATE_FOLDER=$DATE_FOLDER"
}

[ "$1" = "main" ] && main_output
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
