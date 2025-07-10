#!/bin/bash

# 🚀 API管理系统启动脚本
# =========================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🚀 API管理系统启动脚本"
echo "======================"

# 检查.env文件
if [[ ! -f ".env" ]]; then
    print_warning "未找到.env文件，从模板创建..."
    cp env.example .env
    print_info "请编辑.env文件配置数据库连接"
fi

# 加载环境变量
source .env 2>/dev/null || true

# 获取命令行参数
HTTPS_MODE=${1:-false}
PORT=${2:-${PORT:-8080}}

# 检查HTTPS配置
if [[ "$HTTPS_MODE" == "https" ]] || [[ "$ENABLE_HTTPS" == "true" ]]; then
    print_info "HTTPS模式启动"
    
    # 检查证书
    CERT_PATH=${SSL_CERT_PATH:-$HOME/.ssl}
    if [[ ! -f "$CERT_PATH/fullchain.pem" ]] || [[ ! -f "$CERT_PATH/privkey.pem" ]]; then
        print_warning "SSL证书不存在，正在生成..."
        ./scripts/generate_cert.sh
    fi
    
    export ENABLE_HTTPS=true
    print_success "HTTPS已启用"
else
    print_info "HTTP模式启动"
    export ENABLE_HTTPS=false
fi

# 检查依赖
print_info "检查Python依赖..."
pip3 install -r requirements.txt > /dev/null 2>&1

# 显示启动信息
echo ""
print_success "启动配置："
echo "  模式: $([ "$ENABLE_HTTPS" == "true" ] && echo "HTTPS" || echo "HTTP")"
echo "  端口: $PORT"
echo "  域名: ${DOMAIN:-localhost}"
echo ""

# 启动应用
print_info "启动API服务..."
echo "======================================"

# 设置启动参数
ARGS="--port $PORT --host 0.0.0.0"
if [[ "$ENABLE_HTTPS" == "true" ]]; then
    ARGS="$ARGS --ssl"
fi

# 启动
python3 main.py $ARGS 