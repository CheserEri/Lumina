use axum::{
    response::sse::{Event, Sse},
    routing::{get, post},
    Json, Router,
};
use futures_util::Stream;
use futures_util::StreamExt;

use crate::handlers::{chat, list_models, AppState};
use crate::models::ChatRequest;

pub fn create_router(state: AppState) -> Router {
    Router::new()
        .route("/api/models", get(list_models))
        .route("/api/chat", post(chat))
        .route("/api/chat/stream", post(stream_chat))
        .with_state(state)
}

pub async fn stream_chat(
    axum::extract::State(state): axum::extract::State<AppState>,
    Json(req): Json<ChatRequest>,
) -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let ollama = state.ollama.clone();
    let stream = async_stream::stream! {
        match ollama.chat_streaming(req).await {
            Ok(mut chunks) => {
                while let Some(result) = chunks.next().await {
                    match result {
                        Ok(chunk) => {
                            let data = serde_json::to_string(&chunk).unwrap_or_default();
                            yield Ok(Event::default().data(data));
                            if chunk.done {
                                break;
                            }
                        }
                        Err(e) => {
                            tracing::error!("Stream chunk error: {}", e);
                            let err: serde_json::Value = serde_json::json!({"error": e});
                            yield Ok(Event::default().data(err.to_string()));
                            break;
                        }
                    }
                }
            }
            Err(e) => {
                tracing::error!("Failed to start streaming: {}", e);
                let err: serde_json::Value = serde_json::json!({"error": e.to_string()});
                yield Ok(Event::default().data(err.to_string()));
            }
        }
    };

    Sse::new(stream)
}
