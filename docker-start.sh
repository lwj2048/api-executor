#!/bin/bash

# 🐳 Docker Compose 启动脚本
# ============================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🐳 Docker Compose 启动脚本"
echo "=========================="

# 获取命令行参数
MODE=${1:-http}  # http/https/with-db

# 检查.env文件
if [[ ! -f ".env" ]]; then
    print_warning "未找到.env文件，从模板创建..."
    cp env.example .env
    print_info "请编辑.env文件配置数据库连接"
fi

# 检查Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker未安装，请先安装Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

# 加载环境变量
source .env 2>/dev/null || true

# 根据模式配置
case "$MODE" in
    "https")
        print_info "HTTPS模式启动"
        
        # 检查SSL证书
        CERT_PATH=${SSL_CERT_PATH:-$HOME/.ssl}
        if [[ ! -f "$CERT_PATH/fullchain.pem" ]] || [[ ! -f "$CERT_PATH/privkey.pem" ]]; then
            print_warning "SSL证书不存在，正在生成..."
            ./scripts/generate_cert.sh
        fi
        
        export ENABLE_HTTPS=true
        SERVICES="api nginx"
        ;;
        
    "with-db")
        print_info "包含PostgreSQL数据库启动"
        export ENABLE_HTTPS=${ENABLE_HTTPS:-false}
        COMPOSE_PROFILES="--profile with-db"
        SERVICES="api nginx postgres"
        ;;
        
    "http"|*)
        print_info "HTTP模式启动"
        export ENABLE_HTTPS=false
        SERVICES="api nginx"
        ;;
esac

# 显示启动信息
echo ""
print_success "启动配置："
echo "  模式: $MODE"
echo "  HTTPS: $([ "$ENABLE_HTTPS" == "true" ] && echo "启用" || echo "禁用")"
echo "  服务: $SERVICES"
echo ""

# 构建并启动
print_info "构建和启动Docker服务..."

# 停止现有服务
docker-compose down 2>/dev/null || true

# 启动服务
if [[ "$MODE" == "with-db" ]]; then
    docker-compose $COMPOSE_PROFILES up -d --build
else
    docker-compose up -d --build api nginx
fi

# 等待服务启动
print_info "等待服务启动..."
sleep 5

# 检查服务状态
print_info "检查服务状态..."
docker-compose ps

# 显示访问信息
echo ""
print_success "🎉 服务启动成功！"
echo ""

if [[ "$ENABLE_HTTPS" == "true" ]]; then
    print_info "🔐 HTTPS访问地址:"
    echo "  https://localhost"
else
    print_info "🌐 HTTP访问地址:"
    echo "  http://localhost"
fi

echo ""
print_info "🔐 管理界面:"
echo "  用户名: ${ADMIN_USERNAME:-admin}"
echo "  密码: ${ADMIN_PASSWORD:-admin123}"
echo ""

print_info "📊 管理命令:"
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
echo "" 