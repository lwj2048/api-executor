#!/bin/bash

# 进程调试和清理脚本
# 用于检查和清理API服务相关的进程

echo "🔍 API服务进程诊断工具"
echo "========================"

# 检查Python相关进程
echo "1. 检查Python进程..."
python_processes=$(ps aux | grep -E "(python|uvicorn)" | grep $(whoami) | grep -v grep)
if [ -n "$python_processes" ]; then
    echo "发现Python进程:"
    echo "$python_processes"
    echo ""
else
    echo "✅ 没有发现Python进程"
    echo ""
fi

# 检查特定端口占用
echo "2. 检查端口占用..."
for port in 8080 8000 8090; do
    port_info=$(netstat -tulpn 2>/dev/null | grep ":$port ")
    if [ -n "$port_info" ]; then
        echo "端口 $port 被占用:"
        echo "$port_info"
    else
        echo "✅ 端口 $port 空闲"
    fi
done
echo ""

# 检查multiprocessing相关进程
echo "3. 检查multiprocessing进程..."
mp_processes=$(ps aux | grep -E "(multiprocessing|spawn_main)" | grep -v grep)
if [ -n "$mp_processes" ]; then
    echo "⚠️ 发现multiprocessing进程:"
    echo "$mp_processes"
    echo ""
else
    echo "✅ 没有发现multiprocessing进程"
    echo ""
fi

# 检查API相关进程
echo "4. 检查API相关进程..."
api_processes=$(pgrep -f "main.py" -u $(whoami))
if [ -n "$api_processes" ]; then
    echo "发现API相关进程:"
    ps -p $api_processes -o pid,ppid,cmd
    echo ""
    
    # 提供清理选项
    read -p "是否要终止这些进程？[y/N]: " choice
    if [[ $choice == [Yy]* ]]; then
        echo "正在终止进程..."
        kill -TERM $api_processes
        sleep 2
        
        # 检查是否还有进程存在
        remaining=$(pgrep -f "main.py" -u $(whoami))
        if [ -n "$remaining" ]; then
            echo "强制终止剩余进程..."
            kill -KILL $remaining
        fi
        echo "✅ 进程清理完成"
    fi
else
    echo "✅ 没有发现API相关进程"
fi

echo ""
echo "🏁 诊断完成"
echo ""
echo "💡 如果发现问题，建议："
echo "   1. 使用 './start.sh' 或 './docker-start.sh' 启动服务"
echo "   2. 使用 Ctrl+C 正常关闭服务"
echo "   3. 避免使用 kill -9 强制终止进程" 