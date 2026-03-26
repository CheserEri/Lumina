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
├── backend/
│   ├── src/
│   │   ├── main.rs           # 应用入口
│   │   ├── config/           # 配置模块
│   │   ├── models/           # 数据模型
│   │   ├── ollama/           # Ollama 客户端
│   │   ├── handlers/         # 请求处理器
│   │   ├── routes/           # 路由定义
│   │   └── chat_history/     # 聊天历史管理
│   ├── Cargo.toml
│   └── Cargo.lock
└── frontend/
    ├── lib/
    │   ├── main.dart         # 应用入口
    │   ├── screens/          # 界面
    │   ├── services/         # API服务
    │   ├── models/           # 数据模型
    │   └── widgets/          # 组件
    └── pubspec.yaml
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
- `ChatHistoryConfig`: 聊天历史配置（保存目录、自动保存设置）
- 默认配置: Ollama 在 `http://localhost:11434`，服务器在 `0.0.0.0:8080`，聊天历史保存到 `E:\Code\History`

#### models/mod.rs
定义所有数据模型：
- `OllamaModel`: 模型信息（名称、修改时间、大小）
- `OllamaTagsResponse`: 模型列表响应
- `ChatMessage`: 聊天消息（角色、内容）
- `ChatRequest`: 聊天请求（模型、消息列表、是否流式）
- `ChatResponse`: 聊天响应
- `StreamChunk`: 流式响应块
- `ApiError`: API 错误响应
- `SaveChatRequest`: 保存聊天请求（模型、消息列表、格式）
- `SaveChatResponse`: 保存聊天响应（成功状态、文件路径、消息）

#### ollama/client.rs
Ollama HTTP 客户端，提供三个主要方法：
1. `list_models()`: 获取可用模型列表
2. `chat()`: 非流式聊天请求
3. `chat_streaming()`: 流式聊天请求，返回异步流

#### handlers/mod.rs
HTTP 请求处理器：
1. `list_models()`: 处理模型列表请求
2. `chat()`: 处理非流式聊天请求
3. `save_chat()`: 保存聊天内容到文件
4. `list_saved_chats()`: 获取保存的聊天列表
5. `delete_saved_chat()`: 删除保存的聊天文件
6. `rename_saved_chat()`: 重命名保存的聊天文件

#### routes/mod.rs
路由定义和流式聊天处理：
1. `/api/models` (GET): 列出模型
2. `/api/chat` (POST): 非流式聊天
3. `/api/chat/stream` (POST): 流式聊天（使用 Server-Sent Events）
4. `/api/save_chat` (POST): 保存聊天内容到文件
5. `/api/saved_chats` (GET): 获取保存的聊天列表
6. `/api/delete_chat` (POST): 删除保存的聊天文件
7. `/api/rename_chat` (POST): 重命名保存的聊天文件

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

### 4. 保存聊天内容
**端点**: `POST /api/save_chat`

**请求示例**:
```json
{
  "model": "llama2:latest",
  "messages": [
    {"role": "user", "content": "你好"},
    {"role": "assistant", "content": "你好！有什么我可以帮助你的吗？"}
  ],
  "format": "markdown"  // 可选: markdown, json, txt
}
```

**响应示例**:
```json
{
  "success": true,
  "file_path": "E:\\Code\\History\\chat_20260326_164221_llama2_latest.md",
  "message": "聊天历史已保存到: chat_20260326_164221_llama2_latest.md"
}
```

### 5. 获取保存的聊天列表
**端点**: `GET /api/saved_chats`

**响应示例**:
```json
{
  "success": true,
  "files": [
    "chat_20260326_164221_llama2_latest.md",
    "chat_20260326_164300_test.json"
  ],
  "save_directory": "E:\\Code\\History"
}
```

### 6. 删除保存的聊天
**端点**: `POST /api/delete_chat`

**请求示例**:
```json
{
  "filename": "chat_20260326_164221_llama2_latest.md"
}
```

**响应示例**:
```json
{
  "success": true,
  "file_path": null,
  "message": "文件已删除: chat_20260326_164221_llama2_latest.md"
}
```

### 7. 重命名保存的聊天
**端点**: `POST /api/rename_chat`

**请求示例**:
```json
{
  "old_name": "chat_20260326_164221_llama2_latest.md",
  "new_name": "my_first_chat.md"
}
```

**响应示例**:
```json
{
  "success": true,
  "file_path": "E:\\Code\\History\\my_first_chat.md",
  "message": "文件已重命名: chat_20260326_164221_llama2_latest.md -> my_first_chat.md"
}
```

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

聊天历史配置可在 `backend/src/config/mod.rs` 中修改：
```rust
pub struct ChatHistoryConfig {
    pub save_directory: String,    // 保存目录路径
    pub auto_save: bool,           // 是否启用自动保存
    pub auto_save_interval: u64,   // 自动保存间隔（秒）
}
```

默认配置：
- 保存目录: `E:\Code\History`
- 自动保存: 启用
- 自动保存间隔: 300秒（5分钟）

## 特性
- ✅ 异步高性能架构
- ✅ 支持流式和非流式聊天
- ✅ CORS 跨域支持
- ✅ 结构化日志
- ✅ 错误处理和状态码
- ✅ 类型安全的 API
- ✅ 聊天内容保存功能（支持 Markdown、JSON、TXT 格式）
- ✅ 自动保存聊天记录
- ✅ 聊天历史管理（查看、删除、重命名）
- ✅ 前端界面集成保存功能
- ✅ 性能优化（内存管理、ListView 优化）

## 聊天内容保存功能

### 功能说明
聊天内容保存功能允许用户将与 AI 的对话保存到本地文件，支持多种格式和自动保存。

### 文件格式
1. **Markdown 格式** (`.md`): 包含格式化的标题、模型信息和聊天内容
2. **JSON 格式** (`.json`): 结构化的数据格式，便于程序处理
3. **TXT 格式** (`.txt`): 纯文本格式，简单易读

### 保存位置
聊天记录默认保存到 `E:\Code\History` 目录，可在配置中修改。

### 使用方法
1. **手动保存**: 在聊天界面点击保存按钮
2. **自动保存**: 每10条消息自动保存一次
3. **历史管理**: 点击历史按钮查看、删除、重命名保存的文件

### 文件命名规则
保存的文件名格式：`chat_{时间戳}_{模型名}.{扩展名}`
例如：`chat_20260326_164221_llama2_latest.md`

## 性能优化

### 前端优化
1. **ListView.builder 优化**: 添加 `itemExtent` 属性提高滚动性能
2. **内存管理**: 限制消息列表最大为100条，自动清理旧消息
3. **自动保存**: 每10条消息自动保存一次，减少数据丢失风险

### 后端优化
1. **聊天历史管理**: 实现了完整的文件保存和管理功能
2. **配置管理**: 添加了聊天历史保存目录和自动保存配置
3. **错误处理**: 改进了错误处理和日志记录

### 后续优化建议
1. **连接池管理**: 考虑使用 `bb8` 或 `deadpool` 进行数据库连接池管理
2. **请求限流**: 添加请求限流中间件防止DDoS攻击
3. **缓存机制**: 实现模型列表缓存，减少对Ollama API的请求
4. **WebSocket 支持**: 考虑使用WebSocket替代SSE，提供更好的双向通信
