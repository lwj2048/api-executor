#!/bin/bash

# 🔍 SSL证书路径诊断脚本
# =========================

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

echo "🔍 SSL证书路径诊断"
echo "=================="

# 1. 显示环境信息
print_info "环境信息："
echo "  当前用户: $(whoami)"
echo "  HOME目录: $HOME"
echo "  当前目录: $(pwd)"
echo ""

# 2. 检查.env文件
print_info "检查.env文件："
if [[ -f ".env" ]]; then
    print_success ".env文件存在"
    source .env 2>/dev/null || true
    
    echo "  SSL_CERT_PATH=${SSL_CERT_PATH:-未设置}"
    echo "  DOMAIN=${DOMAIN:-未设置}"
    echo "  ENABLE_HTTPS=${ENABLE_HTTPS:-未设置}"
else
    print_warning ".env文件不存在"
fi
echo ""

# 3. 显示各种路径表示方式
print_info "路径展开测试："
echo "  \$HOME/.ssl = $HOME/.ssl"
echo "  ~/.ssl = $(eval echo ~/.ssl)"
echo "  SSL_CERT_PATH = ${SSL_CERT_PATH:-$HOME/.ssl}"

# 展开最终路径
FINAL_CERT_PATH="${SSL_CERT_PATH:-$HOME/.ssl}"
# 处理~开头的路径
if [[ "$FINAL_CERT_PATH" =~ ^~ ]]; then
    FINAL_CERT_PATH="${FINAL_CERT_PATH/#\~/$HOME}"
fi

echo "  最终证书路径 = $FINAL_CERT_PATH"
echo ""

# 4. 检查证书目录和文件
print_info "检查证书文件："
if [[ -d "$FINAL_CERT_PATH" ]]; then
    print_success "证书目录存在: $FINAL_CERT_PATH"
    ls -la "$FINAL_CERT_PATH"
    echo ""
    
    # 检查具体文件
    if [[ -f "$FINAL_CERT_PATH/fullchain.pem" ]]; then
        print_success "证书文件存在: fullchain.pem"
        echo "  文件大小: $(ls -lh "$FINAL_CERT_PATH/fullchain.pem" | awk '{print $5}')"
        echo "  修改时间: $(ls -l "$FINAL_CERT_PATH/fullchain.pem" | awk '{print $6, $7, $8}')"
    else
        print_error "证书文件不存在: $FINAL_CERT_PATH/fullchain.pem"
    fi
    
    if [[ -f "$FINAL_CERT_PATH/privkey.pem" ]]; then
        print_success "私钥文件存在: privkey.pem"
        echo "  文件大小: $(ls -lh "$FINAL_CERT_PATH/privkey.pem" | awk '{print $5}')"
        echo "  修改时间: $(ls -l "$FINAL_CERT_PATH/privkey.pem" | awk '{print $6, $7, $8}')"
    else
        print_error "私钥文件不存在: $FINAL_CERT_PATH/privkey.pem"
    fi
else
    print_error "证书目录不存在: $FINAL_CERT_PATH"
fi
echo ""

# 5. 检查权限
print_info "检查目录权限："
if [[ -d "$FINAL_CERT_PATH" ]]; then
    echo "  目录权限: $(ls -ld "$FINAL_CERT_PATH" | awk '{print $1}')"
    echo "  目录所有者: $(ls -ld "$FINAL_CERT_PATH" | awk '{print $3":"$4}')"
    
    if [[ -f "$FINAL_CERT_PATH/fullchain.pem" ]]; then
        echo "  证书权限: $(ls -l "$FINAL_CERT_PATH/fullchain.pem" | awk '{print $1}')"
    fi
    
    if [[ -f "$FINAL_CERT_PATH/privkey.pem" ]]; then
        echo "  私钥权限: $(ls -l "$FINAL_CERT_PATH/privkey.pem" | awk '{print $1}')"
    fi
else
    print_warning "无法检查权限，目录不存在"
fi
echo ""

# 6. 模拟程序检查
print_info "模拟程序检查逻辑："
echo "  程序会查找以下文件："
echo "  - 证书: $FINAL_CERT_PATH/fullchain.pem"
echo "  - 私钥: $FINAL_CERT_PATH/privkey.pem"

if [[ -f "$FINAL_CERT_PATH/fullchain.pem" ]] && [[ -f "$FINAL_CERT_PATH/privkey.pem" ]]; then
    print_success "程序检查：证书文件完整"
else
    print_error "程序检查：证书文件缺失"
fi
echo ""

# 7. 提供解决方案
print_info "解决方案："
if [[ ! -d "$FINAL_CERT_PATH" ]]; then
    echo "  1. 创建证书目录："
    echo "     mkdir -p \"$FINAL_CERT_PATH\""
fi

if [[ ! -f "$FINAL_CERT_PATH/fullchain.pem" ]] || [[ ! -f "$FINAL_CERT_PATH/privkey.pem" ]]; then
    echo "  2. 生成证书："
    echo "     ./scripts/generate_cert.sh"
    echo "     或者："
    echo "     DOMAIN=${DOMAIN:-localhost} ./scripts/generate_cert.sh"
fi

# 8. 显示当前所有.ssl目录
print_info "查找所有.ssl目录："
find $HOME -name ".ssl" -type d 2>/dev/null | while read dir; do
    echo "  找到: $dir"
    if [[ -f "$dir/fullchain.pem" ]] && [[ -f "$dir/privkey.pem" ]]; then
        print_success "    → 包含证书文件"
    else
        print_warning "    → 不包含证书文件"
    fi
done
echo ""

# 9. 环境变量修复建议
print_info "环境变量修复建议："
echo "  如果证书在其他位置，更新.env文件："
echo "  SSL_CERT_PATH=$FINAL_CERT_PATH"
echo ""

print_success "诊断完成！" 