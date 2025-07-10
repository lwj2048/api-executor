#!/usr/bin/env python3
"""
端口检测工具 - 帮助找到可用端口
"""

import socket
import argparse

def is_port_available(port, host='localhost'):
    """检查指定端口是否可用"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            result = sock.connect_ex((host, port))
            return result != 0
    except Exception:
        return False

def find_available_port(start_port=8000, end_port=9999, host='localhost'):
    """在指定范围内查找可用端口"""
    available_ports = []
    
    print(f"🔍 正在检测端口范围 {start_port}-{end_port}...")
    
    for port in range(start_port, end_port + 1):
        if is_port_available(port, host):
            available_ports.append(port)
            if len(available_ports) >= 10:  # 最多显示10个可用端口
                break
    
    return available_ports

def main():
    parser = argparse.ArgumentParser(description='端口检测工具')
    parser.add_argument('--port', '-p', type=int, help='检测指定端口是否可用')
    parser.add_argument('--range', '-r', nargs=2, type=int, metavar=('START', 'END'),
                       default=[8000, 9999], help='检测端口范围 (默认: 8000 9999)')
    parser.add_argument('--host', type=str, default='localhost', 
                       help='检测的主机地址 (默认: localhost)')
    
    args = parser.parse_args()
    
    if args.port:
        # 检测单个端口
        if is_port_available(args.port, args.host):
            print(f"✅ 端口 {args.port} 可用")
            return 0
        else:
            print(f"❌ 端口 {args.port} 已被占用")
            return 1
    else:
        # 查找可用端口
        start_port, end_port = args.range
        available_ports = find_available_port(start_port, end_port, args.host)
        
        if available_ports:
            print(f"\n✅ 找到 {len(available_ports)} 个可用端口:")
            for i, port in enumerate(available_ports, 1):
                print(f"  {i}. {port}")
            
            print(f"\n💡 推荐使用端口: {available_ports[0]}")
            print(f"启动命令: ./start.sh {available_ports[0]}")
        else:
            print(f"❌ 在范围 {start_port}-{end_port} 内未找到可用端口")
            return 1
    
    return 0

if __name__ == "__main__":
    exit(main()) 