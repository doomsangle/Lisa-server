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

generate_html() {
    local html_file="$DATE_FOLDER/index.html"
    local hostname=$(hostname)
    
    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sing-box 配置信息 - $(date +%Y-%m-%d %H:%M:%S)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; color: #fff; margin-bottom: 30px; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header p { color: #aaa; }
        .card { background: #2d3436; border-radius: 12px; padding: 24px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }
        .card-title { color: #00b894; font-size: 20px; margin-bottom: 20px; display: flex; align-items: center; gap: 10px; }
        .card-title span { font-size: 24px; }
        .qrcode-container { display: flex; align-items: center; gap: 30px; flex-wrap: wrap; }
        .qrcode-box { background: #fff; padding: 10px; border-radius: 8px; }
        .qrcode-box img { display: block; width: 150px; height: 150px; }
        .link-info { flex: 1; min-width: 300px; }
        .link-label { color: #fdcb6e; font-size: 14px; margin-bottom: 8px; }
        .link-value { background: #1a1a2e; color: #fff; padding: 12px; border-radius: 8px; word-break: break-all; font-family: monospace; font-size: 13px; line-height: 1.6; }
        .copy-btn { background: #0984e3; color: #fff; border: none; padding: 8px 16px; border-radius: 6px; cursor: pointer; margin-top: 10px; font-size: 14px; }
        .copy-btn:hover { background: #74b9ff; }
        .protocol-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; }
        .protocol-card { background: #34495e; border-radius: 10px; padding: 20px; }
        .protocol-name { color: #00b894; font-size: 18px; margin-bottom: 15px; }
        .info-row { display: flex; margin-bottom: 10px; }
        .info-label { color: #fdcb6e; width: 100px; flex-shrink: 0; }
        .info-value { color: #fff; flex: 1; word-break: break-all; }
        .footer { text-align: center; color: #636e72; margin-top: 30px; font-size: 14px; }
        @media (max-width: 768px) {
            .qrcode-container { flex-direction: column; }
            .protocol-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Sing-box 节点配置信息</h1>
            <p>生成时间: $(date +%Y-%m-%d %H:%M:%S) | 主机名: $hostname</p>
        </div>
EOF

    if [ -f "$DATE_FOLDER/vl_reality.txt" ]; then
        local vl_link=$(cat "$DATE_FOLDER/vl_reality.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Vless-Reality-Vision</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="vl_reality.png" alt="Vless-Reality QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vl-link">$vl_link</div>
                    <button class="copy-btn" onclick="copyText('vl-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/vm_ws.txt" ]; then
        local vm_link=$(cat "$DATE_FOLDER/vm_ws.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Vmess-WS</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="vm_ws.png" alt="Vmess-WS QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-link">$vm_link</div>
                    <button class="copy-btn" onclick="copyText('vm-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/vm_ws_tls.txt" ]; then
        local vm_tls_link=$(cat "$DATE_FOLDER/vm_ws_tls.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Vmess-WS-TLS</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="vm_ws_tls.png" alt="Vmess-WS-TLS QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-tls-link">$vm_tls_link</div>
                    <button class="copy-btn" onclick="copyText('vm-tls-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/vm_ws_argols.txt" ]; then
        local vm_argo_link=$(cat "$DATE_FOLDER/vm_ws_argols.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Vmess-WS + Argo 临时</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="vm_ws_argols.png" alt="Vmess-WS-Argo QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-argo-link">$vm_argo_link</div>
                    <button class="copy-btn" onclick="copyText('vm-argo-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/vm_ws_argogd.txt" ]; then
        local vm_argo_gd_link=$(cat "$DATE_FOLDER/vm_ws_argogd.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Vmess-WS + Argo 固定</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="vm_ws_argogd.png" alt="Vmess-WS-Argo-Fixed QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="vm-argo-gd-link">$vm_argo_gd_link</div>
                    <button class="copy-btn" onclick="copyText('vm-argo-gd-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/hy2.txt" ]; then
        local hy2_link=$(cat "$DATE_FOLDER/hy2.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Hysteria-2</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="hy2.png" alt="Hysteria-2 QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="hy2-link">$hy2_link</div>
                    <button class="copy-btn" onclick="copyText('hy2-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/tuic5.txt" ]; then
        local tu5_link=$(cat "$DATE_FOLDER/tuic5.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Tuic-v5</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="tuic5.png" alt="Tuic-v5 QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="tu5-link">$tu5_link</div>
                    <button class="copy-btn" onclick="copyText('tu5-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/an.txt" ]; then
        local an_link=$(cat "$DATE_FOLDER/an.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>Anytls</span>
            </div>
            <div class="qrcode-container">
                <div class="qrcode-box">
                    <img src="an.png" alt="Anytls QR Code">
                </div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="an-link">$an_link</div>
                    <button class="copy-btn" onclick="copyText('an-link')">复制链接</button>
                </div>
            </div>
        </div>
EOF
    fi

    if [ -f "$DATE_FOLDER/jhsub.txt" ]; then
        local jh_link=$(cat "$DATE_FOLDER/jhsub.txt")
        cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>🔹</span>
                <span>聚合节点</span>
            </div>
            <div class="link-info">
                <div class="link-label">聚合链接</div>
                <div class="link-value" id="jh-link">$jh_link</div>
                <button class="copy-btn" onclick="copyText('jh-link')">复制链接</button>
            </div>
        </div>
EOF
    fi

    cat >> "$html_file" <<EOF
        <div class="card">
            <div class="card-title">
                <span>📋</span>
                <span>协议配置详情</span>
            </div>
            <div class="protocol-grid">
EOF

    if [ -f /etc/s-box/sb.json ]; then
        local vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
        local vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
        local hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
        local tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
        local vl_sni=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
        local uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')

        cat >> "$html_file" <<EOF
                <div class="protocol-card">
                    <div class="protocol-name">Vless-Reality</div>
                    <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$vl_port</div></div>
                    <div class="info-row"><div class="info-label">SNI:</div><div class="info-value">$vl_sni</div></div>
                    <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Vmess-WS</div>
                    <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$vm_port</div></div>
                    <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">Path:</div><div class="info-value">${uuid}-vm</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Hysteria-2</div>
                    <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$hy2_port</div></div>
                    <div class="info-row"><div class="info-label">密码:</div><div class="info-value">$uuid</div></div>
                </div>
                <div class="protocol-card">
                    <div class="protocol-name">Tuic-v5</div>
                    <div class="info-row"><div class="info-label">端口:</div><div class="info-value">$tu5_port</div></div>
                    <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">$uuid</div></div>
                    <div class="info-row"><div class="info-label">密码:</div><div class="info-value">$uuid</div></div>
                </div>
EOF
    fi

    cat >> "$html_file" <<EOF
            </div>
        </div>

        <div class="footer">
            <p>输出目录: $DATE_FOLDER</p>
        </div>
    </div>
    <script>
        function copyText(id) {
            const text = document.getElementById(id).textContent;
            navigator.clipboard.writeText(text).then(() => {
                alert('链接已复制到剪贴板！');
            }).catch(err => {
                const textarea = document.createElement('textarea');
                textarea.value = text;
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
                alert('链接已复制到剪贴板！');
            });
        }
    </script>
</body>
</html>
EOF
    echo "HTML_FILE=$html_file"
}

main() {
    eval $(create_date_folder)
    generate_qr_codes
    eval $(generate_html)
    echo "SUCCESS"
    echo "输出目录: $DATE_FOLDER"
    echo "HTML文件: $html_file"
}

if [ "$1" = "main" ]; then
    main
fi
