mod config;
mod handlers;
mod models;
mod ollama;
mod routes;

use crate::config::AppConfig;
use crate::handlers::AppState;
use crate::ollama::client::OllamaClient;
use crate::routes::create_router;
use axum::http::Method;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
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

    let state = AppState {
        ollama: Arc::new(ollama_client),
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers(Any);

    let app = create_router(state).layer(cors);
    let addr = format!("{}:{}", config.server.host, config.server.port);
    tracing::info!("Server listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
