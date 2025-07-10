#!/bin/bash

# SSL证书自动申请和配置脚本
# ====================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_header() {
    echo ""
    echo "🔐 SSL证书自动配置脚本"
    echo "===================="
    echo ""
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统类型
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        print_info "检测到Debian/Ubuntu系统"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
        print_info "检测到RedHat/CentOS系统"
    else
        print_warning "未识别的系统类型，尝试通用安装"
        OS="unknown"
    fi
}

# 安装必要软件
install_dependencies() {
    print_info "安装必要软件..."
    
    if [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y nginx certbot python3-certbot-nginx cron
    elif [[ "$OS" == "redhat" ]]; then
        yum update -y
        yum install -y nginx certbot python3-certbot-nginx cronie
        systemctl enable crond
        systemctl start crond
    else
        print_error "请手动安装: nginx, certbot, python3-certbot-nginx"
        exit 1
    fi
    
    print_success "依赖软件安装完成"
}

# 读取配置
load_config() {
    # 从.env文件读取配置
    if [[ -f ".env" ]]; then
        source .env
        print_info "从.env文件加载配置"
    fi
    
    # 交互式输入域名（如果未设置）
    if [[ -z "$DOMAIN" ]]; then
        echo ""
        echo "🌐 请输入您的域名:"
        echo "示例: api.test.dpdns.org 或 test.dpdns.org"
        read -p "域名: " DOMAIN
        
        if [[ -z "$DOMAIN" ]]; then
            print_error "域名不能为空"
            exit 1
        fi
    fi
    
    # 输入邮箱（用于Let's Encrypt）
    if [[ -z "$CERT_EMAIL" ]] || [[ "$CERT_EMAIL" == "admin@example.com" ]]; then
        echo ""
        echo "📧 请输入您的邮箱地址（用于Let's Encrypt通知）:"
        read -p "邮箱: " CERT_EMAIL
        
        if [[ -z "$CERT_EMAIL" ]]; then
            print_error "邮箱地址不能为空"
            exit 1
        fi
    fi
    
    # 确认信息
    echo ""
    print_info "配置信息:"
    echo "  域名: $DOMAIN"
    echo "  邮箱: $CERT_EMAIL"
    echo "  API端口: ${PORT:-8080}"
    echo ""
    read -p "确认配置正确？[y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "配置取消"
        exit 1
    fi
}

# 创建nginx配置
create_nginx_config() {
    print_info "创建nginx配置..."
    
    local api_port=${PORT:-8080}
    
    cat > /etc/nginx/sites-available/api-management << EOF
# API管理系统 - nginx配置
server {
    listen 80;
    server_name $DOMAIN;
    
    # Let's Encrypt验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # 重定向到HTTPS（证书申请成功后启用）
    # location / {
    #     return 301 https://\$server_name\$request_uri;
    # }
    
    # 临时反向代理到API服务（证书申请期间）
    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# HTTPS配置（证书申请成功后启用）
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL证书路径（certbot会自动填充）
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 安全头部
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # 反向代理到API服务
    location / {
        proxy_pass http://127.0.0.1:$api_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/api-management /etc/nginx/sites-enabled/
    
    # 删除默认站点（如果存在）
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试nginx配置
    if nginx -t; then
        print_success "nginx配置创建成功"
    else
        print_error "nginx配置有误"
        exit 1
    fi
}

# 申请SSL证书
request_certificate() {
    print_info "申请SSL证书..."
    
    # 启动nginx
    systemctl start nginx
    systemctl enable nginx
    
    # 创建webroot目录
    mkdir -p /var/www/html
    
    # 使用certbot申请证书
    print_info "正在向Let's Encrypt申请证书..."
    
    if certbot certonly \
        --webroot \
        -w /var/www/html \
        -d "$DOMAIN" \
        --email "$CERT_EMAIL" \
        --agree-tos \
        --non-interactive \
        --staple-ocsp; then
        
        print_success "SSL证书申请成功！"
        
        # 使用certbot自动配置nginx
        if certbot --nginx -d "$DOMAIN" --non-interactive; then
            print_success "nginx SSL配置完成"
        else
            print_warning "自动配置nginx失败，请手动配置"
        fi
        
    else
        print_error "SSL证书申请失败"
        echo ""
        echo "可能的原因："
        echo "1. 域名DNS没有正确指向此服务器"
        echo "2. 防火墙阻止了80端口"
        echo "3. 网络连接问题"
        echo ""
        echo "请检查后重试"
        exit 1
    fi
}

# 设置证书自动更新
setup_auto_renewal() {
    print_info "设置证书自动更新..."
    
    # 添加到crontab
    local cron_cmd="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"
    
    # 检查crontab是否已存在该任务
    if crontab -l 2>/dev/null | grep -q "certbot renew"; then
        print_info "证书自动更新任务已存在"
    else
        (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
        print_success "证书自动更新任务已添加"
    fi
    
    # 测试续期
    print_info "测试证书续期..."
    if certbot renew --dry-run; then
        print_success "证书自动续期测试通过"
    else
        print_warning "证书续期测试失败，请检查配置"
    fi
}

# 更新环境变量
update_env_config() {
    print_info "更新环境变量配置..."
    
    # 备份原配置
    if [[ -f ".env" ]]; then
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # 更新.env文件
    cat >> .env << EOF

# SSL/HTTPS配置
DOMAIN=$DOMAIN
ENABLE_HTTPS=true
CERT_EMAIL=$CERT_EMAIL
SSL_CERT_PATH=/etc/letsencrypt/live

EOF

    print_success "环境变量配置已更新"
}

# 配置防火墙
setup_firewall() {
    print_info "配置防火墙..."
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu UFW
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw --force enable
        print_success "UFW防火墙配置完成"
        
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        print_success "firewalld防火墙配置完成"
        
    elif command -v iptables &> /dev/null; then
        # 通用iptables
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        print_success "iptables防火墙配置完成"
        
    else
        print_warning "未检测到防火墙，请手动开放80和443端口"
    fi
}

# 创建服务管理脚本
create_service_script() {
    print_info "创建服务管理脚本..."
    
    cat > /usr/local/bin/api-management << 'EOF'
#!/bin/bash

# API管理系统服务脚本
API_DIR="/opt/api-management"
API_USER="api"

case "$1" in
    start)
        echo "启动API管理系统..."
        cd $API_DIR
        sudo -u $API_USER python3 main.py --port 8080 &
        echo $! > /var/run/api-management.pid
        echo "✅ API管理系统已启动"
        ;;
    stop)
        echo "停止API管理系统..."
        if [[ -f /var/run/api-management.pid ]]; then
            kill $(cat /var/run/api-management.pid) 2>/dev/null || true
            rm -f /var/run/api-management.pid
        fi
        pkill -f "python3 main.py" || true
        echo "✅ API管理系统已停止"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if pgrep -f "python3 main.py" > /dev/null; then
            echo "✅ API管理系统正在运行"
        else
            echo "❌ API管理系统未运行"
        fi
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/api-management
    print_success "服务管理脚本已创建: /usr/local/bin/api-management"
}

# 显示完成信息
show_completion() {
    print_header
    print_success "🎉 SSL证书配置完成！"
    echo ""
    print_info "配置信息："
    echo "  🌐 域名: https://$DOMAIN"
    echo "  📧 邮箱: $CERT_EMAIL"
    echo "  🔐 证书路径: /etc/letsencrypt/live/$DOMAIN/"
    echo "  🔄 自动更新: 每天凌晨3点"
    echo ""
    print_info "管理命令："
    echo "  启动服务: api-management start"
    echo "  停止服务: api-management stop"
    echo "  重启服务: api-management restart"
    echo "  查看状态: api-management status"
    echo ""
    print_info "nginx管理："
    echo "  重启nginx: systemctl restart nginx"
    echo "  查看状态: systemctl status nginx"
    echo "  测试配置: nginx -t"
    echo ""
    print_info "证书管理："
    echo "  手动更新: certbot renew"
    echo "  查看证书: certbot certificates"
    echo "  测试更新: certbot renew --dry-run"
    echo ""
    print_warning "重要提示："
    echo "  1. 确保域名DNS已正确指向此服务器IP"
    echo "  2. 防火墙已开放80和443端口"
    echo "  3. 证书有效期90天，会自动续期"
    echo ""
    print_success "现在可以通过 https://$DOMAIN 访问您的API管理系统！"
}

# 主函数
main() {
    print_header
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_os
    
    # 安装依赖
    install_dependencies
    
    # 加载配置
    load_config
    
    # 创建nginx配置
    create_nginx_config
    
    # 申请证书
    request_certificate
    
    # 设置自动更新
    setup_auto_renewal
    
    # 更新环境变量
    update_env_config
    
    # 配置防火墙
    setup_firewall
    
    # 创建服务脚本
    create_service_script
    
    # 显示完成信息
    show_completion
}

# 检查是否直接运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 