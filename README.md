# OpenCodeLumina

OpenCodeLumina 是一个基于 Rust 的 Ollama API 网关服务，提供简洁的 RESTful 接口来与本地运行的 Ollama 进行交互。

## 项目架构

### 技术栈
- **后端框架**: Axum 0.8 (基于 Tokio 异步运行时)
- **HTTP 客户端**: reqwest 0.12
- **序列化**: serde + serde_json
- **异步编程**: Tokio, async-stream
- **日志**: tracing + tracing-subscriber
- **CORS**: tower-http

### 目录结构
```
OpenCodeLumina/
└── backend/
    ├── src/
    │   ├── main.rs           # 应用入口
    │   ├── config/           # 配置模块
    │   ├── models/           # 数据模型
    │   ├── ollama/           # Ollama 客户端
    │   ├── handlers/         # 请求处理器
    │   └── routes/           # 路由定义
    ├── Cargo.toml
    └── Cargo.lock
```

## 工作流程

### 1. 应用启动流程
1. **初始化日志系统**: 使用 `tracing-subscriber` 配置日志
2. **加载配置**: 使用默认配置或从环境变量读取
3. **创建 Ollama 客户端**: 建立与 Ollama 服务的连接
4. **配置应用状态**: 使用 Arc 共享 Ollama 客户端
5. **配置 CORS**: 允许跨域请求
6. **创建路由**: 注册所有 API 端点
7. **启动服务器**: 在指定地址和端口监听请求

### 2. 核心模块说明

#### config/mod.rs
定义应用配置结构，包括：
- `OllamaConfig`: Ollama 服务配置（基础 URL、超时时间）
- `ServerConfig`: 服务器配置（主机、端口）
- 默认配置: Ollama 在 `http://localhost:11434`，服务器在 `0.0.0.0:8080`

#### models/mod.rs
定义所有数据模型：
- `OllamaModel`: 模型信息（名称、修改时间、大小）
- `OllamaTagsResponse`: 模型列表响应
- `ChatMessage`: 聊天消息（角色、内容）
- `ChatRequest`: 聊天请求（模型、消息列表、是否流式）
- `ChatResponse`: 聊天响应
- `StreamChunk`: 流式响应块
- `ApiError`: API 错误响应

#### ollama/client.rs
Ollama HTTP 客户端，提供三个主要方法：
1. `list_models()`: 获取可用模型列表
2. `chat()`: 非流式聊天请求
3. `chat_streaming()`: 流式聊天请求，返回异步流

#### handlers/mod.rs
HTTP 请求处理器：
1. `list_models()`: 处理模型列表请求
2. `chat()`: 处理非流式聊天请求

#### routes/mod.rs
路由定义和流式聊天处理：
1. `/api/models` (GET): 列出模型
2. `/api/chat` (POST): 非流式聊天
3. `/api/chat/stream` (POST): 流式聊天（使用 Server-Sent Events）

### 3. 请求处理流程

#### 列出模型流程
```
客户端 → GET /api/models 
       → routes::create_router 
       → handlers::list_models 
       → ollama::client::list_models 
       → Ollama API /api/tags 
       → 返回 JSON 响应
```

#### 非流式聊天流程
```
客户端 → POST /api/chat (JSON)
       → routes::create_router
       → handlers::chat
       → ollama::client::chat
       → Ollama API /api/chat
       → 返回完整响应
```

#### 流式聊天流程
```
客户端 → POST /api/chat/stream (JSON)
       → routes::stream_chat
       → ollama::client::chat_streaming
       → Ollama API /api/chat (stream=true)
       → 通过 SSE 逐块发送响应
       → 客户端逐步接收内容
```

## API 接口

### 1. 列出模型
**端点**: `GET /api/models`

**响应示例**:
```json
{
  "models": [
    {
      "name": "llama2:latest",
      "modified_at": "2024-01-01T00:00:00Z",
      "size": 3825819519
    }
  ]
}
```

### 2. 非流式聊天
**端点**: `POST /api/chat`

**请求示例**:
```json
{
  "model": "llama2:latest",
  "messages": [
    {"role": "user", "content": "你好"}
  ],
  "stream": false
}
```

**响应示例**:
```json
{
  "model": "",
  "message": {"role": "assistant", "content": "你好！有什么我可以帮助你的吗？"},
  "done_reason": null,
  "done": true
}
```

### 3. 流式聊天
**端点**: `POST /api/chat/stream`

**请求示例**: 同上

**响应**: Server-Sent Events 流式数据

## 运行项目

### 前置条件
1. 安装 Rust (最新稳定版)
2. 本地运行 Ollama 服务（默认端口 11434）

### 启动服务
```bash
cd backend
cargo run
```

服务器将在 `http://0.0.0.0:8080` 启动。

### 配置
可以通过环境变量修改日志级别:
```bash
RUST_LOG=debug cargo run
```

## 特性
- ✅ 异步高性能架构
- ✅ 支持流式和非流式聊天
- ✅ CORS 跨域支持
- ✅ 结构化日志
- ✅ 错误处理和状态码
- ✅ 类型安全的 API
