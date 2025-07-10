#!/bin/bash

# API定义管理系统 - GitHub部署脚本
# ====================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo ""
    echo "🚀 API定义管理系统 - GitHub部署向导"
    echo "=================================="
    echo ""
}

# 检查必要工具
check_requirements() {
    print_info "检查部署环境..."
    
    if ! command -v git &> /dev/null; then
        print_error "Git 未安装，请先安装 Git"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未安装，请先安装 Python3"
        exit 1
    fi
    
    print_success "环境检查通过"
}

# 检查.env文件
check_env_file() {
    print_info "检查环境变量配置..."
    
    if [ ! -f ".env" ]; then
        print_warning ".env 文件不存在，将从模板创建"
        if [ -f "env.example" ]; then
            cp env.example .env
            print_info "已创建 .env 文件，请编辑配置后重新运行此脚本"
            print_info "需要配置的变量："
            echo "  - SUPABASE_URL"
            echo "  - SECRET_KEY"
            echo "  - ADMIN_USERNAME"
            echo "  - ADMIN_PASSWORD"
            exit 1
        else
            print_error "env.example 模板文件不存在"
            exit 1
        fi
    fi
    
    print_success "环境配置文件检查完成"
}

# Git仓库初始化
init_git_repo() {
    print_info "初始化Git仓库..."
    
    if [ ! -d ".git" ]; then
        git init
        print_success "Git仓库初始化完成"
    else
        print_info "Git仓库已存在"
    fi
    
    # 添加所有文件
    git add .
    
    # 检查是否有变更需要提交
    if git diff --staged --quiet; then
        print_info "没有新的变更需要提交"
    else
        print_info "提交代码变更..."
        git commit -m "🚀 准备部署API管理系统到GitHub

- 📦 配置环境变量支持
- 🐳 添加Docker支持
- 🔧 GitHub Actions自动化部署
- 🔐 安全配置优化
- 📖 更新部署文档"
        print_success "代码提交完成"
    fi
}

# 显示GitHub配置说明
show_github_instructions() {
    print_header
    print_success "本地准备工作完成！"
    echo ""
    print_info "接下来请按以下步骤在GitHub上配置："
    echo ""
    echo "1. 📁 创建GitHub仓库"
    echo "   - 访问 https://github.com/new"
    echo "   - 创建新的仓库（可以是私有或公开）"
    echo "   - 不要初始化README、.gitignore或license"
    echo ""
    echo "2. 🔗 连接远程仓库"
    echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
    echo ""
    echo "3. 🔐 配置GitHub Secrets"
    echo "   进入仓库 → Settings → Secrets and variables → Actions"
    echo "   添加以下Secrets："
    echo ""
    echo "   📋 必需的Secrets："
    echo "   - SUPABASE_URL: 你的Supabase数据库连接URL"
    echo "   - SECRET_KEY: JWT加密密钥（强随机字符串）"
    echo "   - ADMIN_USERNAME: 管理员用户名"
    echo "   - ADMIN_PASSWORD: 管理员密码（建议使用强密码）"
    echo ""
    echo "   🐳 可选的Secrets（Docker部署）："
    echo "   - DOCKER_USERNAME: Docker Hub用户名"
    echo "   - DOCKER_PASSWORD: Docker Hub密码"
    echo ""
    echo "4. 🚀 自动部署"
    echo "   推送代码到main分支会自动触发部署流程"
    echo ""
    print_warning "重要提醒："
    echo "   - 请确保GitHub Secrets中的敏感信息安全"
    echo "   - 建议使用强密码和定期更换密钥"
    echo "   - 生产环境请启用HTTPS"
    echo ""
    print_success "部署向导完成！🎉"
}

# 主函数
main() {
    print_header
    
    # 检查环境
    check_requirements
    
    # 检查配置
    check_env_file
    
    # Git操作
    init_git_repo
    
    # 显示说明
    show_github_instructions
}

# 运行主函数
main 