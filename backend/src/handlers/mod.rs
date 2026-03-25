use crate::models::{ApiError, ChatRequest, ChatResponse, OllamaTagsResponse};
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
