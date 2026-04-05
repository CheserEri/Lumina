# Lumina

Lumina 是一个基于 Rust + Flutter 的 AI 聊天平台，提供优雅的 Web 界面与本地 Ollama 服务交互。

## 特性

- 🔐 用户注册/登录 (JWT + bcrypt)
- 💬 流式/非流式聊天 (SSE)
- 🎨 精美的 Claudelike 风格界面
- 📱 响应式设计，支持桌面和移动端
- 📂 聊天历史管理 (保存/查看/删除/重命名)
- 🔒 单端口部署，前后端统一

## 技术栈

| 层级 | 技术 |
|------|------|
| **后端** | Rust + Axum 0.8 + Tokio |
| **前端** | Flutter Web (Dart) |
| **认证** | JWT + bcrypt |
| **通信** | RESTful API + SSE 流式 |
| **AI** | Ollama 本地/远程服务 |

## 目录结构

```
Lumina/
├── backend/
│   ├── src/
│   │   ├── auth/           # 用户认证模块
│   │   ├── chat_history/   # 聊天历史管理
│   │   ├── config/         # 配置模块
│   │   ├── handlers/       # 请求处理器
│   │   ├── models/         # 数据模型
│   │   ├── ollama/         # Ollama 客户端
│   │   ├── routes/         # 路由定义
│   │   └── main.rs         # 应用入口
│   └── Cargo.toml
└── frontend/
    ├── lib/
    │   ├── main.dart        # 应用入口
    │   ├── screens/         # 页面 (登录/注册/聊天/历史)
    │   ├── services/        # API 服务
    │   ├── models/          # 数据模型
    │   ├── theme/           # 主题配置
    │   └── widgets/         # UI 组件
    └── pubspec.yaml
```

## 快速开始

### 前置条件

1. 安装 Rust (最新稳定版)
2. 安装 Flutter SDK
3. 运行中的 Ollama 服务 (默认端口 11434)

### 配置

编辑 `backend/src/config/mod.rs` 修改以下配置：

```rust
impl Default for AppConfig {
    fn default() -> Self {
        Self {
            ollama: OllamaConfig {
                // 修改为你的 Ollama 服务地址
                base_url: "http://192.168.x.x:11434".to_string(),
                timeout_secs: 300,
            },
            server: ServerConfig {
                host: "0.0.0.0".to_string(),
                port: 3000,
            },
            chat_history: ChatHistoryConfig {
                // 修改为聊天历史保存目录
                save_directory: "/tmp/lumina_chats".to_string(),
                auto_save: true,
                auto_save_interval: 300,
            },
        }
    }
}
```

### 构建前端

```bash
cd frontend
flutter pub get
flutter build web --release
```

### 部署前端到后端

```bash
cp -r frontend/build/web/* backend/target/release/web/
```

### 启动服务

```bash
cd backend
cargo run --release
```

服务器将在 `http://0.0.0.0:3000` 启动，浏览器访问即可。

### 预置管理员账号

- 用户名: `admin`
- 密码: `admin123`

## API 接口

### 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/register` | 用户注册 |
| POST | `/api/auth/login` | 用户登录 |

### 聊天

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/models` | 列出可用模型 |
| POST | `/api/chat` | 非流式聊天 |
| POST | `/api/chat/stream` | 流式聊天 (SSE) |

### 聊天历史

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/save_chat` | 保存聊天 |
| GET | `/api/saved_chats` | 获取保存列表 |
| POST | `/api/delete_chat` | 删除聊天 |
| POST | `/api/rename_chat` | 重命名聊天 |

### 注册请求示例

```json
POST /api/auth/register
{
  "username": "your_username",
  "email": "your@email.com",
  "password": "your_password"
}
```

### 登录请求示例

```json
POST /api/auth/login
{
  "username": "your_username",
  "password": "your_password"
}
```

### 登录响应

```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "username": "your_username",
  "email": "your@email.com"
}
```

### 聊天请求示例

```json
POST /api/chat
{
  "model": "gemma4:e4b",
  "messages": [
    {"role": "user", "content": "你好"}
  ],
  "stream": false
}
```

## 架构说明

### 单端口架构

```
客户端浏览器 → http://server:3000/ (Flutter Web)
                    ↓ (相对路径 /api/*)
              后端统一端口 (Axum)
              ├── /api/* → API 路由
              └── /*     → 静态文件服务
                    ↓ (内网通信)
              Ollama 服务
```

前端通过相对路径请求 API，所有请求都经过同一个端口。后端使用 `tower-http::ServeDir` 托管 Flutter Web 构建产物，API 路由优先匹配，未匹配的路由由静态文件服务处理。

### 安全特性

- 密码使用 bcrypt 哈希存储
- JWT Token 认证，7天有效期
- 单端口部署，API 不直接暴露
- Ollama 服务完全隐藏在服务器内部

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)
