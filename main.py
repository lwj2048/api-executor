from fastapi import FastAPI, Depends, HTTPException, Form, Request, Query
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, Dict, Any
import time
import json
import os
import argparse
import sys

from database import get_db, create_tables, APIDefinition, APIExecution, generate_api_key
from executor import APIExecutor
from config import settings
from auth import AuthManager, get_current_user, get_current_user_optional
import asyncio

# 创建FastAPI应用
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="强大的API定义和远程执行系统"
)

# 创建数据库表
create_tables()

# 定时清理过期会话 (使用asyncio后台任务)
async def cleanup_sessions_task():
    """异步定时清理过期会话"""
    while True:
        try:
            await asyncio.sleep(300)  # 等待5分钟
            AuthManager.cleanup_expired_sessions()
            print("✓ 已清理过期会话")
        except asyncio.CancelledError:
            print("✓ 会话清理任务已停止")
            break
        except Exception as e:
            print(f"✗ 清理会话失败: {e}")

# FastAPI生命周期事件
@app.on_event("startup")
async def startup_event():
    """应用启动时的初始化任务"""
    print("🔄 启动会话清理任务...")
    # 创建后台任务，5分钟后开始第一次清理
    asyncio.create_task(cleanup_sessions_task())

# 模板设置
templates = Jinja2Templates(directory="templates")

# 健康检查端点
@app.get("/health")
async def health_check():
    """健康检查端点，用于Docker和负载均衡器"""
    return {"status": "ok", "service": "api-management", "version": settings.APP_VERSION}

# Pydantic模型
class APIDefinitionCreate(BaseModel):
    name: str
    description: Optional[str] = ""
    endpoint_path: str
    action_type: str
    action_content: str
    parameters: Optional[Dict[str, str]] = {}

class APIDefinitionResponse(BaseModel):
    id: int
    name: str
    description: str
    api_key: str
    endpoint_path: str
    action_type: str
    is_active: bool
    execution_count: int

# 登录页面
@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    # 如果已经登录，重定向到主页
    current_user = await get_current_user_optional(request)
    if current_user:
        return RedirectResponse(url="/", status_code=302)
    
    return templates.TemplateResponse("login.html", {
        "request": request,
        "app_name": settings.APP_NAME
    })

# 登录处理
@app.post("/login")
async def login(request: Request, username: str = Form(...), password: str = Form(...)):
    if AuthManager.authenticate_user(username, password):
        session_id = AuthManager.create_session(username, request)
        response = JSONResponse({"success": True, "message": "登录成功"})
        response.set_cookie(
            key="session_id", 
            value=session_id, 
            max_age=15*60,  # 15分钟
            httponly=True,
            secure=False,  # 生产环境设置为True
            samesite="lax"
        )
        return response
    else:
        raise HTTPException(status_code=401, detail="用户名或密码错误")

# 登出
@app.post("/logout")
async def logout(request: Request):
    session_id = request.cookies.get("session_id")
    if session_id:
        AuthManager.logout_session(session_id)
    
    response = JSONResponse({"success": True, "message": "已登出"})
    response.delete_cookie("session_id")
    return response

# 主页 - 管理界面（需要登录）
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    # 检查是否已登录
    try:
        current_user = await get_current_user(request)
        return templates.TemplateResponse("index.html", {
            "request": request,
            "app_name": settings.APP_NAME,
            "current_user": current_user
        })
    except HTTPException:
        # 未登录，重定向到登录页面
        return RedirectResponse(url="/login", status_code=302)

# 获取所有API定义
@app.get("/api/definitions")
async def get_api_definitions(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    definitions = db.query(APIDefinition).all()
    return [
        {
            "id": d.id,
            "name": d.name,
            "description": d.description,
            "api_key": d.api_key,
            "endpoint_path": d.endpoint_path,
            "action_type": d.action_type,
            "is_active": d.is_active,
            "enable_logging": getattr(d, 'enable_logging', True),  # 兼容旧数据
            "execution_count": d.execution_count,
            "created_at": d.created_at.isoformat()
        }
        for d in definitions
    ]

# 创建API定义
@app.post("/api/definitions")
async def create_api_definition(
    name: str = Form(...),
    description: str = Form(""),
    endpoint_path: str = Form(...),
    action_type: str = Form(...),
    action_content: str = Form(...),
    parameters: str = Form("{}"),
    enable_logging: bool = Form(True),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    try:
        # 解析参数JSON
        param_dict = json.loads(parameters) if parameters else {}
        
        # 生成API密钥
        api_key = generate_api_key()
        
        # 创建API定义
        api_def = APIDefinition(
            name=name,
            description=description,
            api_key=api_key,
            endpoint_path=endpoint_path,
            action_type=action_type,
            action_content=action_content,
            parameters=param_dict,
            enable_logging=enable_logging
        )
        
        db.add(api_def)
        db.commit()
        db.refresh(api_def)
        
        return {
            "success": True,
            "message": "API定义创建成功",
            "api_key": api_key,
            "id": api_def.id
        }
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="参数格式错误，请使用有效的JSON格式")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建失败: {str(e)}")

# 获取单个API定义详情（用于编辑）
@app.get("/api/definitions/{definition_id}")
async def get_api_definition(definition_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    return {
        "id": api_def.id,
        "name": api_def.name,
        "description": api_def.description,
        "api_key": api_def.api_key,
        "endpoint_path": api_def.endpoint_path,
        "action_type": api_def.action_type,
        "action_content": api_def.action_content,
        "parameters": api_def.parameters,
        "is_active": api_def.is_active,
        "enable_logging": getattr(api_def, 'enable_logging', True),  # 兼容旧数据
        "execution_count": api_def.execution_count,
        "created_at": api_def.created_at.isoformat(),
        "updated_at": api_def.updated_at.isoformat()
    }

# 更新API定义
@app.put("/api/definitions/{definition_id}")
async def update_api_definition(
    definition_id: int,
    name: str = Form(...),
    description: str = Form(""),
    endpoint_path: str = Form(...),
    action_type: str = Form(...),
    action_content: str = Form(...),
    parameters: str = Form("{}"),
    enable_logging: bool = Form(True),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    try:
        # 解析参数JSON
        param_dict = json.loads(parameters) if parameters else {}
        
        # 查找API定义
        api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
        if not api_def:
            raise HTTPException(status_code=404, detail="API定义不存在")
        
        # 更新API定义
        api_def.name = name
        api_def.description = description
        api_def.endpoint_path = endpoint_path
        api_def.action_type = action_type
        api_def.action_content = action_content
        api_def.parameters = param_dict
        api_def.enable_logging = enable_logging
        
        db.commit()
        db.refresh(api_def)
        
        return {
            "success": True,
            "message": "API定义更新成功",
            "id": api_def.id
        }
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="参数格式错误，请使用有效的JSON格式")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"更新失败: {str(e)}")

# 删除API定义
@app.delete("/api/definitions/{definition_id}")
async def delete_api_definition(definition_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    db.delete(api_def)
    db.commit()
    return {"success": True, "message": "API定义删除成功"}

# 切换API状态
@app.put("/api/definitions/{definition_id}/toggle")
async def toggle_api_definition(definition_id: int, db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    api_def.is_active = not api_def.is_active
    db.commit()
    return {"success": True, "is_active": api_def.is_active}

# 执行API - 主要入口点
@app.get("/execute")
async def execute_api(
    request: Request,
    key: str = Query(..., description="API密钥"),
    db: Session = Depends(get_db)
):
    start_time = time.time()
    
    # 查找API定义
    api_def = db.query(APIDefinition).filter(APIDefinition.api_key == key).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="无效的API密钥")
    
    if not api_def.is_active:
        raise HTTPException(status_code=403, detail="API已被禁用")
    
    # 获取请求参数
    query_params = dict(request.query_params)
    query_params.pop("key", None)  # 移除key参数
    
    # 检查是否启用日志记录
    enable_logging = getattr(api_def, 'enable_logging', True)
    execution = None
    
    # 如果启用日志记录，则创建执行记录
    if enable_logging:
        execution = APIExecution(
            api_definition_id=api_def.id,
            api_key=key,
            parameters=query_params,
            status="running",
            request_ip=request.client.host if request.client else "unknown"
        )
        db.add(execution)
        db.commit()
    
    try:
        # 执行操作
        result, success, error_msg = APIExecutor.execute_action(
            api_def.action_type,
            api_def.action_content,
            query_params
        )
        
        # 计算执行时长
        duration_ms = int((time.time() - start_time) * 1000)
        
        # 如果启用日志记录，则更新执行记录
        if enable_logging and execution:
            execution.result = result
            execution.status = "success" if success else "error"
            execution.error_message = error_msg
            execution.duration_ms = duration_ms
        
        # 更新API定义的执行计数
        api_def.execution_count += 1
        
        db.commit()
        
        return {
            "success": success,
            "result": result,
            "error_message": error_msg,
            "execution_time": duration_ms,
            "api_name": api_def.name
        }
        
    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        
        # 如果启用日志记录，则更新执行记录
        if enable_logging and execution:
            execution.status = "error"
            execution.error_message = str(e)
            execution.duration_ms = duration_ms
            db.commit()
        
        raise HTTPException(status_code=500, detail=f"执行错误: {str(e)}")

# 获取执行历史
@app.get("/api/executions")
async def get_executions(
    limit: int = Query(50, description="返回数量限制"),
    api_key: Optional[str] = Query(None, description="按API密钥筛选"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    query = db.query(APIExecution)
    
    if api_key:
        query = query.filter(APIExecution.api_key == api_key)
    
    executions = query.order_by(APIExecution.execution_time.desc()).limit(limit).all()
    
    return [
        {
            "id": e.id,
            "api_key": e.api_key,
            "parameters": e.parameters,
            "result": e.result,
            "status": e.status,
            "execution_time": e.execution_time.isoformat(),
            "duration_ms": e.duration_ms,
            "error_message": e.error_message,
            "request_ip": e.request_ip
        }
        for e in executions
    ]

# 获取系统统计
@app.get("/api/stats")
async def get_stats(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    total_apis = db.query(APIDefinition).count()
    active_apis = db.query(APIDefinition).filter(APIDefinition.is_active == True).count()
    total_executions = db.query(APIExecution).count()
    successful_executions = db.query(APIExecution).filter(APIExecution.status == "success").count()
    
    return {
        "total_apis": total_apis,
        "active_apis": active_apis,
        "total_executions": total_executions,
        "successful_executions": successful_executions,
        "success_rate": round(successful_executions / total_executions * 100, 2) if total_executions > 0 else 0
    }

# 获取特定API的详细执行日志
@app.get("/api/definitions/{definition_id}/logs")
async def get_api_logs(
    definition_id: int,
    limit: int = Query(20, description="返回数量限制"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    # 验证API是否存在
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    # 获取执行记录
    executions = db.query(APIExecution).filter(
        APIExecution.api_definition_id == definition_id
    ).order_by(APIExecution.execution_time.desc()).limit(limit).all()
    
    return {
        "api_info": {
            "id": api_def.id,
            "name": api_def.name,
            "description": api_def.description,
            "endpoint_path": api_def.endpoint_path
        },
        "logs": [
            {
                "id": e.id,
                "execution_time": e.execution_time.isoformat(),
                "parameters": e.parameters,
                "result": e.result,
                "status": e.status,
                "duration_ms": e.duration_ms,
                "error_message": e.error_message,
                "request_ip": e.request_ip
            }
            for e in executions
        ]
    }

# 获取会话信息
@app.get("/api/session")
async def get_session_info(current_user: dict = Depends(get_current_user)):
    return {
        "username": current_user["username"],
        "login_time": current_user["created_at"].isoformat(),
        "last_activity": current_user["last_activity"].isoformat(),
        "ip_address": current_user["ip_address"]
    }

# 删除单个日志记录
@app.delete("/api/executions/{execution_id}")
async def delete_execution_log(
    execution_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    execution = db.query(APIExecution).filter(APIExecution.id == execution_id).first()
    if not execution:
        raise HTTPException(status_code=404, detail="日志记录不存在")
    
    db.delete(execution)
    db.commit()
    return {"success": True, "message": "日志记录删除成功"}

# 删除API的所有日志记录
@app.delete("/api/definitions/{definition_id}/logs")
async def delete_api_logs(
    definition_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    # 验证API是否存在
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    # 删除该API的所有执行记录
    deleted_count = db.query(APIExecution).filter(
        APIExecution.api_definition_id == definition_id
    ).delete()
    
    db.commit()
    return {
        "success": True, 
        "message": f"已删除 {deleted_count} 条日志记录",
        "deleted_count": deleted_count
    }

# 切换API的日志记录状态
@app.put("/api/definitions/{definition_id}/toggle-logging")
async def toggle_api_logging(
    definition_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    api_def = db.query(APIDefinition).filter(APIDefinition.id == definition_id).first()
    if not api_def:
        raise HTTPException(status_code=404, detail="API定义不存在")
    
    # 切换日志记录状态
    current_logging = getattr(api_def, 'enable_logging', True)
    api_def.enable_logging = not current_logging
    
    db.commit()
    return {
        "success": True, 
        "enable_logging": api_def.enable_logging,
        "message": f"日志记录已{'启用' if api_def.enable_logging else '禁用'}"
    }

if __name__ == "__main__":
    import uvicorn
    
    # 命令行参数解析
    parser = argparse.ArgumentParser(description='API定义管理系统')
    parser.add_argument('--port', '-p', type=int, 
                       default=settings.PORT,
                       help=f'服务端口号 (默认: {settings.PORT})')
    parser.add_argument('--host', type=str, 
                       default=settings.HOST,
                       help=f'服务主机地址 (默认: {settings.HOST})')
    parser.add_argument('--reload', action='store_true',
                       help='启用自动重载 (开发模式)')
    parser.add_argument('--ssl', action='store_true',
                       help='启用HTTPS/SSL (需要证书)')
    
    args = parser.parse_args()
    
    # 检查HTTPS配置
    use_ssl = args.ssl or settings.ENABLE_HTTPS
    ssl_keyfile = None
    ssl_certfile = None
    
    if use_ssl:
        # 构建证书路径
        if settings.DOMAIN:
            cert_dir = f"{settings.SSL_CERT_PATH}/{settings.DOMAIN}"
            ssl_certfile = f"{cert_dir}/fullchain.pem"
            ssl_keyfile = f"{cert_dir}/privkey.pem"
            
            # 检查证书文件是否存在
            if not (os.path.exists(ssl_certfile) and os.path.exists(ssl_keyfile)):
                print(f"❌ SSL证书文件不存在:")
                print(f"   证书: {ssl_certfile}")
                print(f"   密钥: {ssl_keyfile}")
                print(f"💡 请先运行SSL配置脚本: sudo ./scripts/setup_ssl.sh")
                sys.exit(1)
        else:
            print(f"❌ 启用HTTPS需要设置DOMAIN环境变量")
            sys.exit(1)
    
    # 显示启动信息
    protocol = "https" if use_ssl else "http"
    domain_info = f" ({settings.DOMAIN})" if settings.DOMAIN else ""
    
    print(f"🚀 启动API定义管理系统...")
    print(f"📡 监听地址: {protocol}://{args.host}:{args.port}{domain_info}")
    print(f"🔄 自动重载: {'启用' if args.reload else '禁用'}")
    print(f"🔐 HTTPS: {'启用' if use_ssl else '禁用'}")
    if use_ssl:
        print(f"📜 证书路径: {ssl_certfile}")
    print("=" * 50)
    
    # 启动服务
    uvicorn_config = {
        "host": args.host,
        "port": args.port,
        "reload": args.reload
    }
    
    # 添加SSL配置
    if use_ssl:
        uvicorn_config.update({
            "ssl_keyfile": ssl_keyfile,
            "ssl_certfile": ssl_certfile,
            "ssl_version": 3,  # TLS 1.2+
        })
    
    if args.reload:
        # 使用reload时需要传递模块字符串
        uvicorn.run("main:app", **uvicorn_config)
    else:
        # 不使用reload时可以直接传递app对象
        uvicorn.run(app, **uvicorn_config) 