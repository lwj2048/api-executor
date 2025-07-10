from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
import secrets

from config import settings

# 密码加密
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 安全配置
security = HTTPBearer()

# 管理员账户配置（从环境变量读取）
# ⚠️ 安全警告: 生产环境请通过环境变量设置强密码
DEFAULT_ADMIN = {
    "username": settings.ADMIN_USERNAME,
    "password": settings.ADMIN_PASSWORD,
    "email": "admin@api-system.com"
}

# Session存储（生产环境建议使用Redis）
active_sessions = {}

class AuthManager:
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """验证密码"""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """生成密码哈希"""
        return pwd_context.hash(password)
    
    @staticmethod
    def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
        """创建访问令牌"""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=15)
        
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
        return encoded_jwt
    
    @staticmethod
    def verify_token(token: str) -> dict:
        """验证令牌"""
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            username = payload.get("sub")
            if username is None:
                raise HTTPException(status_code=401, detail="无效的认证令牌")
            return payload
        except JWTError:
            raise HTTPException(status_code=401, detail="无效的认证令牌")
    
    @staticmethod
    def authenticate_user(username: str, password: str) -> bool:
        """验证用户"""
        # 简单的用户验证（生产环境应该使用数据库）
        if username == DEFAULT_ADMIN["username"]:
            # 为了向后兼容，支持明文密码验证
            if password == DEFAULT_ADMIN["password"]:
                return True
            # 也支持哈希密码验证
            try:
                hashed_password = AuthManager.get_password_hash(DEFAULT_ADMIN["password"])
                return AuthManager.verify_password(password, hashed_password)
            except:
                return False
        return False
    
    @staticmethod
    def create_session(username: str, request: Request) -> str:
        """创建会话"""
        session_id = secrets.token_urlsafe(32)
        session_data = {
            "username": username,
            "created_at": datetime.utcnow(),
            "last_activity": datetime.utcnow(),
            "ip_address": request.client.host if request.client else "unknown",
            "user_agent": request.headers.get("user-agent", "unknown")
        }
        active_sessions[session_id] = session_data
        return session_id
    
    @staticmethod
    def validate_session(session_id: str, request: Request) -> dict:
        """验证会话"""
        if session_id not in active_sessions:
            raise HTTPException(status_code=401, detail="会话不存在，请重新登录")
        
        session = active_sessions[session_id]
        now = datetime.utcnow()
        
        # 检查会话是否过期（15分钟）
        if now - session["last_activity"] > timedelta(minutes=15):
            del active_sessions[session_id]
            raise HTTPException(status_code=401, detail="会话已过期，请重新登录")
        
        # 更新最后活动时间
        session["last_activity"] = now
        active_sessions[session_id] = session
        
        return session
    
    @staticmethod
    def logout_session(session_id: str):
        """登出会话"""
        if session_id in active_sessions:
            del active_sessions[session_id]
    
    @staticmethod
    def cleanup_expired_sessions():
        """清理过期会话"""
        now = datetime.utcnow()
        expired_sessions = []
        
        for session_id, session in active_sessions.items():
            if now - session["last_activity"] > timedelta(minutes=15):
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            del active_sessions[session_id]

# 依赖函数：验证当前用户
async def get_current_user(request: Request):
    """获取当前用户（通过session）"""
    session_id = request.cookies.get("session_id")
    if not session_id:
        raise HTTPException(status_code=401, detail="未登录，请先登录")
    
    session = AuthManager.validate_session(session_id, request)
    return session

# 可选的依赖函数：验证当前用户（允许未登录）
async def get_current_user_optional(request: Request):
    """获取当前用户（可选，允许未登录）"""
    try:
        return await get_current_user(request)
    except HTTPException:
        return None 