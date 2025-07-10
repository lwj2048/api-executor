#!/bin/bash

echo "🚀 API定义管理系统 - 快速启动向导"
echo "=================================="

# 检查依赖
echo "📋 检查系统依赖..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python3，请先安装"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo "❌ 未找到 pip3，请先安装"
    exit 1
fi

echo "✅ 系统依赖检查通过"
echo ""

# 查找可用端口
echo "🔍 正在查找可用端口..."
if [ -f "check_port.py" ]; then
    AVAILABLE_PORTS=$(python3 check_port.py --range 8000 9999 2>/dev/null | grep -o '[0-9]\{4,5\}' | head -5)
    if [ ! -z "$AVAILABLE_PORTS" ]; then
        echo "✅ 找到可用端口:"
        echo "$AVAILABLE_PORTS" | nl -w2 -s'. '
        echo ""
        
        # 获取第一个可用端口
        RECOMMENDED_PORT=$(echo "$AVAILABLE_PORTS" | head -1)
        
        echo "💡 推荐端口: $RECOMMENDED_PORT"
        echo ""
        
        while true; do
            read -p "选择启动方式:
1) 使用推荐端口 ($RECOMMENDED_PORT)
2) 指定自定义端口
3) 查看帮助
4) 退出
请选择 [1-4]: " choice
            
            case $choice in
                1)
                    echo "🚀 启动系统 (端口: $RECOMMENDED_PORT)..."
                    ./start.sh $RECOMMENDED_PORT
                    break
                    ;;
                2)
                    read -p "请输入端口号 (1-65535): " custom_port
                    if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
                        echo "🚀 启动系统 (端口: $custom_port)..."
                        ./start.sh $custom_port
                        break
                    else
                        echo "❌ 无效的端口号，请重新输入"
                    fi
                    ;;
                3)
                    echo ""
                    echo "📖 启动方式说明:"
                    echo "   ./start.sh [端口]     - 使用启动脚本"
                    echo "   python3 main.py -p [端口] --reload  - 直接运行"
                    echo "   API_PORT=[端口] ./start.sh  - 环境变量方式"
                    echo ""
                    echo "🔧 端口检测工具:"
                    echo "   ./check_port.py       - 查找可用端口"
                    echo "   ./check_port.py -p [端口]  - 检查特定端口"
                    echo ""
                    ;;
                4)
                    echo "👋 已退出"
                    exit 0
                    ;;
                *)
                    echo "❌ 无效选择，请重新输入"
                    ;;
            esac
        done
    else
        echo "⚠️  未找到可用端口，请手动指定"
        read -p "请输入端口号: " manual_port
        ./start.sh $manual_port
    fi
else
    echo "⚠️  端口检测工具不可用，使用默认端口 9000"
    ./start.sh
fi 