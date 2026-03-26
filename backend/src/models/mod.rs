use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OllamaModel {
    pub name: String,
    #[serde(rename = "modified_at")]
    pub modified_at: Option<String>,
    pub size: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OllamaTagsResponse {
    pub models: Vec<OllamaModel>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRequest {
    pub model: String,
    pub messages: Vec<ChatMessage>,
    #[serde(rename = "stream")]
    pub stream: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatResponse {
    pub model: String,
    pub message: ChatMessage,
    #[serde(rename = "done_reason")]
    pub done_reason: Option<String>,
    pub done: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamChunk {
    pub model: String,
    pub message: ChatMessage,
    #[serde(rename = "done_reason")]
    pub done_reason: Option<String>,
    pub done: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiError {
    pub error: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveChatRequest {
    pub model: String,
    pub messages: Vec<ChatMessage>,
    pub format: Option<String>, // 支持多种格式: markdown, json, txt
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveChatResponse {
    pub success: bool,
    pub file_path: Option<String>,
    pub message: Option<String>,
}
