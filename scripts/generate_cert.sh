#!/bin/bash

# 🔐 简化的自签名证书生成脚本
# ================================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

# 读取配置
DOMAIN=${DOMAIN:-localhost}
CERT_DIR="$HOME/.ssl"

print_info "生成自签名SSL证书..."
print_info "域名: $DOMAIN"

# 创建证书目录
mkdir -p "$CERT_DIR"

# 生成证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/C=CN/ST=Test/L=Test/O=Test/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,DNS:*.localhost,IP:127.0.0.1,IP:::1"

# 设置权限
chmod 600 "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/fullchain.pem"

print_success "SSL证书生成完成"
print_info "证书位置: $CERT_DIR/"
print_info "  私钥: privkey.pem"
print_info "  证书: fullchain.pem" 