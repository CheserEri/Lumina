use crate::auth::models::{LoginRequest, RegisterRequest};
use crate::chat_history::ChatHistoryManager;
use crate::models::{ApiError, ChatRequest, ChatResponse, OllamaTagsResponse, SaveChatRequest, SaveChatResponse};
use crate::ollama::client::OllamaClient;
use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub ollama: Arc<OllamaClient>,
    pub chat_history: Arc<ChatHistoryManager>,
    pub auth: Arc<crate::auth::AuthManager>,
}

pub async fn register(State(state): State<AppState>, Json(req): Json<RegisterRequest>) -> Response {
    match state.auth.register(req) {
        Ok(res) => (StatusCode::CREATED, Json(res)).into_response(),
        Err(e) => (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({ "error": e })),
        )
            .into_response(),
    }
}

pub async fn login(State(state): State<AppState>, Json(req): Json<LoginRequest>) -> Response {
    match state.auth.login(req) {
        Ok(res) => Json(res).into_response(),
        Err(e) => (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({ "error": e })),
        )
            .into_response(),
    }
}

pub async fn list_models(State(state): State<AppState>) -> Response {
    match state.ollama.list_models().await {
        Ok(models) => Json::<OllamaTagsResponse>(models).into_response(),
        Err(e) => {
            tracing::error!("Failed to list models: {}", e);
            (
                StatusCode::BAD_GATEWAY,
                Json(ApiError {
                    error: format!("Ollama unavailable: {}", e),
                }),
            )
                .into_response()
        }
    }
}

pub async fn chat(State(state): State<AppState>, Json(req): Json<ChatRequest>) -> Response {
    match state.ollama.chat(req).await {
        Ok(response) => Json(ChatResponse {
            model: String::new(),
            message: response,
            done_reason: None,
            done: true,
        })
        .into_response(),
        Err(e) => {
            tracing::error!("Chat error: {}", e);
            (
                StatusCode::BAD_GATEWAY,
                Json(ApiError {
                    error: format!("Chat failed: {}", e),
                }),
            )
                .into_response()
        }
    }
}

pub async fn save_chat(State(state): State<AppState>, Json(req): Json<SaveChatRequest>) -> Response {
    match state.chat_history.save_chat(&req) {
        Ok(response) => Json(response).into_response(),
        Err(e) => {
            tracing::error!("Save chat error: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some(format!("保存失败: {}", e)),
                }),
            )
                .into_response()
        }
    }
}

pub async fn list_saved_chats(State(state): State<AppState>) -> Response {
    match state.chat_history.list_saved_chats() {
        Ok(files) => Json(serde_json::json!({
            "success": true,
            "files": files,
            "save_directory": state.chat_history.get_save_directory().to_string_lossy()
        }))
        .into_response(),
        Err(e) => {
            tracing::error!("List saved chats error: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiError {
                    error: format!("获取保存的聊天列表失败: {}", e),
                }),
            )
                .into_response()
        }
    }
}

pub async fn delete_saved_chat(
    State(state): State<AppState>,
    Json(req): Json<serde_json::Value>,
) -> Response {
    let filename = match req["filename"].as_str() {
        Some(name) => name.to_string(),
        None => {
            return (
                StatusCode::BAD_REQUEST,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some("缺少文件名参数".to_string()),
                }),
            )
                .into_response()
        }
    };

    match state.chat_history.delete_chat(&filename) {
        Ok(response) => Json(response).into_response(),
        Err(e) => {
            tracing::error!("Delete chat error: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some(format!("删除失败: {}", e)),
                }),
            )
                .into_response()
        }
    }
}

pub async fn rename_saved_chat(
    State(state): State<AppState>,
    Json(req): Json<serde_json::Value>,
) -> Response {
    let old_name = match req["old_name"].as_str() {
        Some(name) => name.to_string(),
        None => {
            return (
                StatusCode::BAD_REQUEST,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some("缺少原文件名参数".to_string()),
                }),
            )
                .into_response()
        }
    };

    let new_name = match req["new_name"].as_str() {
        Some(name) => name.to_string(),
        None => {
            return (
                StatusCode::BAD_REQUEST,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some("缺少新文件名参数".to_string()),
                }),
            )
                .into_response()
        }
    };

    match state.chat_history.rename_chat(&old_name, &new_name) {
        Ok(response) => Json(response).into_response(),
        Err(e) => {
            tracing::error!("Rename chat error: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveChatResponse {
                    success: false,
                    file_path: None,
                    message: Some(format!("重命名失败: {}", e)),
                }),
            )
                .into_response()
        }
    }
}
