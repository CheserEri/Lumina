mod auth;
mod chat_history;
mod config;
mod handlers;
mod models;
mod ollama;
mod routes;

use crate::auth::AuthManager;
use crate::chat_history::ChatHistoryManager;
use crate::config::AppConfig;
use crate::handlers::AppState;
use crate::ollama::client::OllamaClient;
use crate::routes::create_router;
use axum::http::Method;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()),
        ))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = AppConfig::default();
    tracing::info!("Starting Lumina Server...");
    tracing::info!("Ollama endpoint: {}", config.ollama.base_url);

    let ollama_client = OllamaClient::new(
        config.ollama.base_url.clone(),
        config.ollama.timeout_secs,
    )?;

    let chat_history_manager = ChatHistoryManager::new(
        &config.chat_history.save_directory,
        config.chat_history.auto_save_interval,
    )?;

    let auth_manager = AuthManager::new();

    let state = AppState {
        ollama: Arc::new(ollama_client),
        chat_history: Arc::new(chat_history_manager),
        auth: Arc::new(auth_manager),
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers(Any);

    let api_router = create_router(state).layer(cors);

    let web_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.join("web")))
        .filter(|p| p.exists());

    let app = if let Some(web_dir) = web_dir {
        tracing::info!("Serving static files from: {:?}", web_dir);
        api_router.fallback_service(ServeDir::new(&web_dir))
    } else {
        tracing::warn!("No web directory found, serving API only");
        api_router
    };

    let addr = format!("{}:{}", config.server.host, config.server.port);
    tracing::info!("Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
