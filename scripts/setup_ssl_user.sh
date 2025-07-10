#!/bin/bash

# 🔐 API管理系统 - 用户目录SSL配置脚本（无需root权限）
# ================================================================

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
    echo ""
    echo "🔐 API管理系统 - 用户目录SSL配置"
    echo "====================================="
    echo "✨ 无需root权限，证书存储在用户目录"
    echo ""
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖软件..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        echo ""
        echo "Ubuntu/Debian安装命令:"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sudo sh get-docker.sh"
        echo "  sudo usermod -aG docker $USER"
        echo "  # 重新登录生效"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装"
        echo ""
        echo "安装命令:"
        echo "  sudo curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "  sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    # 检查Docker是否可以无sudo运行
    if ! docker ps &> /dev/null; then
        print_error "Docker需要sudo权限运行"
        echo ""
        echo "解决方法:"
        echo "  sudo usermod -aG docker $USER"
        echo "  # 然后重新登录或运行: newgrp docker"
        exit 1
    fi
    
    print_success "依赖检查通过"
}

# 配置环境变量
setup_environment() {
    print_info "配置环境变量..."
    
    # 复制环境变量模板
    if [[ ! -f ".env" ]]; then
        if [[ -f "env.example" ]]; then
            cp env.example .env
            print_info "已创建.env文件"
        else
            print_error "env.example文件不存在"
            exit 1
        fi
    fi
    
    # 读取现有配置
    source .env 2>/dev/null || true
    
    # 配置域名
    if [[ -z "$DOMAIN" ]] || [[ "$DOMAIN" == "api.test.dpdns.org" ]]; then
        echo ""
        echo "🌐 请输入您的域名:"
        echo "示例: api.test.dpdns.org 或 test.dpdns.org"
        read -p "域名: " NEW_DOMAIN
        
        if [[ -n "$NEW_DOMAIN" ]]; then
            sed -i "s/DOMAIN=.*/DOMAIN=$NEW_DOMAIN/" .env
            DOMAIN=$NEW_DOMAIN
        fi
    fi
    
    # 配置邮箱
    if [[ -z "$CERT_EMAIL" ]] || [[ "$CERT_EMAIL" == "your-email@example.com" ]]; then
        echo ""
        echo "📧 请输入您的邮箱（Let's Encrypt通知用）:"
        read -p "邮箱: " NEW_EMAIL
        
        if [[ -n "$NEW_EMAIL" ]]; then
            sed -i "s/CERT_EMAIL=.*/CERT_EMAIL=$NEW_EMAIL/" .env
            CERT_EMAIL=$NEW_EMAIL
        fi
    fi
    
    # 设置用户目录证书路径
    HOME_SSL_PATH="$HOME/.ssl/letsencrypt/live"
    sed -i "s|SSL_CERT_PATH=.*|SSL_CERT_PATH=$HOME_SSL_PATH|" .env
    
    # 重新读取配置
    source .env
    
    print_success "环境配置完成"
    echo "  域名: $DOMAIN"
    echo "  邮箱: $CERT_EMAIL"
    echo "  证书路径: $HOME_SSL_PATH"
}

# 创建必要目录
create_directories() {
    print_info "创建必要目录..."
    
    # 创建SSL证书目录
    mkdir -p "$HOME/.ssl/letsencrypt/live"
    mkdir -p "nginx/html"
    mkdir -p "nginx/logs"
    
    # 创建nginx测试页面
    cat > nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API管理系统</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .status { color: #4CAF50; }
        .loading { color: #FF9800; }
    </style>
</head>
<body>
    <h1>🔐 API管理系统</h1>
    <p class="loading">SSL证书配置中...</p>
    <p>请等待Let's Encrypt证书申请完成</p>
</body>
</html>
EOF
    
    print_success "目录创建完成"
}

# 启动基础服务
start_basic_services() {
    print_info "启动基础服务..."
    
    # 停止可能运行的服务
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # 构建API镜像
    print_info "构建API应用..."
    docker-compose -f docker-compose.prod.yml build api
    
    # 启动数据库和API
    print_info "启动数据库和API..."
    docker-compose -f docker-compose.prod.yml up -d postgres api
    
    # 等待服务启动
    print_info "等待服务启动..."
    sleep 15
    
    # 检查服务状态
    if docker-compose -f docker-compose.prod.yml ps | grep -E "(postgres|api)" | grep -q "Up"; then
        print_success "基础服务启动成功"
    else
        print_error "基础服务启动失败"
        docker-compose -f docker-compose.prod.yml logs
        exit 1
    fi
}

# 申请SSL证书
request_ssl_certificate() {
    print_info "申请SSL证书..."
    
    # 先启动nginx（HTTP模式）
    print_info "启动nginx（HTTP模式）..."
    docker-compose -f docker-compose.prod.yml up -d nginx
    sleep 5
    
    # 测试HTTP访问
    print_info "测试域名HTTP访问..."
    if curl -f "http://$DOMAIN" >/dev/null 2>&1; then
        print_success "域名HTTP访问正常"
    else
        print_warning "无法通过HTTP访问域名，可能的原因："
        echo "  1. DNS解析未生效"
        echo "  2. 防火墙阻止80端口"
        echo "  3. 域名配置错误"
        echo ""
        echo "继续申请证书..."
    fi
    
    # 申请SSL证书
    print_info "向Let's Encrypt申请SSL证书..."
    if docker-compose -f docker-compose.prod.yml run --rm certbot; then
        print_success "SSL证书申请成功！"
        
        # 重启nginx使用HTTPS
        print_info "重启nginx启用HTTPS..."
        docker-compose -f docker-compose.prod.yml restart nginx
        
        # 启动证书自动更新服务
        print_info "启动证书自动更新服务..."
        docker-compose -f docker-compose.prod.yml up -d certbot-renewal nginx-reload
        
        return 0
    else
        print_warning "SSL证书申请失败"
        return 1
    fi
}

# 检查SSL状态
check_ssl_status() {
    local domain=$1
    
    print_info "检查SSL证书状态..."
    
    # 检查证书文件
    if docker-compose -f docker-compose.prod.yml exec nginx test -f "/home/ssl/letsencrypt/live/$domain/fullchain.pem" 2>/dev/null; then
        print_success "SSL证书文件存在"
        
        # 测试HTTPS访问
        if curl -f -k "https://$domain/health" >/dev/null 2>&1; then
            print_success "HTTPS访问正常"
            return 0
        else
            print_warning "HTTPS访问异常"
            return 1
        fi
    else
        print_warning "SSL证书文件不存在"
        return 1
    fi
}

# 显示完成信息
show_completion() {
    print_header
    
    # 检查SSL状态
    if check_ssl_status "$DOMAIN"; then
        print_success "🎉 SSL配置成功！"
        echo ""
        print_info "🔐 HTTPS访问地址:"
        echo "  https://$DOMAIN"
        echo ""
        print_info "🔐 管理界面:"
        echo "  https://$DOMAIN"
        echo "  用户名: admin"
        echo "  密码: admin123"
        echo ""
    else
        print_warning "⚠️  SSL配置部分完成"
        echo ""
        print_info "🌐 HTTP访问地址:"
        echo "  http://$DOMAIN"
        echo ""
        print_warning "SSL证书申请可能失败，常见原因："
        echo "  1. 域名DNS未正确指向服务器IP"
        echo "  2. 防火墙未开放80端口"
        echo "  3. 域名已被其他服务占用"
        echo ""
    fi
    
    print_info "📊 服务管理命令:"
    echo "  查看状态: docker-compose -f docker-compose.prod.yml ps"
    echo "  查看日志: docker-compose -f docker-compose.prod.yml logs"
    echo "  重启服务: docker-compose -f docker-compose.prod.yml restart"
    echo "  停止服务: docker-compose -f docker-compose.prod.yml down"
    echo ""
    
    print_info "🔧 SSL证书管理:"
    echo "  查看证书: ls -la ~/.ssl/letsencrypt/live/"
    echo "  手动申请: docker-compose -f docker-compose.prod.yml run --rm certbot"
    echo "  测试更新: docker-compose -f docker-compose.prod.yml exec certbot-renewal certbot renew --dry-run"
    echo ""
    
    print_info "📁 证书存储位置:"
    echo "  用户目录: ~/.ssl/letsencrypt/live/$DOMAIN/"
    echo "  Docker卷: cert-data"
    echo ""
    
    print_warning "⚠️  重要提示:"
    echo "  1. 证书存储在用户目录，无需root权限"
    echo "  2. 证书有效期90天，系统会自动续期"
    echo "  3. 确保防火墙开放80和443端口"
    echo "  4. 如需迁移，备份~/.ssl目录即可"
}

# 主函数
main() {
    print_header
    
    # 检查依赖
    check_dependencies
    
    # 配置环境
    setup_environment
    
    # 创建目录
    create_directories
    
    # 启动基础服务
    start_basic_services
    
    # 申请SSL证书
    request_ssl_certificate || true
    
    # 显示完成信息
    show_completion
}

# 运行主函数
main "$@" 