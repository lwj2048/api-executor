#!/bin/bash

# 设置默认端口
DEFAULT_PORT=8080

# 获取命令行参数
PORT=${1:-$DEFAULT_PORT}

echo "======================================"
echo "    API定义管理系统 启动脚本"
echo "======================================"

# 检查端口是否为有效数字
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "错误: 端口号必须是1-65535之间的数字"
    echo "用法: $0 [端口号]"
    echo "示例: $0 8080"
    exit 1
fi

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  警告: 端口 $PORT 已被占用"
    echo "正在使用的进程:"
    lsof -Pi :$PORT -sTCP:LISTEN
    echo ""
    read -p "是否继续启动? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "启动已取消"
        exit 1
    fi
fi

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到python3，请先安装Python 3.8+"
    exit 1
fi

# 检查pip是否安装
if ! command -v pip3 &> /dev/null; then
    echo "错误: 未找到pip3，请先安装pip"
    exit 1
fi

echo "正在安装依赖包..."
pip3 install -r requirements.txt

echo ""
echo "🚀 正在启动应用..."
echo "📡 访问地址: http://localhost:$PORT"
echo "🔧 使用端口: $PORT"
echo "⏹️  按 Ctrl+C 停止服务"
echo "======================================"

# 启动应用
python3 main.py --port $PORT --reload 