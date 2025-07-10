#!/bin/bash

# 🔐 API管理系统 - SSL自动部署脚本
# =====================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_header() {
    clear
    echo ""
    echo "🔐 API管理系统 - SSL自动部署"
    echo "=============================="
    echo ""
}

# 检查Docker和Docker Compose
check_dependencies() {
    print_info "检查依赖软件..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    print_success "依赖检查通过"
}

# 配置环境变量
setup_environment() {
    print_info "配置环境变量..."
    
    # 复制环境变量模板（如果不存在）
    if [[ ! -f ".env" ]]; then
        if [[ -f "env.example" ]]; then
            cp env.example .env
            print_info "已创建.env文件，请编辑配置"
        else
            print_error "env.example文件不存在"
            exit 1
        fi
    fi
    
    # 读取当前域名配置
    source .env 2>/dev/null || true
    
    # 交互式配置域名
    if [[ -z "$DOMAIN" ]] || [[ "$DOMAIN" == "api.test.dpdns.org" ]]; then
        echo ""
        echo "🌐 请输入您的域名:"
        echo "示例: api.test.dpdns.org 或 test.dpdns.org"
        read -p "域名: " NEW_DOMAIN
        
        if [[ -n "$NEW_DOMAIN" ]]; then
            # 更新.env文件中的域名
            sed -i "s/DOMAIN=.*/DOMAIN=$NEW_DOMAIN/" .env
            DOMAIN=$NEW_DOMAIN
        fi
    fi
    
    # 配置邮箱
    if [[ -z "$CERT_EMAIL" ]] || [[ "$CERT_EMAIL" == "your-email@example.com" ]]; then
        echo ""
        echo "📧 请输入您的邮箱地址（用于Let's Encrypt通知）:"
        read -p "邮箱: " NEW_EMAIL
        
        if [[ -n "$NEW_EMAIL" ]]; then
            # 更新.env文件中的邮箱
            sed -i "s/CERT_EMAIL=.*/CERT_EMAIL=$NEW_EMAIL/" .env
            CERT_EMAIL=$NEW_EMAIL
        fi
    fi
    
    # 重新读取配置
    source .env
    
    print_success "环境配置完成"
    echo "  域名: $DOMAIN"
    echo "  邮箱: $CERT_EMAIL"
}

# 创建必要的目录
create_directories() {
    print_info "创建必要目录..."
    
    mkdir -p nginx/html
    mkdir -p nginx/conf.d
    mkdir -p nginx/logs
    
    # 创建nginx默认页面
    cat > nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>API管理系统</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>API管理系统</h1>
    <p>系统正在启动中...</p>
</body>
</html>
EOF
    
    print_success "目录创建完成"
}

# 主函数
main() {
    print_header
    check_dependencies
    setup_environment 
    create_directories
    
    print_success "🎉 配置完成！"
    echo ""
    print_info "🚀 启动方式:"
    echo "  方式一（推荐）: ./scripts/setup_ssl_user.sh   # 无需root权限"
    echo "  方式二（手动）: docker-compose -f docker-compose.prod.yml up -d"
    echo ""
    print_warning "📁 证书存储位置:"
    echo "  用户目录: ~/.ssl/letsencrypt/live/"
    echo "  无需root权限，便于管理和备份"
}

main "$@" 