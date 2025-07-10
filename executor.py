import subprocess
import requests
import time
import json
import os
from typing import Dict, Any, Tuple
import tempfile

class APIExecutor:
    """API执行器，支持多种操作类型"""
    
    @staticmethod
    def execute_action(action_type: str, action_content: str, parameters: Dict[str, Any]) -> Tuple[str, bool, str]:
        """
        执行操作
        返回: (结果, 是否成功, 错误信息)
        """
        try:
            if action_type == "shell":
                return APIExecutor._execute_shell(action_content, parameters)
            elif action_type == "http":
                return APIExecutor._execute_http(action_content, parameters)
            elif action_type == "python":
                return APIExecutor._execute_python(action_content, parameters)
            elif action_type == "webhook":
                return APIExecutor._execute_webhook(action_content, parameters)
            else:
                return "", False, f"不支持的操作类型: {action_type}"
        except Exception as e:
            return "", False, f"执行错误: {str(e)}"
    
    @staticmethod
    def _execute_shell(command: str, parameters: Dict[str, Any]) -> Tuple[str, bool, str]:
        """执行Shell命令"""
        try:
            # 替换参数占位符
            for key, value in parameters.items():
                command = command.replace(f"{{{key}}}", str(value))
            
            # 安全检查 - 防止危险命令
            dangerous_commands = ['rm -rf', 'format', 'del', 'sudo rm', 'chmod 777']
            for dangerous in dangerous_commands:
                if dangerous in command.lower():
                    return "", False, f"检测到危险命令，执行被阻止: {dangerous}"
            
            # 检查是否是多行命令
            if '\n' in command.strip():
                # 多行命令：创建临时脚本文件执行
                with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
                    f.write("#!/bin/bash\n")
                    f.write("set -e\n")  # 遇到错误就退出
                    f.write(command)
                    temp_script = f.name
                
                try:
                    # 给脚本添加执行权限
                    os.chmod(temp_script, 0o755)
                    
                    # 执行脚本
                    result = subprocess.run(
                        ["/bin/bash", temp_script],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                finally:
                    # 清理临时文件
                    os.unlink(temp_script)
            else:
                # 单行命令：直接执行
                result = subprocess.run(
                    command, 
                    shell=True, 
                    capture_output=True, 
                    text=True, 
                    timeout=30
                )
            
            output = result.stdout + result.stderr
            success = result.returncode == 0
            error_msg = "" if success else f"命令执行失败，返回码: {result.returncode}"
            
            return output, success, error_msg
            
        except subprocess.TimeoutExpired:
            return "", False, "命令执行超时"
        except Exception as e:
            return "", False, f"Shell执行错误: {str(e)}"
    
    @staticmethod
    def _execute_http(config: str, parameters: Dict[str, Any]) -> Tuple[str, bool, str]:
        """执行HTTP请求"""
        try:
            # 解析HTTP配置
            http_config = json.loads(config)
            
            url = http_config.get("url", "")
            method = http_config.get("method", "GET").upper()
            headers = http_config.get("headers", {})
            data = http_config.get("data", {})
            
            # 替换参数占位符
            for key, value in parameters.items():
                url = url.replace(f"{{{key}}}", str(value))
                if isinstance(data, dict):
                    for data_key, data_value in data.items():
                        if isinstance(data_value, str):
                            data[data_key] = data_value.replace(f"{{{key}}}", str(value))
            
            # 发送请求
            response = requests.request(
                method=method,
                url=url,
                headers=headers,
                json=data if method in ["POST", "PUT", "PATCH"] else None,
                params=data if method == "GET" else None,
                timeout=30
            )
            
            result = {
                "status_code": response.status_code,
                "headers": dict(response.headers),
                "body": response.text
            }
            
            success = 200 <= response.status_code < 300
            error_msg = "" if success else f"HTTP请求失败，状态码: {response.status_code}"
            
            return json.dumps(result, ensure_ascii=False, indent=2), success, error_msg
            
        except json.JSONDecodeError:
            return "", False, "HTTP配置格式错误，请使用有效的JSON格式"
        except requests.RequestException as e:
            return "", False, f"HTTP请求错误: {str(e)}"
        except Exception as e:
            return "", False, f"HTTP执行错误: {str(e)}"
    
    @staticmethod
    def _execute_python(code: str, parameters: Dict[str, Any]) -> Tuple[str, bool, str]:
        """执行Python代码"""
        try:
            # 创建临时文件
            with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
                # 在代码前添加参数定义
                param_code = ""
                for key, value in parameters.items():
                    if isinstance(value, str):
                        param_code += f"{key} = '{value}'\n"
                    else:
                        param_code += f"{key} = {value}\n"
                
                f.write(param_code + "\n" + code)
                temp_file = f.name
            
            try:
                # 执行Python代码
                result = subprocess.run(
                    ["python", temp_file],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                output = result.stdout + result.stderr
                success = result.returncode == 0
                error_msg = "" if success else f"Python代码执行失败，返回码: {result.returncode}"
                
                return output, success, error_msg
                
            finally:
                # 清理临时文件
                os.unlink(temp_file)
                
        except subprocess.TimeoutExpired:
            return "", False, "Python代码执行超时"
        except Exception as e:
            return "", False, f"Python执行错误: {str(e)}"
    
    @staticmethod
    def _execute_webhook(config: str, parameters: Dict[str, Any]) -> Tuple[str, bool, str]:
        """执行Webhook调用"""
        try:
            # 解析Webhook配置
            webhook_config = json.loads(config)
            
            url = webhook_config.get("url", "")
            payload = webhook_config.get("payload", {})
            headers = webhook_config.get("headers", {"Content-Type": "application/json"})
            
            # 替换参数占位符
            for key, value in parameters.items():
                url = url.replace(f"{{{key}}}", str(value))
                payload = json.loads(json.dumps(payload).replace(f"{{{key}}}", str(value)))
            
            # 发送Webhook
            response = requests.post(
                url=url,
                json=payload,
                headers=headers,
                timeout=30
            )
            
            result = {
                "webhook_url": url,
                "status_code": response.status_code,
                "response": response.text
            }
            
            success = 200 <= response.status_code < 300
            error_msg = "" if success else f"Webhook调用失败，状态码: {response.status_code}"
            
            return json.dumps(result, ensure_ascii=False, indent=2), success, error_msg
            
        except json.JSONDecodeError:
            return "", False, "Webhook配置格式错误，请使用有效的JSON格式"
        except requests.RequestException as e:
            return "", False, f"Webhook请求错误: {str(e)}"
        except Exception as e:
            return "", False, f"Webhook执行错误: {str(e)}" 