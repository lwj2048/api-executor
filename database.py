from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, Boolean, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
from config import settings
import uuid

# 创建数据库引擎
engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

class APIDefinition(Base):
    __tablename__ = "api_definitions"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, index=True)
    description = Column(Text)
    api_key = Column(String(50), unique=True, nullable=False, index=True)
    endpoint_path = Column(String(200), nullable=False)
    action_type = Column(String(50), nullable=False)  # shell, http, python, etc.
    action_content = Column(Text, nullable=False)
    parameters = Column(JSON, default={})  # 支持的参数定义
    is_active = Column(Boolean, default=True)
    enable_logging = Column(Boolean, default=True)  # 控制是否记录执行日志
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    execution_count = Column(Integer, default=0)

class APIExecution(Base):
    __tablename__ = "api_executions"
    
    id = Column(Integer, primary_key=True, index=True)
    api_definition_id = Column(Integer, nullable=False, index=True)
    api_key = Column(String(50), nullable=False, index=True)
    parameters = Column(JSON, default={})
    result = Column(Text)
    status = Column(String(20), nullable=False)  # success, error, running
    execution_time = Column(DateTime, default=datetime.utcnow)
    duration_ms = Column(Integer)  # 执行时长(毫秒)
    error_message = Column(Text)
    request_ip = Column(String(50))

# 数据库依赖
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 创建表
def create_tables():
    Base.metadata.create_all(bind=engine)

# 生成API密钥
def generate_api_key():
    return str(uuid.uuid4()).replace('-', '')[:32] 