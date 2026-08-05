#!/bin/bash
# ============================================================
# MetoE 管理平台 - 一键部署脚本（Ubuntu 22.04+ / Debian 12+）
# 用法：sudo bash deploy.sh
# ============================================================

set -e

# ---------- 配置 ----------
DOMAIN=${1:-"metoe.example.com"}     # 改成你的域名，或留空用 IP
PROJECT_DIR="/var/www/metoe"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIST="$PROJECT_DIR/dist"
BACKEND_PORT=8000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "  MetoE 一键部署"
echo "  域名/IP: $DOMAIN"
echo "  项目目录: $PROJECT_DIR"
echo "=========================================="

# ---------- 1. 安装系统依赖 ----------
echo ""
echo "[1/7] 安装系统依赖..."
apt-get update -qq
apt-get install -y -qq nginx python3 python3-pip python3-venv python3-dev \
    build-essential curl git sqlite3

# ---------- 2. 创建项目目录 ----------
echo ""
echo "[2/7] 创建项目目录..."
mkdir -p "$BACKEND_DIR" "$FRONTEND_DIST"
mkdir -p "$BACKEND_DIR/data" "$BACKEND_DIR/logs"

# ---------- 3. 复制后端代码 ----------
echo ""
echo "[3/7] 复制后端代码..."
cp -r "$REPO_ROOT/metoe_backend/"* "$BACKEND_DIR/"
cd "$BACKEND_DIR"

# 创建虚拟环境并安装依赖
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q

# 初始化数据库
python3 -c "from core.init_db import init_db; init_db()" || true

deactivate

# 设置权限
chown -R www-data:www-data "$BACKEND_DIR"
chmod -R 755 "$BACKEND_DIR"

# ---------- 4. 构建前端 ----------
echo ""
echo "[4/7] 构建前端..."
cd "$REPO_ROOT/metoe"

# 检查 node 是否安装
if ! command -v node &> /dev/null; then
    echo "  安装 Node.js 18+..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
fi

npm install --silent
npm run build

cp -r dist/* "$FRONTEND_DIST/"
chown -R www-data:www-data "$FRONTEND_DIST"

# ---------- 5. 配置 Systemd 后端服务 ----------
echo ""
echo "[5/7] 配置后端服务..."
cp "$SCRIPT_DIR/systemd/metoe-backend.service" /etc/systemd/system/metoe-backend.service

# 修正路径
sed -i "s|/var/www/metoe/backend|$BACKEND_DIR|g" /etc/systemd/system/metoe-backend.service
# 如果用了虚拟环境，修正 ExecStart
sed -i "s|# ExecStart=/var/www/metoe/backend/venv/bin/uvicorn|ExecStart=$BACKEND_DIR/venv/bin/uvicorn|" /etc/systemd/system/metoe-backend.service
sed -i "/^ExecStart=\/usr\/bin\/python3/d" /etc/systemd/system/metoe-backend.service

systemctl daemon-reload
systemctl enable metoe-backend
systemctl restart metoe-backend

# 等待后端启动
sleep 2
if systemctl is-active --quiet metoe-backend; then
    echo "  ✅ 后端服务启动成功"
else
    echo "  ❌ 后端服务启动失败，查看日志：journalctl -u metoe-backend -n 50"
fi

# ---------- 6. 配置 Nginx ----------
echo ""
echo "[6/7] 配置 Nginx..."

# 备份原 nginx.conf
[ -f /etc/nginx/nginx.conf ] && cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf

# 站点配置
cp "$SCRIPT_DIR/conf.d/metoe.conf" /etc/nginx/conf.d/metoe.conf
sed -i "s|/var/www/metoe/dist|$FRONTEND_DIST|g" /etc/nginx/conf.d/metoe.conf

# 去掉默认站点（避免端口冲突）
rm -f /etc/nginx/sites-enabled/default

# 测试配置
nginx -t && systemctl reload nginx
echo "  ✅ Nginx 配置完成"

# ---------- 7. 输出结果 ----------
echo ""
echo "=========================================="
echo "  🎉 部署完成！"
echo "=========================================="
echo ""
echo "  访问地址: http://$DOMAIN"
echo ""
echo "  后端服务: systemctl status metoe-backend"
echo "  后端日志: journalctl -u metoe-backend -f"
echo "  Nginx 日志: tail -f /var/log/nginx/metoe.*.log"
echo ""
echo "  默认账号: admin / 123456"
echo "  请登录后立即修改密码！"
echo ""
