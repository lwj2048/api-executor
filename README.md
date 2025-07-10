# API定义管理系统

一个功能强大的API定义和远程执行系统，支持通过Web界面创建和管理API，并通过简单的HTTP请求触发各种操作。

## 🚀 功能特点

- **🎨 美观的Web界面** - 响应式设计，支持移动设备
- **🔧 多种操作类型** - 支持Shell命令、HTTP请求、Python代码、Webhook调用
- **🔐 自动密钥生成** - 每个API自动生成唯一的访问密钥
- **📊 实时统计** - 显示API使用情况和执行统计
- **📝 执行历史** - 记录所有API执行的详细日志
- **⚡ 参数化支持** - 支持动态参数传递和替换
- **🛡️ 安全防护** - 内置危险命令检测和执行超时保护
- **🔑 用户认证** - 登录系统保护管理界面，15分钟会话超时
- **✏️ 在线编辑** - 支持API定义的在线编辑和更新
- **📋 详细日志** - 查看每个API的执行日志，包含来源IP和详细结果
- **🕐 会话管理** - 自动清理过期会话，支持登出功能

## 📋 环境要求

- Python 3.8+
- PostgreSQL数据库

## 🔧 端口配置

系统支持多种方式配置端口，解决端口占用问题：

### 📍 检测可用端口
```bash
# 自动查找可用端口
./check_port.py

# 检查特定端口
./check_port.py --port 8080

# 在指定范围查找
./check_port.py --range 3000 4000
```

### ⚙️ 设置端口的方法

1. **命令行参数（推荐）**：
   ```bash
   ./start.sh 8080           # 启动脚本指定端口
   python3 main.py -p 8080   # 直接运行指定端口
   ```

2. **环境变量**：
   ```bash
   export API_PORT=8080
   ./start.sh
   ```

3. **交互式处理**：
   启动脚本会自动检测端口占用并提示您选择

### 🚨 端口占用处理
- 启动时自动检测端口占用
- 显示占用进程信息
- 提供继续或取消选项
- 智能推荐可用端口

## ⚙️ 安装与配置

### 1. 克隆或下载项目文件

### 2. 配置环境变量

#### 🌍 环境变量配置

系统使用环境变量管理敏感配置，支持开发和生产环境：

```bash
# 复制环境变量模板
cp env.example .env

# 编辑环境变量
vim .env
```

**必需的环境变量**：
- `SUPABASE_URL` - Supabase数据库连接URL
- `SECRET_KEY` - JWT密钥（请使用强随机字符串）
- `ADMIN_USERNAME` - 管理员用户名
- `ADMIN_PASSWORD` - 管理员密码

**可选的环境变量**：
- `HOST` - 服务器监听地址（默认: 0.0.0.0）
- `PORT` - 服务器端口（默认: 8080）
- `DEBUG` - 调试模式（默认: false）

#### 📁 本地开发配置

```bash
# .env 文件示例
SUPABASE_URL=postgresql://postgres.your-project:your-password@your-host.pooler.supabase.com:5432/postgres
SECRET_KEY=your-super-secret-jwt-key-change-this-in-production
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
DEBUG=true
PORT=8080
```

### 3. 检查可用端口（可选）
```bash
# 查找可用端口
./check_port.py

# 检查特定端口是否可用
./check_port.py --port 8080
```

### 4. 安装依赖并启动
```bash
# 方式一：使用启动脚本（推荐）
./start.sh [端口号]

# 示例：
./start.sh           # 使用默认端口9000
./start.sh 8080      # 使用指定端口8080
./start.sh 3000      # 使用指定端口3000

# 方式二：直接运行Python程序
python3 main.py --port 8080 --reload

# 方式三：使用环境变量
export API_PORT=8080
python3 main.py --reload
```

### 5. 访问系统
打开浏览器访问：http://localhost:[您指定的端口]

**💡 快速体验：**
```bash
# 一键启动向导（推荐新手）
./quick_start.sh

# 或直接指定可用端口启动
./start.sh 8080
```

## 🔐 用户认证

### 默认登录信息
- **用户名**：`admin`
- **密码**：`admin123`

### 安全特性
- **会话超时**：15分钟无操作自动登出
- **自动清理**：系统每5分钟自动清理过期会话
- **访问保护**：所有管理功能需要登录后才能访问
- **IP记录**：记录所有操作的来源IP地址

### 🚀 GitHub部署配置

#### 🔐 GitHub Secrets设置

在GitHub仓库设置中添加以下Secrets：

| Secret名称 | 说明 | 示例值 |
|-----------|------|--------|
| `SUPABASE_URL` | Supabase数据库连接URL | `postgresql://postgres.xxx:xxx@xxx.pooler.supabase.com:5432/postgres` |
| `SECRET_KEY` | JWT加密密钥 | `your-super-secret-jwt-key-64-chars-long` |
| `ADMIN_USERNAME` | 管理员用户名 | `admin` |
| `ADMIN_PASSWORD` | 管理员密码 | `your-secure-password` |

**可选Secrets**（Docker部署需要）：
- `DOCKER_USERNAME` - Docker Hub用户名
- `DOCKER_PASSWORD` - Docker Hub密码

#### 📋 设置步骤

1. 进入GitHub仓库页面
2. 点击 "Settings" → "Secrets and variables" → "Actions"
3. 点击 "New repository secret"
4. 依次添加上述环境变量

#### 🔄 自动化部署

推送到 `main` 分支会自动触发：
- ✅ 代码语法检查
- 🚀 自动部署到生产环境
- 🐳 构建Docker镜像（可选）

### 🐳 Docker部署

#### 本地Docker运行
```bash
# 构建镜像
docker build -t api-management .

# 运行容器
docker run -d \
  --name api-management \
  -p 8080:8080 \
  -e SUPABASE_URL="your-supabase-url" \
  -e SECRET_KEY="your-secret-key" \
  -e ADMIN_USERNAME="admin" \
  -e ADMIN_PASSWORD="your-password" \
  api-management
```

#### Docker Compose
```yaml
# docker-compose.yml
version: '3.8'
services:
  api-management:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
      - ADMIN_USERNAME=${ADMIN_USERNAME}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
    restart: unless-stopped
```

### 生产环境安全建议

⚠️ **重要安全提醒**：

1. **🔐 强密码策略**：
   - 管理员密码至少12位
   - 包含大小写字母、数字、特殊字符
   - 定期更换密码

2. **🛡️ 网络安全**：
   - 启用HTTPS（推荐使用nginx反向代理）
   - 配置防火墙限制访问
   - 使用VPN或IP白名单

3. **🔑 密钥管理**：
   - SECRET_KEY使用64位随机字符串
   - 定期轮换API密钥
   - 监控异常访问

4. **📊 监控告警**：
   - 设置日志监控
   - 配置异常登录告警
   - 定期备份数据库

### 初始登录信息
- **开发环境默认账户**：`admin` / `admin123`
- **生产环境**：请修改 `auth.py` 文件中的默认配置

## 📖 使用说明

### 登录系统

1. 访问系统URL，自动跳转到登录页面
2. 输入用户名 `admin` 和密码 `admin123`
3. 登录成功后进入管理界面

### 创建API

1. 在Web界面左侧填写API信息：
   - **API名称**：为你的API起一个描述性名称
   - **描述**：详细说明API的用途
   - **端点路径**：API的访问路径（如：/deploy-app）
   - **操作类型**：选择要执行的操作类型
   - **操作内容**：具体的操作代码或配置
   - **参数定义**：定义API支持的参数

2. 点击"创建API"按钮

3. 系统会生成唯一的API密钥，请妥善保存

### 管理API

在API列表中，每个API提供以下操作：

- **📋 查看日志**：查看API的详细执行历史，包括：
  - 执行时间和来源IP
  - 请求参数和返回结果
  - 执行状态和耗时
  - 错误信息（如果有）

- **🔑 查看密钥**：显示API密钥和使用示例

- **✏️ 编辑**：修改API定义，包括：
  - 更新API名称和描述
  - 修改操作内容
  - 调整参数定义
  - 更改操作类型

- **🔄 启用/禁用**：切换API的启用状态

- **🗑️ 删除**：永久删除API定义

### 操作类型说明

#### 1. Shell命令
执行Linux/Unix Shell命令：
```bash
echo "Hello {name}!"
ls -la
ping -c 3 {host}
```

#### 2. HTTP请求
发送HTTP请求到其他服务：
```json
{
  "url": "https://api.example.com/data",
  "method": "POST",
  "headers": {"Content-Type": "application/json"},
  "data": {"message": "Hello from {name}"}
}
```

#### 3. Python代码
执行Python脚本：
```python
print(f"Hello {name}!")
import requests
response = requests.get(f"https://api.github.com/users/{username}")
print(response.json())
```

#### 4. Webhook调用
发送Webhook通知：
```json
{
  "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
  "payload": {"text": "任务完成: {task_name}"},
  "headers": {"Content-Type": "application/json"}
}
```

### 调用API

使用curl或任何HTTP客户端调用API：

```bash
# 基本调用
curl "http://your-domain.com/execute?key=YOUR_API_KEY"

# 带参数调用
curl "http://your-domain.com/execute?key=YOUR_API_KEY&name=张三&host=google.com"

# POST方式（也支持）
curl -X POST "http://your-domain.com/execute" \
  -d "key=YOUR_API_KEY&name=张三&host=google.com"
```

### 参数化功能

在操作内容中使用 `{参数名}` 的格式定义参数占位符：

- Shell: `echo "Hello {name}!"`
- HTTP: `"url": "https://api.example.com/users/{user_id}"`
- Python: `print(f"Processing {task_id}")`

调用时传递对应参数：
```bash
curl "http://localhost:9000/execute?key=YOUR_KEY&name=张三&user_id=123&task_id=456"
```

## 🛡️ 安全特性

- **危险命令检测**：自动阻止 `rm -rf`、`format` 等危险命令
- **执行超时**：所有操作都有30秒的超时限制
- **参数验证**：对输入参数进行安全检查
- **访问日志**：记录所有API调用的详细信息

## 🔧 系统管理

### Web界面功能

- **API列表**：查看所有已创建的API
- **状态切换**：启用/禁用API
- **执行统计**：查看API调用次数和成功率
- **执行历史**：查看详细的执行日志
- **参数管理**：管理API支持的参数

### API端点

- `GET /` - Web管理界面
- `GET /execute?key=API_KEY` - 执行API
- `GET /api/definitions` - 获取API列表
- `POST /api/definitions` - 创建API
- `DELETE /api/definitions/{id}` - 删除API
- `PUT /api/definitions/{id}/toggle` - 切换API状态
- `GET /api/executions` - 获取执行历史
- `GET /api/stats` - 获取系统统计

## 📝 使用示例

### 示例1：服务器监控
```bash
# 创建系统状态检查API
# 操作类型：Shell
# 操作内容：
df -h
free -m
uptime
ps aux --sort=-%cpu | head -10

# 调用：
curl "http://localhost:9000/execute?key=YOUR_KEY"
```

### 示例2：自动部署
```bash
# 创建应用部署API
# 操作类型：Shell
# 操作内容：
cd /path/to/app
git pull origin {branch}
npm install
npm run build
pm2 restart {app_name}

# 调用：
curl "http://localhost:9000/execute?key=YOUR_KEY&branch=main&app_name=myapp"
```

### 示例3：发送通知
```json
// 创建Slack通知API
// 操作类型：Webhook
// 操作内容：
{
  "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
  "payload": {
    "text": "🚀 部署完成！",
    "attachments": [
      {
        "color": "good",
        "fields": [
          {"title": "项目", "value": "{project}", "short": true},
          {"title": "版本", "value": "{version}", "short": true}
        ]
      }
    ]
  }
}
```

## 🚀 生产环境部署

### 1. 使用反向代理
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. 使用进程管理器
```bash
# 使用PM2管理进程
npm install -g pm2
pm2 start "python3 -m uvicorn main:app --host 0.0.0.0 --port 9000" --name api-system
pm2 save
pm2 startup
```

### 3. 环境变量配置
建议在生产环境中修改 `config.py` 中的安全设置：
- 更改 `SECRET_KEY`
- 设置 `DEBUG = False`
- 配置HTTPS

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

---

**享受你的API管理之旅！** 🎉 