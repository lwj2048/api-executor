# 🚀 API定义管理系统

一个强大且易用的API定义和远程执行系统，支持HTTP和HTTPS，提供Web界面管理API定义。

## 📋 功能特点

- 🔐 **安全认证** - JWT令牌认证，会话管理
- 📊 **API管理** - 在线创建、编辑、删除API定义
- 🚀 **远程执行** - 安全的API远程调用
- 📝 **执行日志** - 完整的API调用记录
- 🌐 **Web界面** - 现代化的管理界面
- 🔒 **HTTPS支持** - 自签名证书，快速启用SSL
- 🐳 **容器化** - Docker和Docker Compose支持

## ⚡ 快速开始

### 手动部署（推荐开发）

```bash
# 1. 配置环境变量
cp env.example .env
# 编辑.env文件设置数据库连接

# 2. HTTP模式启动
./start.sh

# 3. HTTPS模式启动
./start.sh https
```

### Docker Compose部署

```bash
# 1. HTTP模式
./docker-start.sh http

# 2. HTTPS模式
./docker-start.sh https

# 3. 包含PostgreSQL数据库
./docker-start.sh with-db
```

## 🔧 环境配置

### 必需配置

编辑 `.env` 文件：

```bash
# 数据库配置（必需）
SUPABASE_URL=postgresql://user:password@host:port/database

# 管理员账户
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password

# 安全密钥
SECRET_KEY=your-super-secret-key-change-in-production
```

### 可选配置

```bash
# 服务器配置
HOST=0.0.0.0
PORT=8080
DEBUG=false

# SSL配置
DOMAIN=localhost
ENABLE_HTTPS=false
SSL_CERT_PATH=~/.ssl
```

## 🔐 HTTPS配置

系统支持自签名SSL证书，适合测试和开发环境：

### 自动生成证书

启动脚本会自动检测并生成SSL证书：

```bash
# 启动时自动生成证书
./start.sh https
./docker-start.sh https
```

### 手动生成证书

```bash
# 手动生成自签名证书
./scripts/generate_cert.sh
```

### 浏览器安全警告

使用自签名证书时，浏览器会显示安全警告，这是正常现象：

1. 点击"高级"
2. 点击"继续前往localhost（不安全）"

## 🐳 Docker配置说明

### 服务组件

- **api**: FastAPI应用服务
- **nginx**: 反向代理服务器（支持HTTP/HTTPS）
- **postgres**: PostgreSQL数据库（可选）

### 启动模式

1. **http**: 仅HTTP访问
2. **https**: 启用HTTPS访问
3. **with-db**: 包含PostgreSQL数据库

### 数据库选择

- **外部数据库**: 在`.env`中配置`SUPABASE_URL`，不启动postgres服务
- **内置数据库**: 使用`with-db`模式，自动启动PostgreSQL容器

## 🌐 访问地址

### 手动部署
- **HTTP**: http://localhost:8080
- **HTTPS**: https://localhost:8080

### Docker Compose部署
- **HTTP**: http://localhost
- **HTTPS**: https://localhost

### 管理界面
- **用户名**: admin（可在.env中修改）
- **密码**: admin123（可在.env中修改）

## 📊 管理命令

### 手动部署

```bash
# 启动服务
./start.sh [http|https] [端口]

# 查看日志
tail -f app.log

# 停止服务
Ctrl+C
```

### Docker Compose

```bash
# 启动服务
./docker-start.sh [http|https|with-db]

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart
```

## 🛠️ 开发指南

### 本地开发

```bash
# 安装依赖
pip3 install -r requirements.txt

# 启动开发服务器
python3 main.py --reload

# 或使用启动脚本
./start.sh
```

### 项目结构

```
api/
├── main.py              # 主应用文件
├── config.py            # 配置管理
├── database.py          # 数据库模型
├── auth.py              # 认证模块
├── executor.py          # API执行器
├── templates/           # HTML模板
├── scripts/             # 工具脚本
├── nginx/               # nginx配置
├── start.sh            # 手动启动脚本
├── docker-start.sh     # Docker启动脚本
├── docker-compose.yml  # Docker Compose配置
└── requirements.txt    # Python依赖
```

## 🔒 安全说明

### 生产环境配置

1. **修改默认密码**: 更改管理员用户名和密码
2. **使用强密钥**: 生成强随机SECRET_KEY
3. **启用HTTPS**: 生产环境建议使用正式SSL证书
4. **数据库安全**: 使用强密码和安全连接

### 自签名证书说明

- **适用场景**: 开发、测试、内网环境
- **不适用场景**: 生产环境、公网访问
- **浏览器警告**: 正常现象，可安全忽略

## 📈 性能优化

### 生产环境建议

1. **使用nginx**: 提供静态文件服务和负载均衡
2. **数据库优化**: 配置连接池和索引
3. **日志管理**: 配置日志轮转
4. **监控**: 添加健康检查和监控

## 🤝 支持与贡献

如有问题或建议，欢迎提交Issue或Pull Request。

## 📄 许可证

MIT License - 详见 LICENSE 文件

---

**开始您的API管理之旅！** 🎉 