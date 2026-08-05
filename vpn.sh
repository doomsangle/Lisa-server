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


readp(){
    if [ -t 0 ]; then
        read -p "$(yellow "$1")" $2
    else
        local _varname="$2"
        if [ -n "$_varname" ]; then
            eval "$_varname=''"
        fi
        read -t 1 -r -p "$(yellow "$1")" $2 2>/dev/null || true
    fi
}


[[ $EUID -ne 0 ]] && { red "请以 root 身份运行此脚本 (sudo -i)"; exit 1; }


# =====================================================
# Sing-box 核心函数（已从 sb.sh 内联合并，无需外部文件）
# 来源：https://github.com/yonggekkk/sing-box-yg
# =====================================================
v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
v4dq=$(curl -s4m5 -k https://myip.ipip.net | awk -F'来自于：' '{print $2}' 2>/dev/null)
#v4dq=$(curl -s4m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
v6dq=$(curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
}
warpcheck(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

v6(){
v4orv6(){
if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
echo
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow "检测到 纯IPV6 VPS，添加NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
ipv=prefer_ipv6
else
ipv=prefer_ipv4
fi
if [ -n "$(curl -s6m5 icanhazip.com -k)" ]; then
endip="2606:4700:d0::a29f:c001"
else
endip="162.159.192.1"
fi
}
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4orv6
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4orv6
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

close(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
sleep 1
green "执行开放端口，关闭防火墙完毕"
}

openyn(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
readp "是否开放端口，关闭防火墙？\n1、是，执行 (回车默认)\n2、否，跳过！自行处理\n请选择【1-2】：" action
if [[ -z $action ]] || [[ "$action" = "1" ]]; then
close
elif [[ "$action" = "2" ]]; then
echo
else
red "输入错误,请重新选择" && openyn
fi
}

inssb(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "使用哪个内核版本？"
yellow "1：使用目前最新正式版内核 (回车默认)"
yellow "2：使用之前1.10.7正式版内核 (支持geosite分流、IP优选级切换，无Anytls协议)"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
else
sbcore='1.10.7'
fi
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
blue "成功安装 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
else
red "下载 Sing-box 内核不完整，安装失败，请再运行安装一次" && exit
fi
else
red "下载 Sing-box 内核失败，请再运行安装一次，并检测VPS的网络是否可以访问Github" && exit
fi
}

inscertificate(){
ymzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality的SNI域名默认为 apple.com"
tlsyn=true
ym_vm_ws=$(cat /root/ygkkkca/ca.log 2>/dev/null)
certificatec_vmess_ws='/root/ygkkkca/cert.crt'
certificatep_vmess_ws='/root/ygkkkca/private.key'
certificatec_hy2='/root/ygkkkca/cert.crt'
certificatep_hy2='/root/ygkkkca/private.key'
certificatec_tuic='/root/ygkkkca/cert.crt'
certificatep_tuic='/root/ygkkkca/private.key'
certificatec_an='/root/ygkkkca/cert.crt'
certificatep_an='/root/ygkkkca/private.key'
}

zqzs(){
ym_vl_re=apple.com
echo
blue "Vless-reality的SNI域名默认为 apple.com"
tlsyn=false
ym_vm_ws=www.bing.com
certificatec_vmess_ws='/etc/s-box/cert.pem'
certificatep_vmess_ws='/etc/s-box/private.key'
certificatec_hy2='/etc/s-box/cert.pem'
certificatep_hy2='/etc/s-box/private.key'
certificatec_tuic='/etc/s-box/cert.pem'
certificatep_tuic='/etc/s-box/private.key'
certificatec_an='/etc/s-box/cert.pem'
certificatep_an='/etc/s-box/private.key'
}

red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "二、生成并设置相关证书"
echo
blue "自动生成bing自签证书中……" && sleep 2
openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem -subj "/CN=www.bing.com"
echo
if [[ -f /etc/s-box/cert.pem ]]; then
blue "生成bing自签证书成功"
else
red "生成bing自签证书失败" && exit
fi
echo
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
yellow "经检测，之前已使用Acme-yg脚本申请过Acme域名IP证书：$(cat /root/ygkkkca/ca.log) "
green "是否使用 $(cat /root/ygkkkca/ca.log) 域名IP证书？"
yellow "1：否！使用自签的证书 (回车默认)"
yellow "2：是！使用 $(cat /root/ygkkkca/ca.log) 域名IP证书"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
ymzs
fi
else
green "是否申请一个Acme域名IP证书？"
yellow "1：否！继续使用自签的证书 (回车默认)"
yellow "2：是！使用Acme-yg脚本申请Acme证书 (支持80端口域名IP证书模式与Dns API域名模式)"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key && ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Acme证书申请失败，继续使用自签证书" 
zqzs
else
ymzs
fi
fi
fi
}

chooseport(){
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
blue "确认的端口：$port" && sleep 2
}

vlport(){
readp "\n设置Vless-reality端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_vl_re=$port
}
vmport(){
readp "\n设置Vmess-ws端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_vm_ws=$port
}
hy2port(){
readp "\n设置Hysteria2主端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_hy2=$port
}
tu5port(){
readp "\n设置Tuic5主端口 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_tu=$port
}
anport(){
readp "\n设置Anytls主端口，最新内核时可用 (回车跳过为10000-65535之间的随机端口)：" port
chooseport
port_an=$port
}

insport(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "三、设置各个协议端口"
yellow "1：自动生成每个协议的随机端口 (10000-65535范围内)，回车默认。请确保VPS后台已开放所有端口"
yellow "2：自定义每个协议端口。请确保VPS后台已开放指定的端口"
readp "请输入【1-2】：" port
if [ -z "$port" ] || [ "$port" = "1" ] ; then
ports=()
for i in {1..5}; do
while true; do
port=$(shuf -i 10000-65535 -n 1)
if ! [[ " ${ports[@]} " =~ " $port " ]] && \
[[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
[[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
ports+=($port)
break
fi
done
done
port_vm_ws=${ports[0]}
port_vl_re=${ports[1]}
port_hy2=${ports[2]}
port_tu=${ports[3]}
port_an=${ports[4]}
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
until [[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port_vm_ws") ]]
do
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
done
echo
blue "根据Vmess-ws协议是否启用TLS，随机指定支持CDN优选IP的标准端口：$port_vm_ws"
else
vlport && vmport && hy2port && tu5port
if [[ "$sbnh" != "1.10" ]]; then
anport
fi
fi
echo
blue "各协议端口确认如下"
blue "Vless-reality端口：$port_vl_re"
blue "Vmess-ws端口：$port_vm_ws"
blue "Hysteria-2端口：$port_hy2"
blue "Tuic-v5端口：$port_tu"
if [[ "$sbnh" != "1.10" ]]; then
blue "Anytls端口：$port_an"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "四、自动生成各个协议统一的uuid (密码)"
uuid=$(/etc/s-box/sing-box generate uuid)
blue "已确认uuid (密码)：${uuid}"
blue "已确认Vmess的path路径：${uuid}-vm"
}

inssbjsonser(){
cat > /etc/s-box/sb10.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",
            "sniff": true,
            "sniff_override_destination": true,
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        }
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag": "vps-outbound-v4", 
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag": "vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
},
{
"type":"direct",
"tag":"socks-IPv4-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"socks-IPv6-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"direct",
"tag":"warp-IPv4-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"warp-IPv6-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"wireguard",
"tag":"wireguard-out",
"server":"$endip",
"server_port":2408,
"local_address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"reserved":$res
},
{
"type": "block",
"tag": "block"
}
],
"route":{
"rules":[
{
"protocol": [
"quic",
"stun"
],
"outbound": "block"
},
{
"outbound":"warp-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"warp-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v4",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v6",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF

cat > /etc/s-box/sb11.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",

      
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",

 
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",

 
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",

     
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        },
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$certificatec_an",
                "key_path": "$certificatep_an"
            }
        }
],
"endpoints":[
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peers": [
{
"address": "$endip",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips": [
"0.0.0.0/0",
"::/0"
],
"reserved":$res
}
]
}
],









"outbounds": [
{
"type":"direct",
"tag":"direct"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
}
],
"route":{
"rules":[
{
 "action": "sniff"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"socks-out"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"warp-out"
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
}

sbservice(){
if command -v apk >/dev/null 2>&1; then
echo '#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box/sing-box"
command_args="run -c /etc/s-box/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"' > /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl start sing-box
systemctl restart sing-box
fi
}

ipuuid(){
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "调整IPv4/IPV6配置输出"
yellow "1：刷新本地IP，使用IPV4配置输出 (回车默认) "
yellow "2：刷新本地IP，使用IPV6配置输出"
readp "请选择【1-2】：" menu
if [ -z "$menu" ] || [ "$menu" = "1" ]; then
server_ip="$v4"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v4"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="[$v6]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v6"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
else
yellow "VPS并不是双栈VPS，不支持IP配置输出的切换"
serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
if [[ "$serip" =~ : ]]; then
server_ip="[$serip]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="$serip"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
fi
else
red "Sing-box服务未运行" && exit
fi
}

wgcfgo(){
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ipuuid
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ipuuid
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

result_vl_vm_hy_tu(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
fi
rm -rf /etc/s-box/vm_ws_argo.txt /etc/s-box/vm_ws.txt /etc/s-box/vm_ws_tls.txt
server_ip=$(cat /etc/s-box/server_ip.log)
server_ipcl=$(cat /etc/s-box/server_ipcl.log)
uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vl_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
public_key=$(cat /etc/s-box/public.key)
short_id=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.short_id[0]')
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
ws_path=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
if [[ -f /etc/s-box/cfvmadd_local.txt ]]; then
vmadd_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
vmadd_are_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
else
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
fi
if [[ -f /etc/s-box/cfvmadd_argo.txt ]]; then
vmadd_argo=$(cat /etc/s-box/cfvmadd_argo.txt 2>/dev/null)
else
vmadd_argo=cloudflare-ech.com
fi
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
if [[ -n $hy2_ports ]]; then
cmhy2pt=$(echo $hy2_ports | tr ':' '-')
hyps="&mport=$cmhy2pt"
sbhy2pt=$(echo "$hy2_ports" | grep -o '[0-9]\+:[0-9]\+' | sed 's/.*/"&"/' | paste -sd,)
else
hyps=
fi
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [[ "$hy2_sniname" = '/etc/s-box/private.key' ]]; then
SHA256=$(openssl x509 -in /etc/s-box/cert.pem -outform DER | sha256sum | awk '{print $1}')
echo "$SHA256" > /etc/s-box/SHA256.txt
SHA256=$(cat /etc/s-box/SHA256.txt)
hy2_name=www.bing.com
sb_hy2_ip=$server_ip
cl_hy2_ip=$server_ipcl
ins_hy2=1
hy2_ins=true
else
hy2_name=$ym
sb_hy2_ip=$ym
cl_hy2_ip=$ym
ins_hy2=0
hy2_ins=false
fi
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [[ "$tu5_sniname" = '/etc/s-box/private.key' ]]; then
tu5_name=www.bing.com
sb_tu5_ip=$server_ip
cl_tu5_ip=$server_ipcl
ins=1
tu5_ins=true
else
tu5_name=$ym
sb_tu5_ip=$ym
cl_tu5_ip=$ym
ins=0
tu5_ins=false
fi
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [[ "$an_sniname" = '/etc/s-box/private.key' ]]; then
an_name=www.bing.com
sb_an_ip=$server_ip
cl_an_ip=$server_ipcl
ins_an=1
an_ins=true
else
an_name=$ym
sb_an_ip=$ym
cl_an_ip=$ym
ins_an=0
an_ins=false
fi
}

resvless(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vl_link="vless://$uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo "$vl_link" > /etc/s-box/vl_reality.txt
red "🚀【 vless-reality-vision 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$vl_link${plain}"
echo
echo "二维码【v2ran(切换singbox内核)、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vl_reality.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resvmess(){
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】临时节点信息如下(可选择3-8-3，自定义CDN优选地址)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argols.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argols.txt)"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
argogd=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo 】固定节点信息如下 (可选择3-8-3，自定义CDN优选地址)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argogd.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argogd.txt)"
fi
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws 】节点信息如下 (建议选择3-8-1，设置为CDN优选节点)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws.txt)"
else
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws-tls 】节点信息如下 (建议选择3-8-1，设置为CDN优选节点)：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_tls.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_tls.txt)"
fi
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

reshy2(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=0&allowInsecure=0$hyps&sni=$hy2_name&pinSHA256=$SHA256#hy2-$hostname"
#hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&allowInsecure=$ins_hy2$hyps&sni=$hy2_name#hy2-$hostname"
echo "$hy2_link" > /etc/s-box/hy2.txt
red "🚀【 Hysteria-2 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$hy2_link${plain}"
echo
echo "二维码【v2rayn、v2rayng、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/hy2.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

restu5(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
tuic5_link="tuic://$uuid:$uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&insecure=$ins&allowInsecure=$ins&allow_insecure=$ins#tu5-$hostname"
echo "$tuic5_link" > /etc/s-box/tuic5.txt
red "🚀【 Tuic-v5 】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、nekobox、小火箭shadowrocket】"
echo -e "${yellow}$tuic5_link${plain}"
echo
echo "二维码【v2rayn、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/tuic5.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resan(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
an_link="anytls://$uuid@$sb_an_ip:$an_port?&sni=$an_name&allowInsecure=$ins_an&insecure=$ins_an#anytls-$hostname"
echo "$an_link" > /etc/s-box/an.txt
red "🚀【 Anytls】节点信息如下：" && sleep 2
echo
echo "分享链接【v2rayn、小火箭shadowrocket】"
echo -e "${yellow}$an_link${plain}"
echo
echo "二维码【v2rayn、nekobox、小火箭shadowrocket】"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/an.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

sb_client(){

sbhy2ports(){
if [[ -n $hy2_ports ]]; then
    cat <<EOF
  "server_ports": [ $sbhy2pt ],
EOF
fi
}

sbany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "\"anytls-$hostname\","
  fi
}
clany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "- anytls-$hostname"
  fi
}
sbany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
         {
            "type": "anytls",
            "tag": "anytls-$hostname",
            "server": "$sb_an_ip",
            "server_port": $an_port,
            "password": "$uuid",
            "idle_session_check_interval": "30s",
            "idle_session_timeout": "30s",
            "min_idle_session": 5,
            "tls": {
                "enabled": true,
                "insecure": $an_ins,
                "server_name": "$an_name"
            }
         },
EOF
  fi
}
clany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
- name: anytls-$hostname
  type: anytls
  server: $cl_an_ip
  port: $an_port
  password: $uuid
  client-fingerprint: chrome
  udp: true
  idle-session-check-interval: 30
  idle-session-timeout: 30
  sni: $an_name
  skip-cert-verify: $an_ins
EOF
  fi
}

sball(){
cat <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "./cache.db",
            "store_fakeip": true
        },
        "clash_api": {
            "external_controller": "127.0.0.1:9090",
            "external_ui": "ui",
            "default_mode": "Rule"
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "aliDns",
                "type": "https",
                "server": "dns.alidns.com",
                "path": "/dns-query",
                "domain_resolver": "local"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "223.5.5.5"
            },
            {
                "tag": "proxyDns",
                "type": "https",
                "server": "dns.google",
                "path": "/dns-query",
	            "domain_resolver": "aliDns",
                "detour": "proxy"
            },
           {
        "type": "fakeip",
        "tag": "fakeip",
        "inet4_range": "198.18.0.0/15",
        "inet6_range": "fc00::/18"
      }
        ],
        "rules": [
            {
                "rule_set": "geosite-cn",
                "clash_mode": "Rule",
                "server": "aliDns"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "clash_mode": "Global",
                "server": "proxyDns"
            },
            {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "fakeip"
      }
        ],
        "final": "proxyDns",
        "strategy": "prefer_ipv4"
    },
	  "http_clients": [
    {
      "tag": "http-client-direct"
    }
    ],
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "address": [
                "172.19.0.1/30",
                "fd00::1/126"
            ],
            "auto_route": true,
            "strict_route": true
        }
    ],
    "route": {
        "rules": [
            {
	           "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 53
                    },
                    {
                        "protocol": "dns"
                    }
                ],
                "action": "hijack-dns"
            },
         {
          "clash_mode": "Global",
          "outbound": "proxy"
         },
        {
        "rule_set": "geosite-cn",
        "clash_mode": "Rule",
        "outbound": "direct"
       },
     {
    "rule_set": "geoip-cn",
    "clash_mode": "Rule",
    "outbound": "direct"
      },
     {
    "ip_is_private": true,
    "clash_mode": "Rule",
    "outbound": "direct"
    },
     {
      "clash_mode": "Direct",
      "outbound": "direct"
     }		
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs"
            }
        ],
        "final": "proxy",
        "default_http_client": "http-client-direct",
        "auto_detect_interface": true,
        "default_domain_resolver": {
            "server": "aliDns"
        }
    },
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
$(sbhy2ports)
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
EOF
}

clall(){
cat <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
dns:
  enable: true 
  listen: "0.0.0.0:1053"
  ipv6: true
  prefer-h3: false
  respect-rules: true
  use-system-hosts: false
  cache-algorithm: "arc"
  enhanced-mode: "fake-ip"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "+.lan"
    - "+.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
    - "+.in-addr.arpa"
    - "+.ip6.arpa"
    - "time.*.com"
    - "time.*.gov"
    - "pool.ntp.org"
    - "localhost.work.weixin.qq.com"
  default-nameserver: ["223.5.5.5", "119.29.29.29"]
  nameserver:
    - "https://1.1.1.1/dns-query"
    - "https://8.8.8.8/dns-query"
  proxy-server-nameserver:
    - "https://223.5.5.5/dns-query"
    - "https://doh.pub/dns-query"

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port
  ports: $cmhy2pt
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: $tu5_ins
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins
EOF
}

tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 443,
            "tag": "vmess-tls-argo固定-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo固定-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 443,
            "tag": "vmess-tls-argo临时-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo临时-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname",
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname",
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

- name: vmess-tls-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd


- name: vmess-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-tls-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOSITE,CN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

elif ! ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 443,
            "tag": "vmess-tls-argo临时-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo临时-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo临时-$hostname",
        "vmess-argo临时-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)








$(clany2)

- name: vmess-tls-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo临时-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo临时-$hostname
    - vmess-argo临时-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOSITE,CN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

elif ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ! ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 443,
            "tag": "vmess-tls-argo固定-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo固定-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
$(sbany1)
        "vmess-tls-argo固定-$hostname",
        "vmess-argo固定-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)






$(clany2)

- name: vmess-tls-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-argo固定-$hostname                         
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    - vmess-tls-argo固定-$hostname
    - vmess-argo固定-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOSITE,CN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

else
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)

- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
rules:
  - GEOIP,LAN,DIRECT
  - GEOSITE,CN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF
fi
}

cfargo_ym(){
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
echo
yellow "1：添加或者删除Argo临时隧道"
yellow "2：添加或者删除Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
cfargo
elif [ "$menu" = "2" ]; then
cfargoym
else
changeserv
fi
else
yellow "因vmess开启了tls，Argo隧道功能不可用" && sleep 2
fi
}

cloudflaredargo(){
if [ ! -e /etc/s-box/cloudflared ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
#curl -L -o /etc/s-box/cloudflared -# --retry 2 https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/$cpu
chmod +x /etc/s-box/cloudflared
fi
}

cfargoym(){
echo
if [[ -f /etc/s-box/sbargotoken.log && -f /etc/s-box/sbargoym.log ]]; then
green "当前Argo固定隧道域名：$(cat /etc/s-box/sbargoym.log 2>/dev/null)"
green "当前Argo固定隧道Token：$(cat /etc/s-box/sbargotoken.log 2>/dev/null)"
fi
echo
green "请进入Cloudflare官网 --- Zero Trust --- 网络 --- 连接器，创建固定隧道"
yellow "1：重置/设置Argo固定隧道域名"
yellow "2：停止Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
cloudflaredargo
readp "输入Argo固定隧道Token: " argotoken
readp "输入Argo固定隧道域名: " argoym
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
echo
yellow "注意！Zero Trust设置固定隧道URL端口填写Vmess端口：localhost:$vm_port"
echo
pid=$(ps -ef 2>/dev/null | awk '/[c]loudflared.*run/ {print $2}')
[ -n "$pid" ] && kill -9 "$pid" >/dev/null 2>&1
echo
if [[ -n "${argotoken}" && -n "${argoym}" ]]; then
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/etc/s-box/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${argotoken}"
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable argo >/dev/null 2>&1
systemctl start argo >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="/etc/s-box/cloudflared tunnel"
command_args="--no-autoupdate --edge-ip-version auto --protocol http2 run --token ${argotoken}"
pidfile="/run/argo.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/argo >/dev/null 2>&1
rc-update add argo default >/dev/null 2>&1
rc-service argo start >/dev/null 2>&1
fi
fi
echo ${argoym} > /etc/s-box/sbargoym.log
echo ${argotoken} > /etc/s-box/sbargotoken.log
argosh=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
sbshare > /dev/null 2>&1
blue "Argo固定隧道设置完成，固定域名：$argosh"
elif [ "$menu" = "2" ]; then
if pidof systemd >/dev/null 2>&1; then
systemctl stop argo >/dev/null 2>&1
systemctl disable argo >/dev/null 2>&1
rm -rf /etc/systemd/system/argo.service
elif command -v rc-service >/dev/null 2>&1; then
rc-service argo stop >/dev/null 2>&1
rc-update del argo default >/dev/null 2>&1
rm -rf /etc/init.d/argo
fi
rm -rf /etc/s-box/vm_ws_argogd.txt
sbshare > /dev/null 2>&1
green "Argo固定隧道已停止"
else
cfargo_ym
fi
}

cfargo(){
echo
yellow "1：重置Argo临时隧道域名"
yellow "2：停止Argo临时隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
green "请稍等……"
cloudflaredargo
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 20
if [[ -n $(curl -sL https://$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')/ -I | awk 'NR==1 && /404|400|503/') ]]; then
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
sbshare > /dev/null 2>&1
blue "Argo临时隧道申请成功，域名验证有效：$argo" && sleep 2
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpineargo.start <<'EOF'
#!/bin/bash
sleep 10
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 10
printf "9\n1\n" | bash /usr/bin/sb > /dev/null 2>&1
EOF
chmod +x /etc/local.d/alpineargo.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 & sleep 10 && printf \"9\n1\n\" | bash /usr/bin/sb > /dev/null 2>&1"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
else
yellow "Argo临时域名验证暂不可用，请稍后再试"
fi
elif [ "$menu" = "2" ]; then
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/s-box/vm_ws_argols.txt
rm -rf /etc/local.d/alpineargo.start
sbshare > /dev/null 2>&1
green "Argo临时隧道已停止"
else
cfargo_ym
fi
}

instsllsingbox(){
if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
red "已安装Sing-box服务，无法再次安装" && exit
fi
mkdir -p /etc/s-box
v6
openyn
inssb
inscertificate
insport
sleep 2
echo
blue "Vless-reality相关key与id将自动生成……"
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
echo "$public_key" > /etc/s-box/public.key
short_id=$(/etc/s-box/sing-box generate rand --hex 4)
wget -q -O /root/geoip.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db
wget -q -O /root/geosite.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "五、自动生成warp-wireguard出站账户" && sleep 2
warpwg
inssbjsonser
sbservice
sbactive
#curl -sL https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/version/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
lnsb && blue "Sing-box-yg脚本安装成功，脚本快捷方式：sb" && cronsb
echo
wgcfgo
sbshare
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
blue "可选择9，刷新并显示所有协议配置及分享链接"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

changeym(){
[ -f /root/ygkkkca/ca.log ] && ymzs="$yellow切换为域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)$plain" || ymzs="$yellow未申请域名证书，无法切换$plain"
vl_na="正在使用的域名：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')。$yellow更换符合reality要求的域名，不支持证书域名$plain"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[[ "$tls" = "false" ]] && vm_na="当前已关闭TLS。$ymzs ${yellow}将开启TLS，Argo隧道将不支持开启${plain}" || vm_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为关闭TLS，Argo隧道将可用$plain"
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_na="正在使用自签bing证书。$ymzs" || hy2_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_na="正在使用自签bing证书。$ymzs" || tu5_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_na="正在使用自签bing证书。$ymzs" || an_na="正在使用的域名证书：$(cat /root/ygkkkca/ca.log 2>/dev/null)。$yellow切换为自签bing证书$plain"
echo
green "请选择要切换证书模式的协议"
green "1：vless-reality协议，$vl_na"
if [[ -f /root/ygkkkca/ca.log ]]; then
green "2：vmess-ws协议，$vm_na"
green "3：Hysteria2协议，$hy2_na"
green "4：Tuic5协议，$tu5_na"
if [[ "$sbnh" != "1.10" ]]; then
green "5：Anytls协议，$an_na"
fi
else
red "仅支持选项1 (vless-reality)。因未申请域名证书，vmess-ws、Hysteria-2、Tuic-v5、Anytls的证书切换选项暂不予显示"
fi
green "0：返回上层"
readp "请选择：" menu
if [ "$menu" = "1" ]; then
readp "请输入vless-reality域名 (回车使用apple.com)：" menu
ym_vl_re=${menu:-apple.com}
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.handshake.server')
c=$(cat /etc/s-box/vl_reality.txt | cut -d'=' -f5 | cut -d'&' -f1)
echo $sbfiles | xargs -n1 sed -i "23s/$a/$ym_vl_re/"
echo $sbfiles | xargs -n1 sed -i "27s/$b/$ym_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality域名证书更换完毕"
elif [ "$menu" = "2" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[ "$a" = "true" ] && a_a=false || a_a=true
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
[ "$b" = "www.bing.com" ] && b_b=$(cat /root/ygkkkca/ca.log) || b_b=$(cat /root/ygkkkca/ca.log)
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "55s#$a#$a_a#"
echo $sbfiles | xargs -n1 sed -i "56s#$b#$b_b#"
echo $sbfiles | xargs -n1 sed -i "57s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "58s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "vmess-ws协议域名证书更换完毕"
echo
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
blue "当前Vmess-ws(tls)的端口：$vm_port"
[[ "$tls" = "false" ]] && blue "切记：可进入主菜单选项4-2，将Vmess-ws端口更改为任意7个80系端口(80、8080、8880、2052、2082、2086、2095)，可实现CDN优选IP" || blue "切记：可进入主菜单选项4-2，将Vmess-ws-tls端口更改为任意6个443系的端口(443、8443、2053、2083、2087、2096)，可实现CDN优选IP"
echo
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "3" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "79s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "80s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Hysteria2协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "4" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "102s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "103s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Tuic5协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
elif [ "$menu" = "5" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "119s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "120s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls协议域名证书更换完毕"
else
red "当前未申请域名证书，不可切换。主菜单选择12，执行Acme证书申请" && sleep 2 && sb
fi
else
sb
fi
}

allports(){
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
tu5_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$tu5_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
[[ -n $hy2_ports ]] && hy2zfport="$hy2_ports" || hy2zfport="未添加"
[[ -n $tu5_ports ]] && tu5zfport="$tu5_ports" || tu5zfport="未添加"
}

changeport(){
sbactive
allports
fports(){
readp "\n请输入转发的端口范围 (1000-65535范围内，格式为 小数字:大数字)：" rangeport
if [[ $rangeport =~ ^([1-9][0-9]{3,4}:[1-9][0-9]{3,4})$ ]]; then
b=${rangeport%%:*}
c=${rangeport##*:}
if [[ $b -ge 1000 && $b -le 65535 && $c -ge 1000 && $c -le 65535 && $b -lt $c ]]; then
iptables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口范围：$rangeport"
else
red "输入的端口范围不在有效范围内" && fports
fi
else
red "输入格式不正确。格式为 小数字:大数字" && fports
fi
echo
}
fport(){
readp "\n请输入一个转发的端口 (1000-65535范围内)：" onlyport
if [[ $onlyport -ge 1000 && $onlyport -le 65535 ]]; then
iptables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "已确认转发的端口：$onlyport"
else
blue "输入的端口不在有效范围内" && fport
fi
echo
}

hy2deports(){
allports
hy2_ports=$(echo "$hy2_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$hy2_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}
tu5deports(){
allports
tu5_ports=$(echo "$tu5_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$tu5_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}

allports
green "Vless-reality、Vmess-ws、Anytls仅能更改唯一的端口，vmess-ws注意Argo端口重置"
green "Hysteria2与Tuic5支持更改主端口，也支持增删多个转发端口"
green "Hysteria2支持端口跳跃，且与Tuic5都支持多端口复用"
echo
green "1：Vless-reality协议 ${yellow}端口:$vl_port${plain}"
green "2：Vmess-ws协议 ${yellow}端口:$vm_port${plain}"
green "3：Hysteria2协议 ${yellow}端口:$hy2_port  转发多端口: $hy2zfport${plain}"
green "4：Tuic5协议 ${yellow}端口:$tu5_port  转发多端口: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
green "5：Anytls协议 ${yellow}端口:$an_port${plain}"
fi
green "0：返回上层"
readp "请选择要变更端口的协议：" menu
if [ "$menu" = "1" ]; then
vlport
echo $sbfiles | xargs -n1 sed -i "14s/$vl_port/$port_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality端口更改完成"
echo
elif [ "$menu" = "5" ]; then
anport
echo $sbfiles | xargs -n1 sed -i "110s/$an_port/$port_an/"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls端口更改完成"
echo
elif [ "$menu" = "2" ]; then
vmport
echo $sbfiles | xargs -n1 sed -i "41s/$vm_port/$port_vm_ws/"
restartsb && sbshare > /dev/null 2>&1
blue "Vmess-ws端口更改完成"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
blue "切记：如果Argo使用中，临时隧道必须重置，固定隧道的CF设置界面端口必须修改为$port_vm_ws"
else
blue "因TLS已开启，当前Argo隧道已不支持开启"
fi
echo
elif [ "$menu" = "3" ]; then
green "1：更换Hysteria2主端口 (原多端口自动重置删除)"
green "2：添加Hysteria2多端口"
green "3：重置删除Hysteria2多端口"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n "$hy2_ports" ]; then
hy2deports
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
else
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Hysteria2端口更改完成"
elif [ "$menu" = "2" ]; then
green "1：添加Hysteria2范围端口"
green "2：添加Hysteria2单端口"
green "0：返回上层"
readp "请选择【0-2】：" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n "$hy2_ports" ]; then
hy2deports && sbshare > /dev/null 2>&1 yellow "Hysteria2多端口已删除" && changeport
else
sbshare > /dev/null 2>&1 && yellow "Hysteria2未设置多端口" && changeport
fi
else
changeport
fi

elif [ "$menu" = "4" ]; then
green "1：更换Tuic5主端口 (原多端口自动重置删除)"
green "2：添加Tuic5多端口"
green "3：重置删除Tuic5多端口"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
if [ -n "$tu5_ports" ]; then
tu5deports
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
else
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Tuic5端口更改完成"
elif [ "$menu" = "2" ]; then
green "1：添加Tuic5范围端口"
green "2：添加Tuic5单端口"
green "0：返回上层"
readp "请选择【0-2】：" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n "$tu5_ports" ]; then
tu5deports && sbshare > /dev/null 2>&1 yellow "Tuic5多端口已删除" && changeport
else
sbshare > /dev/null 2>&1 && yellow "Tuic5未设置多端口" && changeport
fi
else
changeport
fi
else
sb
fi
}

changeuuid(){
echo
olduuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
oldvmpath=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
green "全协议的uuid (密码)：$olduuid"
green "Vmess的path路径：$oldvmpath"
echo
yellow "1：自定义全协议的uuid (密码)"
yellow "2：自定义Vmess的path路径"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
readp "输入uuid，必须是uuid格式，不懂就回车(重置并随机生成uuid)：" menu
if [ -z "$menu" ]; then
uuid=$(/etc/s-box/sing-box generate uuid)
else
uuid=$menu
fi
echo $sbfiles | xargs -n1 sed -i "s/$olduuid/$uuid/g"
restartsb && sbshare > /dev/null 2>&1
blue "已确认uuid (密码)：${uuid}" 
blue "已确认Vmess的path路径：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
elif [ "$menu" = "2" ]; then
readp "输入Vmess的path路径，回车表示不变：" menu
if [ -z "$menu" ]; then
echo
else
vmpath=$menu
echo $sbfiles | xargs -n1 sed -i "50s#$oldvmpath#$vmpath#g"
restartsb && sbshare > /dev/null 2>&1
fi
blue "已确认Vmess的path路径：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
else
changeserv
fi
}

changeip(){
if [[ "$sbnh" == "1.10" ]]; then
v4v6
chip(){
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy')
sed -i "111s/$rpip/$rrpip/g" /etc/s-box/sb10.json
cp /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
}
readp "1. IPV4优先\n2. IPV6优先\n3. 仅IPV4\n4. 仅IPV6\n请选择：" choose
if [[ $choose == "1" && -n $v4 ]]; then
rrpip="prefer_ipv4" && chip && v4_6="IPV4优先($v4)"
elif [[ $choose == "2" && -n $v6 ]]; then
rrpip="prefer_ipv6" && chip && v4_6="IPV6优先($v6)"
elif [[ $choose == "3" && -n $v4 ]]; then
rrpip="ipv4_only" && chip && v4_6="仅IPV4($v4)"
elif [[ $choose == "4" && -n $v6 ]]; then
rrpip="ipv6_only" && chip && v4_6="仅IPV6($v6)"
else 
red "当前不存在你选择的IPV4/IPV6地址，或者输入错误" && changeip
fi
blue "当前已更换的IP优先级：${v4_6}" && sb
else
red "仅支持1.10.7内核可用" && exit
fi
}

tgsbshow(){
echo
yellow "1：重置/设置Telegram机器人的Token、用户ID"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
rm -rf /etc/s-box/sbtg.sh
readp "输入Telegram机器人Token: " token
telegram_token=$token
readp "输入Telegram机器人用户ID: " userid
telegram_id=$userid
echo '#!/bin/bash
export LANG=en_US.UTF-8
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
total_lines=$(wc -l < /etc/s-box/clmi.yaml)
half=$((total_lines / 2))
head -n $half /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client1.txt
tail -n +$((half + 1)) /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client2.txt

total_lines=$(wc -l < /etc/s-box/sbox.json)
quarter=$((total_lines / 4))
head -n $quarter /etc/s-box/sbox.json > /etc/s-box/sing_box_client1.txt
tail -n +$((quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client2.txt
tail -n +$((2 * quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client3.txt
tail -n +$((3 * quarter + 1)) /etc/s-box/sbox.json > /etc/s-box/sing_box_client4.txt

m1=$(cat /etc/s-box/vl_reality.txt 2>/dev/null)
m2=$(cat /etc/s-box/vm_ws.txt 2>/dev/null)
m3=$(cat /etc/s-box/vm_ws_argols.txt 2>/dev/null)
m3_5=$(cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null)
m4=$(cat /etc/s-box/vm_ws_tls.txt 2>/dev/null)
m5=$(cat /etc/s-box/hy2.txt 2>/dev/null)
m6=$(cat /etc/s-box/tuic5.txt 2>/dev/null)
m7=$(cat /etc/s-box/sing_box_client1.txt 2>/dev/null)
m7_5=$(cat /etc/s-box/sing_box_client2.txt 2>/dev/null)
m7_5_5=$(cat /etc/s-box/sing_box_client3.txt 2>/dev/null)
m7_5_5_5=$(cat /etc/s-box/sing_box_client4.txt 2>/dev/null)
m8=$(cat /etc/s-box/clash_meta_client1.txt 2>/dev/null)
m8_5=$(cat /etc/s-box/clash_meta_client2.txt 2>/dev/null)
m9=$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)
m10=$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)
m11=$(cat /etc/s-box/jhsub.txt 2>/dev/null)
m12=$(cat /etc/s-box/an.txt 2>/dev/null)
message_text_m1=$(echo "$m1")
message_text_m2=$(echo "$m2")
message_text_m3=$(echo "$m3")
message_text_m3_5=$(echo "$m3_5")
message_text_m4=$(echo "$m4")
message_text_m5=$(echo "$m5")
message_text_m6=$(echo "$m6")
message_text_m7=$(echo "$m7")
message_text_m7_5=$(echo "$m7_5")
message_text_m7_5_5=$(echo "$m7_5_5")
message_text_m7_5_5_5=$(echo "$m7_5_5_5")
message_text_m8=$(echo "$m8")
message_text_m8_5=$(echo "$m8_5")
message_text_m9=$(echo "$m9")
message_text_m10=$(echo "$m10")
message_text_m11=$(echo "$m11")
message_text_m12=$(echo "$m12")
MODE=HTML
URL="https://api.telegram.org/bottelegram_token/sendMessage"
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vless-reality-vision 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m1}")
if [[ -f /etc/s-box/vm_ws.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m2}")
fi
if [[ -f /etc/s-box/vm_ws_argols.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo临时域名分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m3}")
fi
if [[ -f /etc/s-box/vm_ws_argogd.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo固定域名分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m3_5}")
fi
if [[ -f /etc/s-box/vm_ws_tls.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws-tls 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m4}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Hysteria-2 分享链接 】：支持v2rayng、nekobox "$'"'"'\n\n'"'"'"${message_text_m5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Tuic-v5 分享链接 】：支持nekobox "$'"'"'\n\n'"'"'"${message_text_m6}")
if [[ "$sbnh" != "1.10" ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Anytls 分享链接 】：仅最新内核可用 "$'"'"'\n\n'"'"'"${message_text_m12}")
fi
if [[ -f /etc/s-box/sing_box_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box 订阅链接 】：支持SFA、SFW、SFI "$'"'"'\n\n'"'"'"${message_text_m9}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box 配置文件(4段) 】：支持SFA、SFW、SFI "$'"'"'\n\n'"'"'"${message_text_m7}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5_5}")
fi

if [[ -f /etc/s-box/clash_meta_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Mihomo 订阅链接 】：支持Mihomo相关客户端 "$'"'"'\n\n'"'"'"${message_text_m10}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Mihomo 配置文件(2段) 】：支持Mihomo相关客户端 "$'"'"'\n\n'"'"'"${message_text_m8}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m8_5}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 聚合节点 】：支持nekobox "$'"'"'\n\n'"'"'"${message_text_m11}")

if [ $? == 124 ];then
echo TG_api请求超时,请检查网络是否重启完成并是否能够访问TG
fi
resSuccess=$(echo "$res" | jq -r ".ok")
if [[ $resSuccess = "true" ]]; then
echo "TG推送成功";
else
echo "TG推送失败，请检查TG机器人Token和ID";
fi
' > /etc/s-box/sbtg.sh
sed -i "s/telegram_token/$telegram_token/g" /etc/s-box/sbtg.sh
sed -i "s/telegram_id/$telegram_id/g" /etc/s-box/sbtg.sh
green "设置完成！请确保TG机器人已处于激活状态！"
tgnotice
else
changeserv
fi
}

tgnotice(){
if [[ -f /etc/s-box/sbtg.sh ]]; then
green "请稍等5秒，TG机器人准备推送……"
sbshare > /dev/null 2>&1
bash /etc/s-box/sbtg.sh
else
yellow "未设置TG通知功能"
fi
exit
}

changeserv(){
sbactive
echo
green "Sing-box配置变更选择如下:"
readp "1：更换Reality域名伪装地址、切换自签证书与Acme域名证书、开关TLS\n2：更换全协议UUID(密码)、Vmess-Path路径\n3：设置Argo临时隧道、固定隧道\n4：切换IPV4或IPV6的代理优先级 (仅 1.10.7 内核可用)\n5：设置Telegram推送节点通知\n6：更换Warp-wireguard出站账户\n7：设置Gitlab订阅分享链接\n8：设置本地IP订阅分享链接\n9：设置所有Vmess节点的CDN优选地址\n0：返回上层\n请选择【0-9】：" menu
if [ "$menu" = "1" ];then
changeym
elif [ "$menu" = "2" ];then
changeuuid
elif [ "$menu" = "3" ];then
cfargo_ym
elif [ "$menu" = "4" ];then
changeip
elif [ "$menu" = "5" ];then
tgsbshow
elif [ "$menu" = "6" ];then
changewg
elif [ "$menu" = "7" ];then
gitlabsub
elif [ "$menu" = "8" ];then
ipsub
elif [ "$menu" = "9" ];then
vmesscfadd
else 
sb
fi
}

ipsub(){
subtokenipsub(){
echo
readp "输入订阅链接路径密码（回车表示使用当前UUID）：" menu
if [ -z "$menu" ]; then
subtoken="$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')"
else
subtoken="$menu"
fi
rm -rf /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
echo $subtoken > /etc/s-box/subtoken.log
green "订阅链接路径密码：$(cat /etc/s-box/subtoken.log 2>/dev/null)"
}
subportipsub(){
echo
readp "输入未被占用且可用的订阅链接端口（回车表示随机端口）：" menu
if [ -z "$menu" ]; then
subport=$(shuf -i 10000-65535 -n 1)
else
subport="$menu"
fi
echo $subport > /etc/s-box/subport.log
green "订阅链接端口：$(cat /etc/s-box/subport.log 2>/dev/null)"
}
echo
yellow "1：重置安装本地IP订阅链接"
yellow "2：更换订阅链接路径密码"
yellow "3：更换订阅链接端口"
yellow "4：卸载本地IP订阅链接"
yellow "0：返回上层"
readp "请选择【0-4】：" menu
if [ "$menu" = "1" ]; then
subtokenipsub && subportipsub
elif [ "$menu" = "2" ];then
subtokenipsub
elif [ "$menu" = "3" ];then
subportipsub
elif [ "$menu" = "4" ];then
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /root/websbox
rm -rf /etc/local.d/alpinesub.start
green "本地IP订阅链接已卸载完成" && sleep 3 && exit
else
changeserv
fi
echo
green "请稍后…………"
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
mkdir -p /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
ln -sf /etc/s-box/clmi.yaml /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/clmi.yaml
ln -sf /etc/s-box/sbox.json /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/sbox.json
ln -sf /etc/s-box/jhsub.txt /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/jhsub.txt
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
else
busybox httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
fi
sleep 5
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesub.start <<'EOF'
#!/bin/bash
sleep 10
busybox-extras httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesub.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
sbshare > /dev/null 2>&1
sleep 1 && green "本地IP订阅链接已更新完成" && sleep 3 && sb
}

vmesscfadd(){
echo
green "推荐使用稳定的世界大厂或组织的官方CDN域名作为CDN优选地址："
blue "cloudflare-ech.com"
blue "www.visa.com.sg"
blue "www.wto.org"
blue "www.shopify.com"
blue "yg1.ygkkk.dpdns.org (yg1中的1，可换为1-13中任意数字)"
echo
yellow "1：自定义Vmess-ws(tls)主协议节点的CDN优选地址"
yellow "2：针对选项1，重置客户端host/sni域名(IP解析到CF上的域名)"
yellow "3：自定义Vmess-ws(tls)-Argo节点的CDN优选地址"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
echo
green "请确保VPS的IP已解析到Cloudflare的域名上"
if [[ ! -f /etc/s-box/cfymjx.txt ]] 2>/dev/null; then
readp "输入客户端host/sni域名(IP解析到CF上的域名)：" menu
echo "$menu" > /etc/s-box/cfymjx.txt
fi
echo
readp "输入自定义的优选IP/域名：" menu
echo "$menu" > /etc/s-box/cfvmadd_local.txt
sbshare > /dev/null 2>&1
green "设置成功，选择主菜单9进行节点配置更新" && sleep 2 && vmesscfadd
elif  [ "$menu" = "2" ]; then
rm -rf /etc/s-box/cfymjx.txt
sbshare > /dev/null 2>&1
green "重置成功，可选择1重新设置" && sleep 2 && vmesscfadd
elif  [ "$menu" = "3" ]; then
readp "输入自定义的优选IP/域名：" menu
echo "$menu" > /etc/s-box/cfvmadd_argo.txt
sbshare > /dev/null 2>&1
green "设置成功，选择主菜单9进行节点配置更新" && sleep 2 && vmesscfadd
else
changeserv
fi
}

gitlabsub(){
echo
green "请确保Gitlab官网上已建立项目，已开启推送功能，已获取访问令牌"
yellow "1：重置/设置Gitlab订阅链接"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
cd /etc/s-box
readp "输入登录邮箱: " email
readp "输入访问令牌: " token
readp "输入用户名: " userid
readp "输入项目名: " project
echo
green "多台VPS共用一个令牌及项目名，可创建多个分支订阅链接"
green "回车跳过表示不新建，仅使用主分支main订阅链接(首台VPS建议回车跳过)"
readp "新建分支名称: " gitlabml
echo
if [[ -z "$gitlabml" ]]; then
gitlab_ml=''
git_sk=main
rm -rf /etc/s-box/gitlab_ml_ml
else
gitlab_ml=":${gitlabml}"
git_sk="${gitlabml}"
echo "${gitlab_ml}" > /etc/s-box/gitlab_ml_ml
fi
echo "$token" > /etc/s-box/gitlabtoken.txt
rm -rf /etc/s-box/.git
git init >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git config --global user.email "${email}" >/dev/null 2>&1
git config --global user.name "${userid}" >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
branches=$(git branch)
if [[ $branches == *master* ]]; then
git branch -m master main >/dev/null 2>&1
fi
git remote add origin https://${token}@gitlab.com/${userid}/${project}.git >/dev/null 2>&1
if [[ $(ls -a | grep '^\.git$') ]]; then
cat > /etc/s-box/gitpush.sh <<EOF
#!/usr/bin/expect
spawn bash -c "git push -f origin main${gitlab_ml}"
expect "Password for 'https://$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)@gitlab.com':"
send "$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)\r"
interact
EOF
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/sbox.json/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/sing_box_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/clmi.yaml/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/clash_meta_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/jhsub.txt/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/jh_sub_gitlab.txt
clsbshow
else
yellow "设置Gitlab订阅链接失败，请反馈"
fi
cd
else
changeserv
fi
}

gitlabsubgo(){
cd /etc/s-box
if [[ $(ls -a | grep '^\.git$') ]]; then
if [ -f /etc/s-box/gitlab_ml_ml ]; then
gitlab_ml=$(cat /etc/s-box/gitlab_ml_ml)
fi
git rm --cached sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_rm_$(date +"%F %T")" >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
clsbshow
else
yellow "未设置Gitlab订阅链接"
fi
cd
}

clsbshow(){
green "当前Sing-box节点已更新并推送"
green "Sing-box订阅链接如下："
blue "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
green "Sing-box订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前Mihomo节点配置已更新并推送"
green "Mihomo订阅链接如下："
blue "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
green "Mihomo订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前聚合节点配置已更新并推送"
green "订阅链接如下："
blue "$(cat /etc/s-box/jh_sub_gitlab.txt 2>/dev/null)"
echo
yellow "可以在网页上输入订阅链接查看配置内容，如果无配置内容，请自检Gitlab相关设置并重置"
echo
}

warpwg(){
warpcode(){
reg(){
keypair=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout)
private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
response=$(curl -sL --tlsv1.3 --connect-timeout 3 --max-time 5 \
-X POST 'https://api.cloudflareclient.com/v0a2158/reg' \
-H 'CF-Client-Version: a-7.21-0721' \
-H 'Content-Type: application/json' \
-d '{
"key": "'"$public_key"'",
"tos": "'"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"'"
}')
if [ -z "$response" ]; then
return 1
fi
echo "$response" | python3 -m json.tool 2>/dev/null | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}
reserved(){
reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
echo -e "{\n    \"reserved_dec\": $reserved_dec,"
echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}
result() {
echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
echo "}"
}
warp_info=$(reg) 
warp_reserved=$(reserved) 
result
}
output=$(warpcode)
if ! echo "$output" 2>/dev/null | grep -w "private_key" > /dev/null; then
v6=2606:4700:110:860e:738f:b37:f15:d38d
pvk=g9I2sgUH6OCbIBTehkEfVEnuvInHYZvPOFhWchMLSc4=
res=[33,217,129]
else
pvk=$(echo "$output" | sed -n 4p | awk '{print $2}' | tr -d ' "' | sed 's/.$//')
v6=$(echo "$output" | sed -n 7p | awk '{print $2}' | tr -d ' "')
res=$(echo "$output" | sed -n 1p | awk -F":" '{print $NF}' | tr -d ' ' | sed 's/.$//')
fi
blue "Private_key私钥：$pvk"
blue "IPV6地址：$v6"
blue "reserved值：$res"
}

changewg(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
if [[ "$sbnh" == "1.10" ]]; then
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .local_address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .private_key')
wgres=$(sed -n '165s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server_port')
else
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .private_key')
wgres=$(sed -n '142s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].address')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].port')
fi
echo
green "当前warp-wireguard可更换的参数如下："
green "Private_key私钥：$wgprkey"
green "IPV6地址：$wgipv6"
green "Reserved值：$wgres"
green "对端IP：$wgip:$wgpo"
echo
yellow "1：更换warp-wireguard账户"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
green "最新随机生成普通warp-wireguard账户如下"
warpwg
echo
readp "输入自定义Private_key：" menu
sed -i "163s#$wgprkey#$menu#g" /etc/s-box/sb10.json
sed -i "132s#$wgprkey#$menu#g" /etc/s-box/sb11.json
readp "输入自定义IPV6地址：" menu
sed -i "161s/$wgipv6/$menu/g" /etc/s-box/sb10.json
sed -i "130s/$wgipv6/$menu/g" /etc/s-box/sb11.json
readp "输入自定义Reserved值 (格式：数字,数字,数字)，如无值则回车跳过：" menu
if [ -z "$menu" ]; then
menu=0,0,0
fi
sed -i "165s/$wgres/$menu/g" /etc/s-box/sb10.json
sed -i "142s/$wgres/$menu/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
green "设置结束"
else
changeserv
fi
}

sbymfl(){
sbport=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}' | awk -F":" '{print $NF}') 
sbport=${sbport:-'40000'}
resv1=$(curl -sm3 --socks5 localhost:$sbport icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$sbport icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
warp_s4_ip='Socks5-IPV4未启动，黑名单模式'
warp_s6_ip='Socks5-IPV6未启动，黑名单模式'
else
warp_s4_ip='Socks5-IPV4可用'
warp_s6_ip='Socks5-IPV6自测'
fi
v4v6
if [[ -z $v4 ]]; then
vps_ipv4='无本地IPV4，黑名单模式'      
vps_ipv6="当前IP：$v6"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="当前IP：$v4"    
vps_ipv6="当前IP：$v6"
else
vps_ipv4="当前IP：$v4"    
vps_ipv6='无本地IPV6，黑名单模式'
fi
unset swg4 swd4 swd6 swg6 ssd4 ssg4 ssd6 ssg6 sad4 sag4 sad6 sag6
wd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].domain_suffix | join(" ")')
wg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].geosite | join(" ")' 2>/dev/null)
if [[ "$wd4" == "yg_kkk" && ("$wg4" == "yg_kkk" || -z "$wg4") ]]; then
wfl4="${yellow}【warp出站IPV4可用】未分流${plain}"
else
if [[ "$wd4" != "yg_kkk" ]]; then
swd4="$wd4 "
fi
if [[ "$wg4" != "yg_kkk" ]]; then
swg4=$wg4
fi
wfl4="${yellow}【warp出站IPV4可用】已分流：$swd4$swg4${plain} "
fi

wd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].domain_suffix | join(" ")')
wg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].geosite | join(" ")' 2>/dev/null)
if [[ "$wd6" == "yg_kkk" && ("$wg6" == "yg_kkk"|| -z "$wg6") ]]; then
wfl6="${yellow}【warp出站IPV6自测】未分流${plain}"
else
if [[ "$wd6" != "yg_kkk" ]]; then
swd6="$wd6 "
fi
if [[ "$wg6" != "yg_kkk" ]]; then
swg6=$wg6
fi
wfl6="${yellow}【warp出站IPV6自测】已分流：$swd6$swg6${plain} "
fi

sd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].domain_suffix | join(" ")')
sg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].geosite | join(" ")' 2>/dev/null)
if [[ "$sd4" == "yg_kkk" && ("$sg4" == "yg_kkk" || -z "$sg4") ]]; then
sfl4="${yellow}【$warp_s4_ip】未分流${plain}"
else
if [[ "$sd4" != "yg_kkk" ]]; then
ssd4="$sd4 "
fi
if [[ "$sg4" != "yg_kkk" ]]; then
ssg4=$sg4
fi
sfl4="${yellow}【$warp_s4_ip】已分流：$ssd4$ssg4${plain} "
fi

sd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].domain_suffix | join(" ")')
sg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].geosite | join(" ")' 2>/dev/null)
if [[ "$sd6" == "yg_kkk" && ("$sg6" == "yg_kkk" || -z "$sg6") ]]; then
sfl6="${yellow}【$warp_s6_ip】未分流${plain}"
else
if [[ "$sd6" != "yg_kkk" ]]; then
ssd6="$sd6 "
fi
if [[ "$sg6" != "yg_kkk" ]]; then
ssg6=$sg6
fi
sfl6="${yellow}【$warp_s6_ip】已分流：$ssd6$ssg6${plain} "
fi

ad4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].domain_suffix | join(" ")' 2>/dev/null)
ag4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad4" == "yg_kkk" || -z "$ad4") && ("$ag4" == "yg_kkk" || -z "$ag4") ]]; then
adfl4="${yellow}【$vps_ipv4】未分流${plain}" 
else
if [[ "$ad4" != "yg_kkk" ]]; then
sad4="$ad4 "
fi
if [[ "$ag4" != "yg_kkk" ]]; then
sag4=$ag4
fi
adfl4="${yellow}【$vps_ipv4】已分流：$sad4$sag4${plain} "
fi

ad6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].domain_suffix | join(" ")' 2>/dev/null)
ag6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad6" == "yg_kkk" || -z "$ad6") && ("$ag6" == "yg_kkk" || -z "$ag6") ]]; then
adfl6="${yellow}【$vps_ipv6】未分流${plain}" 
else
if [[ "$ad6" != "yg_kkk" ]]; then
sad6="$ad6 "
fi
if [[ "$ag6" != "yg_kkk" ]]; then
sag6=$ag6
fi
adfl6="${yellow}【$vps_ipv6】已分流：$sad6$sag6${plain} "
fi
}

changefl(){
sbactive
blue "对所有协议进行统一的域名分流"
blue "为确保分流可用，双栈IP（IPV4/IPV6）分流模式为优先模式"
blue "warp-wireguard默认开启 (选项1与2)"
blue "socks5需要在VPS安装warp官方客户端或者WARP-plus-Socks5-赛风VPN (选项3与4)"
blue "VPS本地出站分流(选项5与6)"
echo
[[ "$sbnh" == "1.10" ]] && blue "当前Sing-box内核支持geosite分流方式" || blue "当前Sing-box内核不支持geosite分流方式，仅支持分流2、3、5、6选项"
echo
yellow "注意："
yellow "一、后缀域名方式只能填域名 (例：谷歌网站填写：google.com googleapis.com)"
yellow "二、geosite方式须填写geosite规则名 (例：奈飞填写netflix ；迪士尼填写disney ；ChatGPT填写openai ；全局且绕过中国填写geolocation-!cn)"
yellow "三、同一个完整域名或者geosite切勿重复分流"
yellow "四、如分流通道中有个别通道无网络，所填分流为黑名单模式，即屏蔽该网站访问"
changef
}

changef(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sbymfl
echo
[[ "$sbnh" != "1.10" ]] && wfl4='暂不支持' sfl6='暂不支持' adfl4='暂不支持' adfl6='暂不支持'
green "1：重置warp-wireguard-ipv4优先分流域名 $wfl4"
green "2：重置warp-wireguard-ipv6优先分流域名 $wfl6"
green "3：重置warp-socks5-ipv4优先分流域名 $sfl4"
green "4：重置warp-socks5-ipv6优先分流域名 $sfl6"
green "5：重置VPS本地ipv4优先分流域名 $adfl4"
green "6：重置VPS本地ipv6优先分流域名 $adfl6"
green "0：返回上层"
echo
readp "请选择：" menu

if [ "$menu" = "1" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv4的后缀域名方式的分流通道)：" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "184s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv4的geosite方式的分流通道)：" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "187s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "遗憾！当前暂时只支持warp-wireguard-ipv6，如需要warp-wireguard-ipv4，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "2" ]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv6的后缀域名方式的分流通道：" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "193s/.*/$w6flym/" /etc/s-box/sb10.json
sed -i "184s/.*/$w6flym/" /etc/s-box/sb11.json
sed -i "196s/.*/$w6flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-wireguard-ipv6的geosite方式的分流通道：" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "196s/.*/$w6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi

elif [ "$menu" = "3" ]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv4的后缀域名方式的分流通道：" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "202s/.*/$s4flym/" /etc/s-box/sb10.json
sed -i "177s/.*/$s4flym/" /etc/s-box/sb11.json
sed -i "190s/.*/$s4flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv4的geosite方式的分流通道：" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "205s/.*/$s4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi

elif [ "$menu" = "4" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv6的后缀域名方式的分流通道：" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "211s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空warp-socks5-ipv6的geosite方式的分流通道：" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "214s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "遗憾！当前暂时只支持warp-socks5-ipv4，如需要warp-socks5-ipv6，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "5" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv4的后缀域名方式的分流通道：" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "220s/.*/$ad4flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv4的geosite方式的分流通道：" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "223s/.*/$ad4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi
else
yellow "遗憾！如需要VPS本地ipv4分流，请切换1.10系列内核" && exit
fi

elif [ "$menu" = "6" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1：使用后缀域名方式\n2：使用geosite方式\n3：返回上层\n请选择：" menu
if [ "$menu" = "1" ]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv6的后缀域名方式的分流通道：" ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "229s/.*/$ad6flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "每个域名之间留空格，回车跳过表示重置清空VPS本地ipv6的geosite方式的分流通道：" ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "232s/.*/$ad6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "遗憾！当前Sing-box内核不支持geosite分流方式。如要支持，请切换1.10系列内核" && exit
fi
else
changef
fi
else
yellow "遗憾！如需要VPS本地ipv6分流，请切换1.10系列内核" && exit
fi
else
sb
fi
}

restartsb(){
if command -v apk >/dev/null 2>&1; then
rc-service sing-box restart
else
systemctl enable sing-box
systemctl start sing-box
systemctl restart sing-box
fi
}

stclre(){
if [[ ! -f '/etc/s-box/sb.json' ]]; then
red "未正常安装Sing-box" && exit
fi
readp "1：重启\n2：关闭\n请选择：" menu
if [ "$menu" = "1" ]; then
restartsb
sbactive
green "Sing-box服务已重启\n" && sleep 3 && sb
elif [ "$menu" = "2" ]; then
if command -v apk >/dev/null 2>&1; then
rc-service sing-box stop
else
systemctl stop sing-box
systemctl disable sing-box
fi
green "Sing-box服务已关闭\n" && sleep 3 && sb
else
stclre
fi
}

cronsb(){
uncronsb
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo "0 1 * * * systemctl restart sing-box;rc-service sing-box restart" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}
uncronsb(){
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sing-box/d' /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
sed -i '/websbox/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}

lnsb(){
rm -rf /usr/bin/sb
curl -L -o /usr/bin/sb -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh
chmod +x /usr/bin/sb
}

upsbyg(){
if [[ ! -f '/usr/bin/sb' ]]; then
red "未正常安装Sing-box-yg" && exit
fi
lnsb
curl -sL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /etc/s-box/v
green "Sing-box-yg安装脚本升级成功" && sleep 5 && sb
}

lapre(){
json=$(curl -Ls --max-time 3 https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box)
if echo "$json"|grep -q '"versions"'; then
latcore=$(echo "$json"|grep -Eo '"[0-9.]+",'|head -n1|tr -d '",')
precore=$(echo "$json"|grep -Eo '"[0-9.]*-[^"]*"'|head -n1|tr -d '",')
else
page=$(curl -Ls --max-time 3 https://github.com/SagerNet/sing-box/releases)
latcore=$(echo "$page"|grep -oE 'tag/v[0-9.]+'|head -n1|cut -d'v' -f2)
precore=$(echo "$page"|grep -oE '/tag/v[0-9.]+-[^"]+'|head -n1|cut -d'v' -f2)
fi
inscore=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}')
}

upsbcroe(){
sbactive
lapre
[[ $inscore =~ ^[0-9.]+$ ]] && lat="【已安装v$inscore】" || pre="【已安装v$inscore】"
green "1：升级/切换Sing-box最新正式版 v$latcore  ${bblue}${lat}${plain}"
green "2：升级/切换Sing-box最新测试版 v$precore  ${bblue}${pre}${plain}"
green "3：切换Sing-box某个正式版或测试版，需指定版本号 (建议1.10.0以上版本)"
green "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
elif [ "$menu" = "2" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases | grep -oP '/tag/v\K[0-9.]+-[^"]+' | head -n 1)
elif [ "$menu" = "3" ]; then
echo
red "注意: 版本号在 https://github.com/SagerNet/sing-box/tags 可查，且有Downloads字样 (必须1.10系或者1.30系以上版本)"
green "正式版版本号格式：数字.数字.数字 (例：1.10.7   注意，1.10系列内核支持geosite分流，1.10以上内核不支持geosite分流"
green "测试版版本号格式：数字.数字.数字-alpha或rc或beta.数字 (例：1.13.0-alpha或rc或beta.1)"
readp "请输入Sing-box版本号：" upcore
else
sb
fi
if [[ -n $upcore ]]; then
green "开始下载并更新Sing-box内核……请稍等"
sbname="sing-box-$upcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$upcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' 2>/dev/null | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb && sbshare > /dev/null 2>&1
blue "成功升级/切换 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')" && sleep 3 && sb
else
red "下载 Sing-box 内核不完整，安装失败，请重试" && upsbcroe
fi
else
red "下载 Sing-box 内核失败或不存在，请重试" && upsbcroe
fi
else
red "版本号检测出错，请重试" && upsbcroe
fi
}

unins(){
if command -v apk >/dev/null 2>&1; then
for svc in sing-box argo; do
rc-service "$svc" stop >/dev/null 2>&1
rc-update del "$svc" default >/dev/null 2>&1
done
rm -rf /etc/init.d/{sing-box,argo}
else
for svc in sing-box argo; do
systemctl stop "$svc" >/dev/null 2>&1
systemctl disable "$svc" >/dev/null 2>&1
done
rm -rf /etc/systemd/system/{sing-box.service,argo.service}
fi
ps -ef | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
kill -15 $(pgrep -f 'websbox' 2>/dev/null) >/dev/null 2>&1
rm -rf /etc/s-box sbyg_update /usr/bin/sb /root/geoip.db /root/geosite.db /root/warpapi /root/warpip /root/websbox
rm -f /etc/local.d/alpineargo.start /etc/local.d/alpinesub.start /etc/local.d/alpinews5.start
uncronsb
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
green "Sing-box卸载完成！"
blue "欢迎继续使用Sing-box-yg脚本：bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)"
echo
}

sblog(){
red "退出日志 Ctrl+c"
if command -v apk >/dev/null 2>&1; then
yellow "暂不支持alpine查看日志"
else
#systemctl status sing-box
journalctl -u sing-box.service -o cat -f
fi
}

sbactive(){
if [[ ! -f /etc/s-box/sb.json ]]; then
red "未正常启动Sing-box，请卸载重装或者选择10查看运行日志反馈" && exit
fi
}

sbshare(){
rm -rf /etc/s-box/{jhdy,vl_reality,vm_ws_argols,vm_ws_argogd,vm_ws,vm_ws_tls,hy2,tuic5,an}.txt
result_vl_vm_hy_tu && resvless && resvmess && reshy2 && restu5
if [[ "$sbnh" != "1.10" ]]; then
resan
fi
cat /etc/s-box/vl_reality.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argols.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_tls.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/hy2.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/tuic5.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/an.txt 2>/dev/null >> /etc/s-box/jhdy.txt
v2sub=$(cat /etc/s-box/jhdy.txt 2>/dev/null)
echo "$v2sub" > /etc/s-box/jhsub.txt
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 聚合节点 】节点信息如下：" && sleep 2
echo
echo "分享链接"
echo -e "${yellow}$v2sub${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
sb_client
}

clash_sb_share(){
sbactive
echo
yellow "1：刷新并查看各协议分享链接、二维码、聚合节点"
yellow "2：刷新并查看Mihomo、Sing-box客户端SFA/SFI/SFW三合一配置、Gitlab私有订阅链接"
yellow "3：推送最新节点配置信息(选项1+选项2)到Telegram通知"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
sbshare
elif  [ "$menu" = "2" ]; then
green "请稍等……"
sbshare > /dev/null 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "Gitlab订阅链接如下："
gitlabsubgo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀Mihomo配置文件显示如下："
red "文件目录 /etc/s-box/clmi.yaml ，复制自建以yaml文件格式为准" && sleep 2
echo
cat /etc/s-box/clmi.yaml
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀SFA/SFI/SFW配置文件显示如下："
red "安卓SFA、苹果SFI，win电脑官方文件包SFW请到甬哥Github项目自行下载，"
red "文件目录 /etc/s-box/sbox.json ，复制自建以json文件格式为准" && sleep 2
echo
cat /etc/s-box/sbox.json
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
elif [ "$menu" = "3" ]; then
tgnotice
else
sb
fi
}

acme(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
}
cfwarp(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/warp-yg/main/CFwarp.sh)
}
bbr(){
if [[ $vi =~ lxc|openvz ]]; then
yellow "当前VPS的架构为 $vi，不支持开启原版BBR加速" && sleep 2 && exit 
else
green "点击任意键，即可开启BBR加速，ctrl+c退出"
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
fi
}

showprotocol(){
allports
sbymfl
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' || ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
vm_zs="TLS关闭"
argoym="已开启"
else
vm_zs="TLS关闭"
argoym="未开启"
fi
else
vm_zs="TLS开启"
argoym="不支持开启"
fi
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_zs="自签证书" || hy2_zs="域名证书"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_zs="自签证书" || tu5_zs="域名证书"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_zs="自签证书" || an_zs="域名证书"
echo -e "Sing-box节点关键信息、已分流域名情况如下："
echo -e "🚀【 Vless-reality 】${yellow}端口:$vl_port  Reality域名证书伪装地址：$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
if [[ "$tls" = "false" ]]; then
echo -e "🚀【   Vmess-ws    】${yellow}端口:$vm_port   证书形式:$vm_zs   Argo状态:$argoym${plain}"
else
echo -e "🚀【 Vmess-ws-tls  】${yellow}端口:$vm_port   证书形式:$vm_zs   Argo状态:$argoym${plain}"
fi
echo -e "🚀【  Hysteria-2   】${yellow}端口:$hy2_port  证书形式:$hy2_zs  转发多端口: $hy2zfport${plain}"
echo -e "🚀【    Tuic-v5    】${yellow}端口:$tu5_port  证书形式:$tu5_zs  转发多端口: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
echo -e "🚀【    Anytls     】${yellow}端口:$an_port  证书形式:$an_zs${plain}"
fi
if [ -s /etc/s-box/subport.log ]; then
showsubport=$(cat /etc/s-box/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
showsubtoken=$(cat /etc/s-box/subtoken.log 2>/dev/null)
subip=$(cat /etc/s-box/server_ip.log 2>/dev/null)
suburl="$subip:$showsubport/$showsubtoken"
echo "Clash/Mihomo本地IP订阅地址：http://$suburl/clmi.yaml"
echo "Sing-box本地IP订阅地址：http://$suburl/sbox.json"
echo "聚合协议本地IP订阅地址：http://$suburl/jhsub.txt"
fi
fi
if [ "$argoym" = "已开启" ]; then
#echo -e "Vmess-UUID：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')${plain}"
#echo -e "Vmess-Path：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')${plain}"
if ps -ef 2>/dev/null | grep "[l]ocalhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo -e "Argo临时域名：${yellow}$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')${plain}"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
echo -e "Argo固定域名：${yellow}$(cat /etc/s-box/sbargoym.log 2>/dev/null)${plain}"
fi
fi
echo "------------------------------------------------------------------------------------"
if [[ -n $(ps -e | grep sbwpph) ]]; then
s5port=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
s5gj=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $6}')
case "$s5gj" in
AT) showgj="奥地利" ;;
AU) showgj="澳大利亚" ;;
BE) showgj="比利时" ;;
BG) showgj="保加利亚" ;;
CA) showgj="加拿大" ;;
CH) showgj="瑞士" ;;
CZ) showgj="捷克" ;;
DE) showgj="德国" ;;
DK) showgj="丹麦" ;;
EE) showgj="爱沙尼亚" ;;
ES) showgj="西班牙" ;;
FI) showgj="芬兰" ;;
FR) showgj="法国" ;;
GB) showgj="英国" ;;
HR) showgj="克罗地亚" ;;
HU) showgj="匈牙利" ;;
IE) showgj="爱尔兰" ;;
IN) showgj="印度" ;;
IT) showgj="意大利" ;;
JP) showgj="日本" ;;
LT) showgj="立陶宛" ;;
LV) showgj="拉脱维亚" ;;
NL) showgj="荷兰" ;;
NO) showgj="挪威" ;;
PL) showgj="波兰" ;;
PT) showgj="葡萄牙" ;;
RO) showgj="罗马尼亚" ;;
RS) showgj="塞尔维亚" ;;
SE) showgj="瑞典" ;;
SG) showgj="新加坡" ;;
SK) showgj="斯洛伐克" ;;
US) showgj="美国" ;;
esac
grep -q "country" /etc/s-box/sbwpph.log 2>/dev/null && s5ms="多地区Psiphon代理模式 (端口:$s5port  国家:$showgj)" || s5ms="本地Warp代理模式 (端口:$s5port)"
echo -e "WARP-plus-Socks5状态：$yellow已启动 $s5ms$plain"
else
echo -e "WARP-plus-Socks5状态：$yellow未启动$plain"
fi
echo "------------------------------------------------------------------------------------"
ww4="warp-wireguard-ipv4优先分流域名：$wfl4"
ww6="warp-wireguard-ipv6优先分流域名：$wfl6"
ws4="warp-socks5-ipv4优先分流域名：$sfl4"
ws6="warp-socks5-ipv6优先分流域名：$sfl6"
l4="VPS本地ipv4优先分流域名：$adfl4"
l6="VPS本地ipv6优先分流域名：$adfl6"
[[ "$sbnh" == "1.10" ]] && ymflzu=("ww4" "ww6" "ws4" "ws6" "l4" "l6") || ymflzu=("ww6" "ws4" "l4" "l6")
for ymfl in "${ymflzu[@]}"; do
if [[ ${!ymfl} != *"未"* ]]; then
echo -e "${!ymfl}"
fi
done
if [[ $ww4 = *"未"* && $ww6 = *"未"* && $ws4 = *"未"* && $ws6 = *"未"* && $l4 = *"未"* && $l6 = *"未"* ]] ; then
echo -e "未设置域名分流"
fi
}

inssbwpph(){
sbactive
ins(){
if [ ! -e /etc/s-box/sbwpph ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/sbwpph -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sbwpph_$cpu
chmod +x /etc/s-box/sbwpph
fi
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
v4v6
if [[ -n $v4 ]]; then
sw46=4
else
red "IPV4不存在，确保安装过WARP-IPV4模式"
sw46=6
fi
echo
readp "设置WARP-plus-Socks5端口（回车跳过端口默认40000）：" port
if [[ -z $port ]]; then
port=40000
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
s5port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "socks") | .server_port')
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sed -i "127s/$s5port/$port/g" /etc/s-box/sb10.json
sed -i "165s/$s5port/$port/g" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
}
unins(){
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
rm -rf /etc/s-box/sbwpph.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/local.d/alpinews5.start
}
aplws5(){
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinews5.start <<'EOF'
#!/bin/bash
sleep 10
nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null)
EOF
chmod +x /etc/local.d/alpinews5.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null) &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
}
echo
yellow "1：重置启用WARP-plus-Socks5本地Warp代理模式"
yellow "2：重置启用WARP-plus-Socks5多地区Psiphon代理模式"
yellow "3：停止WARP-plus-Socks5代理模式"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
ins
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "2" ]; then
ins
echo '
奥地利（AT）
澳大利亚（AU）
比利时（BE）
保加利亚（BG）
加拿大（CA）
瑞士（CH）
捷克 (CZ)
德国（DE）
丹麦（DK）
爱沙尼亚（EE）
西班牙（ES）
芬兰（FI）
法国（FR）
英国（GB）
克罗地亚（HR）
匈牙利 (HU)
爱尔兰（IE）
印度（IN）
意大利 (IT)
日本（JP）
立陶宛（LT）
拉脱维亚（LV）
荷兰（NL）
挪威 (NO)
波兰（PL）
葡萄牙（PT）
罗马尼亚 (RO)
塞尔维亚（RS）
瑞典（SE）
新加坡 (SG)
斯洛伐克（SK）
美国（US）
'
readp "可选择国家地区（输入末尾两个大写字母，如美国，则输入US）：" guojia
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败，尝试换个国家地区吧" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "3" ]; then
unins && green "已停止WARP-plus-Socks5代理功能"
else
sb
fi
}

sbsm(){
echo
green "关注甬哥YouTube频道：https://youtube.com/@ygkkk?sub_confirmation=1 了解最新代理协议与翻墙动态"
echo
blue "sing-box-yg脚本视频教程：https://www.youtube.com/playlist?list=PLMgly2AulGG_Affv6skQXWnVqw7XWiPwJ"
echo
blue "sing-box-yg脚本博客说明：http://ygkkk.blogspot.com/2023/10/sing-box-yg.html"
echo
blue "sing-box-yg脚本项目地址：https://github.com/yonggekkk/sing-box-yg"
echo
blue "推荐甬哥新品：ArgoSBX一键无交互小钢炮脚本"
blue "ArgoSBX项目地址：https://github.com/yonggekkk/argosbx"
echo
}


# =====================================================
# Sing-box 核心函数结束
# =====================================================

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
    _inst wget; _inst curl; _inst jq; _inst python3; _inst gawk; _inst grep; _inst sed; _inst tr; _inst qrencode
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
    command -v qrencode &>/dev/null && green "  -> qrencode OK (二维码支持)"
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
    fi
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
# Step 2. Sing-box 环境初始化（已内联合并，无需外部 sb.sh）
# =====================================================
step2_prepare_env(){
    green "[2/7] 初始化 Sing-box 环境..."
    mkdir -p /etc/s-box
    green "  -> Sing-box 核心函数已内嵌，无需外部 sb.sh 文件"
}

# =====================================================
# Step 3. 安装 Sing-box + 生成分享（直接调用内嵌函数）
# =====================================================
step3_run_sbsh(){
    green "[3/7] 安装 Sing-box + 生成分享链接..."

    if [ -f '/etc/systemd/system/sing-box.service' ] && [ -f /etc/s-box/sb.json ]; then
        yellow "  -> 检测到 sing-box 已安装，跳过安装"
    else
        green "  -> 安装 sing-box（全自动，3-8 分钟）..."
        # 在子 shell 中执行：覆盖 readp/exit，预设所有变量，完全非交互
        (
            # 1. 覆盖 readp：直接返回空（触发各函数的默认值分支）
            readp(){
                local varname="$2"
                if [ -n "$varname" ]; then
                    eval "$varname=''"
                fi
            }
            # 2. 覆盖 exit：防止任何 exit 中断脚本
            exit(){ return 0; }
            # 3. 预设关键变量（避免未定义变量错误）
            menu='' action='' port='' cpu='amd64'
            # 4. 执行安装
            instsllsingbox
        ) > /var/log/vpn_sb_install.log 2>&1 || true

        local wait_n=0
        while [ $wait_n -lt 240 ]; do
            [ -f /etc/s-box/sb.json ] && break
            sleep 2; wait_n=$((wait_n+1))
        done
    fi

    if [ -f /etc/s-box/sb.json ]; then
        green "  -> 刷新分享链接 / 生成 HTML 页面..."
        (
            readp(){ local v="$2"; [ -n "$v" ] && eval "$v=''" ; }
            exit(){ return 0; }
            sbshare
        ) > /var/log/vpn_sb_share.log 2>&1 || true
    fi

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

    set +e
    set +u

    step0_install_base || true
    step1_deploy_output_helper || true
    step2_prepare_env || true
    step3_run_sbsh || true
    step4_install_nginx || true
    step5_write_nginx_conf || true
    step6_open_ports || true
    step7_show_result || true
}

main "$@"
