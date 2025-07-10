import os
from functools import lru_cache
from dotenv import load_dotenv

# 加载.env文件
load_dotenv()

class Settings:
    # 数据库配置 - 从环境变量读取
    DATABASE_URL = os.getenv(
        "SUPABASE_URL", 
        "postgresql://postgres:password@localhost:5432/api_management"
    )
    
    # 认证配置 - 从环境变量读取
    SECRET_KEY = os.getenv(
        "SECRET_KEY", 
        "your-secret-key-change-this-in-production-9876543210"
    )
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    
    # 管理员账户配置 - 从环境变量读取
    ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")
    
    # 应用设置
    APP_NAME = "API定义管理系统"
    APP_VERSION = "1.0.0"
    DEBUG = os.getenv("DEBUG", "false").lower() == "true"
    
    # 服务器配置
    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", "8080"))
    
    # SSL/HTTPS配置
    DOMAIN = os.getenv("DOMAIN", "")  # 域名，如: api.test.dpdns.org
    ENABLE_HTTPS = os.getenv("ENABLE_HTTPS", "false").lower() == "true"
    # SSL证书路径 - 默认使用用户家目录，避免需要root权限
    HOME_DIR = os.path.expanduser("~")
    SSL_CERT_PATH = os.getenv("SSL_CERT_PATH", f"{HOME_DIR}/.ssl/letsencrypt/live")
    CERT_EMAIL = os.getenv("CERT_EMAIL", "admin@example.com")  # Let's Encrypt邮箱

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings() 