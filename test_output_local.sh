#!/bin/bash
# ==============================================================
# test_output_local.sh — 本地测试 HTML 生成效果
# 不需要真实的 /etc/s-box 和 root 权限，所有输出直接放在当前目录下
# ==============================================================
export LANG=en_US.UTF-8
set +e

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
MOCK_DIR="$WORKDIR/mock"
LOCAL_SBOX="$WORKDIR/test_output/s-box"
OUTPUT_BASE="$WORKDIR/test_output/output"
LOCAL_SB_OUTPUT="$LOCAL_SBOX/sb_output.sh"

yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}

echo
white "================================================================"
green "  🧪 本地测试：sb_output.sh 的 HTML 生成效果"
white "================================================================"
echo

# 1. 初始化临时目录并复制 mock 数据
echo "[1/5] 初始化测试目录..."
rm -rf "$WORKDIR/test_output" 2>/dev/null
mkdir -p "$LOCAL_SBOX" "$OUTPUT_BASE"
cp -f "$MOCK_DIR/sb.json" "$LOCAL_SBOX/sb.json"
for f in vl_reality.txt vm_ws.txt vm_ws_tls.txt hy2.txt tuic5.txt an.txt jhsub.txt; do
    [ -f "$MOCK_DIR/$f" ] && cp -f "$MOCK_DIR/$f" "$LOCAL_SBOX/$f"
done
green "  -> OK (mock 数据已复制到 $LOCAL_SBOX)"

# 2. 写出本地化的 sb_output.sh（把 OUTPUT_BASE 和 /etc/s-box 改成我们的测试目录）
echo "[2/5] 生成本地版 sb_output.sh..."
# 先从 vpn.sh 里提取真正的 sb_output.sh 段 (SBOUT_EOF 标记)，
# 再通过 sed 把路径替换成本地的
python3 - "$WORKDIR/vpn.sh" "$LOCAL_SB_OUTPUT" "$LOCAL_SBOX" "$OUTPUT_BASE" <<'PYEOF'
import sys, re
vp, out, etc_box, out_base = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(vp, 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()
# 提取 SBOUT_EOF 之间的内容
m = re.search(r'cat > "\$SB_OUTPUT_PATH" <<\x27SBOUT_EOF\x27\n(.*?)SBOUT_EOF\n', text, re.S)
if not m:
    print("FAIL: 找不到 SBOUT_EOF 段", file=sys.stderr); sys.exit(1)
body = m.group(1)
# 替换 OUTPUT_BASE="/etc/s-box/output" 以及 /etc/s-box 字面量
body = body.replace('OUTPUT_BASE="/etc/s-box/output"', f'OUTPUT_BASE="{out_base}"')
body = body.replace('/etc/s-box', etc_box)
# 同时将 main_output 调用条件改回 "[ \"$1\" = \"main\" ] && main_output" 原样保留（之前已用 main_output，没问题）
with open(out, 'w', encoding='utf-8') as f:
    f.write(body)
print("OK")
PYEOF
if [ $? -ne 0 ]; then
    red "  -> 提取 sb_output.sh 失败，改用备用方案：直接写出"
    # 直接用我们前面写好的版本
    cat > "$LOCAL_SB_OUTPUT" <<FALLBACK
#!/bin/bash
export LANG=en_US.UTF-8
OUTPUT_BASE="$OUTPUT_BASE"
DATE_FOLDER=""
create_date_folder() {
    local today max_num new_num dir num
    mkdir -p "\$OUTPUT_BASE"
    today=\$(date +%Y%m%d); max_num=0
    for dir in "\$OUTPUT_BASE"/"\$today"-*; do
        [ -d "\$dir" ] || continue
        num=\$(basename "\$dir" | sed "s/^\$today-//")
        [[ "\$num" =~ ^[0-9]+\$ ]] && [ "\$num" -gt "\$max_num" ] && max_num="\$num"
    done
    new_num=\$((max_num + 1))
    DATE_FOLDER="\$OUTPUT_BASE/\${today}-\${new_num}"
    mkdir -p "\$DATE_FOLDER"
    echo "DATE_FOLDER=\$DATE_FOLDER"
}
generate_qr_codes() {
    local base_dir="$LOCAL_SBOX"
    local files=("vl_reality.txt" "vm_ws.txt" "vm_ws_tls.txt" "vm_ws_argols.txt" "vm_ws_argogd.txt" "hy2.txt" "tuic5.txt" "an.txt" "jhsub.txt")
    local file content name
    for file in "\${files[@]}"; do
        [ -f "\$base_dir/\$file" ] || continue
        content=\$(cat "\$base_dir/\$file" 2>/dev/null)
        name="\${file%.txt}"
        [ -n "\$content" ] && echo "\$content" > "\$DATE_FOLDER/\$file"
        if command -v qrencode >/dev/null 2>&1 && [ -n "\$content" ]; then
            qrencode -o "\$DATE_FOLDER/\${name}.png" "\$content" 2>/dev/null || true
        fi
    done
}
write_html_section(){
    local html_file="\$1" name="\$2" title="\$3" txt="\$4" link id
    [ -f "\$DATE_FOLDER/\$txt" ] || return 0
    link=\$(cat "\$DATE_FOLDER/\$txt"); id="\${name//-/_}_link"
    cat >> "\$html_file" <<EOF
        <div class="card">
            <div class="card-title"><span>🔹</span><span>\$title</span></div>
            <div class="qrcode-container">
                <div class="qrcode-box"><img src="\${name}.png" alt="QR"></div>
                <div class="link-info">
                    <div class="link-label">分享链接</div>
                    <div class="link-value" id="\$id">\$link</div>
                    <button class="copy-btn" onclick="copyText('\$id')">复制链接</button>
                </div>
            </div>
        </div>
EOF
}
generate_html() {
    local html_file="\$DATE_FOLDER/index.html"
    local hostname uuid vl_port vm_port hy2_port tu5_port vl_sni jh
    hostname=\$(hostname)
    cat > "\$html_file" <<'HTOP'
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Sing-box 节点配置</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#1a1a2e 0%,#16213e 100%);min-height:100vh;padding:20px;color:#fff}
.container{max-width:1200px;margin:0 auto}.header{text-align:center;color:#fff;margin-bottom:30px}.header h1{font-size:28px;margin-bottom:10px}.header p{color:#aaa}
.card{background:#2d3436;border-radius:12px;padding:24px;margin-bottom:20px;box-shadow:0 4px 15px rgba(0,0,0,.3)}
.card-title{color:#00b894;font-size:20px;margin-bottom:20px;display:flex;align-items:center;gap:10px}.card-title span{font-size:24px}
.qrcode-container{display:flex;align-items:center;gap:30px;flex-wrap:wrap}.qrcode-box{background:#fff;padding:10px;border-radius:8px}.qrcode-box img{display:block;width:150px;height:150px}
.link-info{flex:1;min-width:300px}.link-label{color:#fdcb6e;font-size:14px;margin-bottom:8px}
.link-value{background:#1a1a2e;color:#fff;padding:12px;border-radius:8px;word-break:break-all;font-family:monospace;font-size:13px;line-height:1.6}
.copy-btn{background:#0984e3;color:#fff;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;margin-top:10px;font-size:14px}
.protocol-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px}
.protocol-card{background:#34495e;border-radius:10px;padding:20px}.protocol-name{color:#00b894;font-size:18px;margin-bottom:15px}
.info-row{display:flex;margin-bottom:10px}.info-label{color:#fdcb6e;width:100px;flex-shrink:0}.info-value{color:#fff;flex:1;word-break:break-all}
.footer{text-align:center;color:#636e72;margin-top:30px;font-size:14px}
@media(max-width:768px){.qrcode-container{flex-direction:column}.protocol-grid{grid-template-columns:1fr}}
</style></head><body><div class="container">
HTOP
    cat >> "\$html_file" <<EOF
    <div class="header"><h1>🚀 Sing-box 节点配置信息 (Mock)</h1><p>生成时间: \$(date '+%Y-%m-%d %H:%M:%S') | 主机名: \$hostname</p></div>
EOF
    write_html_section "\$html_file" "vl_reality"  "Vless-Reality-Vision" "vl_reality.txt"
    write_html_section "\$html_file" "vm_ws"        "Vmess-WS"             "vm_ws.txt"
    write_html_section "\$html_file" "vm_ws_tls"    "Vmess-WS-TLS"         "vm_ws_tls.txt"
    write_html_section "\$html_file" "hy2"          "Hysteria-2"           "hy2.txt"
    write_html_section "\$html_file" "tuic5"        "Tuic-v5"              "tuic5.txt"
    write_html_section "\$html_file" "an"           "Anytls"               "an.txt"
    if [ -f "\$DATE_FOLDER/jhsub.txt" ]; then
        jh=\$(cat "\$DATE_FOLDER/jhsub.txt")
        cat >> "\$html_file" <<EOF
        <div class="card"><div class="card-title"><span>🔹</span><span>聚合节点</span></div>
          <div class="link-info"><div class="link-label">聚合链接</div>
            <div class="link-value" id="jh_link">\$jh</div>
            <button class="copy-btn" onclick="copyText('jh_link')">复制链接</button>
          </div></div>
EOF
    fi
    cat >> "\$html_file" <<'HPROTO'
    <div class="card"><div class="card-title"><span>📋</span><span>协议配置详情</span></div><div class="protocol-grid">
HPROTO
    if [ -f "$LOCAL_SBOX/sb.json" ] && command -v jq >/dev/null 2>&1; then
        vl_port=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[0].listen_port' 2>/dev/null)
        vm_port=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[1].listen_port' 2>/dev/null)
        hy2_port=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[2].listen_port' 2>/dev/null)
        tu5_port=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[3].listen_port' 2>/dev/null)
        vl_sni=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[0].tls.server_name' 2>/dev/null)
        uuid=\$(sed 's://.*::g' "$LOCAL_SBOX/sb.json" | jq -r '.inbounds[0].users[0].uuid' 2>/dev/null)
        cat >> "\$html_file" <<EOF
            <div class="protocol-card"><div class="protocol-name">Vless-Reality</div>
              <div class="info-row"><div class="info-label">端口:</div><div class="info-value">\$vl_port</div></div>
              <div class="info-row"><div class="info-label">SNI:</div><div class="info-value">\$vl_sni</div></div>
              <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">\$uuid</div></div></div>
            <div class="protocol-card"><div class="protocol-name">Vmess-WS</div>
              <div class="info-row"><div class="info-label">端口:</div><div class="info-value">\$vm_port</div></div>
              <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">\$uuid</div></div>
              <div class="info-row"><div class="info-label">Path:</div><div class="info-value">\${uuid}-vm</div></div></div>
            <div class="protocol-card"><div class="protocol-name">Hysteria-2</div>
              <div class="info-row"><div class="info-label">端口:</div><div class="info-value">\$hy2_port</div></div>
              <div class="info-row"><div class="info-label">密码:</div><div class="info-value">\$uuid</div></div></div>
            <div class="protocol-card"><div class="protocol-name">Tuic-v5</div>
              <div class="info-row"><div class="info-label">端口:</div><div class="info-value">\$tu5_port</div></div>
              <div class="info-row"><div class="info-label">UUID:</div><div class="info-value">\$uuid</div></div>
              <div class="info-row"><div class="info-label">密码:</div><div class="info-value">\$uuid</div></div></div>
EOF
    fi
    cat >> "\$html_file" <<'HBOT'
        </div></div>
    <div class="footer"><p>输出目录: __DATE_FOLDER__</p></div>
</div>
<script>function copyText(id){var t=document.getElementById(id).textContent;navigator.clipboard.writeText(t).then(function(){alert('已复制！')}).catch(function(){var ta=document.createElement('textarea');ta.value=t;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);alert('已复制！')})}</script>
</body></html>
HBOT
    sed -i "s|__DATE_FOLDER__|\$DATE_FOLDER|g" "\$html_file"
    echo "HTML_FILE=\$html_file"
}
update_latest() {
    local latest
    latest=\$(ls -1d "\$OUTPUT_BASE"/*/ 2>/dev/null | grep -v '/latest/' | sort | tail -n1 | sed 's|/\$||')
    if [ -n "\$latest" ]; then ln -sfn "\$latest" "\$OUTPUT_BASE/latest"; echo "LATEST=\$OUTPUT_BASE/latest"; fi
}
main_output(){
    mkdir -p "\$OUTPUT_BASE"
    eval "\$(create_date_folder)"
    generate_qr_codes
    eval "\$(generate_html)"
    eval "\$(update_latest)"
    echo "SUCCESS"; echo "DATE_FOLDER=\$DATE_FOLDER"
}
[ "\$1" = "main" ] && main_output
FALLBACK
fi
chmod +x "$LOCAL_SB_OUTPUT"
green "  -> OK ($LOCAL_SB_OUTPUT)"

# 3. 运行
echo "[3/5] 运行 sb_output.sh main 生成 HTML..."
res=$(bash "$LOCAL_SB_OUTPUT" main 2>&1)
echo "$res"
if echo "$res" | grep -q "SUCCESS"; then
    green "  -> 运行成功"
else
    red "  -> 警告：未检测到 SUCCESS（可能是 mock 数据不完整或 shell 环境差异），仍尝试找输出..."
fi

# 4. 校验输出
echo "[4/5] 校验结果..."
LATEST_DIR=""
if [ -L "$OUTPUT_BASE/latest" ]; then
    LATEST_DIR=$(readlink -f "$OUTPUT_BASE/latest" 2>/dev/null)
else
    LATEST_DIR=$(ls -1d "$OUTPUT_BASE"/*/ 2>/dev/null | sort | tail -n1 | sed 's|/$||')
fi
if [ -z "$LATEST_DIR" ] || [ ! -d "$LATEST_DIR" ]; then
    red "  -> 找不到输出目录"
    exit 1
fi
green "  -> 最新目录: $LATEST_DIR"
[ -f "$LATEST_DIR/index.html" ] && green "  -> index.html: 存在 ($(wc -l < "$LATEST_DIR/index.html") 行, $(wc -c < "$LATEST_DIR/index.html") 字节)" || red "  -> index.html: 缺失"
for f in vl_reality.txt vm_ws.txt vm_ws_tls.txt hy2.txt tuic5.txt an.txt jhsub.txt; do
    [ -f "$LATEST_DIR/$f" ] && s="✓" || s="✗"
    echo "     $s $f"
done
[ -f "$LATEST_DIR/vl_reality.png" ] && green "  -> 二维码已生成 (qrencode OK)" || yellow "  -> 未生成二维码图片 (当前环境无 qrencode，属正常现象)"

# 5. 尝试打开 index.html
echo "[5/5] 打开 index.html..."
HTML_FILE="$LATEST_DIR/index.html"
case "$(uname -s)" in
    Linux*|WSL*)
        if command -v explorer.exe >/dev/null 2>&1; then
            # WSL 转换路径并用 Windows 默认浏览器打开
            WIN_PATH=$(wslpath -w "$HTML_FILE" 2>/dev/null)
            [ -n "$WIN_PATH" ] && explorer.exe "$WIN_PATH" 2>/dev/null || xdg-open "$HTML_FILE" 2>/dev/null || true
        else
            xdg-open "$HTML_FILE" 2>/dev/null || true
        fi ;;
    Darwin*) open "$HTML_FILE" 2>/dev/null || true ;;
    MINGW*|CYGWIN*|MSYS*) start "" "$HTML_FILE" 2>/dev/null || true ;;
    *) : ;;
esac

echo
white "================================================================"
green "  ✅ 测试完成！"
blue "  HTML 路径：$HTML_FILE"
blue "  latest 软链：$OUTPUT_BASE/latest -> $LATEST_DIR"
yellow "  在浏览器打开上面的 HTML 路径，即可查看页面效果"
white "================================================================"
echo
# 如果能检测到是 Windows + 非 Git Bash，我们用 PowerShell 打开
if command -v powershell.exe >/dev/null 2>&1; then
    PS_PATH=$(cygpath -w "$HTML_FILE" 2>/dev/null || echo "$HTML_FILE")
    powershell.exe -NoProfile -Command "Start-Process '$PS_PATH'" >/dev/null 2>&1 || true
fi
