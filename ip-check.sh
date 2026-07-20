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
