use crate::models::{ChatMessage, ChatRequest, ChatResponse, OllamaTagsResponse, StreamChunk};
use anyhow::Result;
use futures_util::Stream;
use futures_util::StreamExt;
use reqwest::Client;
use std::pin::Pin;
use std::time::Duration;

#[derive(Clone)]
pub struct OllamaClient {
    http: Client,
    base_url: String,
}

impl OllamaClient {
    pub fn new(base_url: String, timeout_secs: u64) -> Result<Self> {
        let http = Client::builder()
            .timeout(Duration::from_secs(timeout_secs))
            .build()?;

        Ok(Self { http, base_url })
    }

    pub async fn list_models(&self) -> Result<OllamaTagsResponse> {
        let url = format!("{}/api/tags", self.base_url);
        let resp = self.http.get(&url).send().await?;
        let models = resp.json::<OllamaTagsResponse>().await?;
        Ok(models)
    }

    pub async fn chat(&self, request: ChatRequest) -> Result<ChatMessage> {
        let url = format!("{}/api/chat", self.base_url);
        let resp = self.http.post(&url).json(&request).send().await?;
        let chat_resp: ChatResponse = resp.json().await?;
        Ok(chat_resp.message)
    }

    pub async fn chat_streaming(
        &self,
        request: ChatRequest,
    ) -> Result<Pin<Box<dyn Stream<Item = Result<StreamChunk, String>> + Send>>> {
        let url = format!("{}/api/chat", self.base_url);
        let request = ChatRequest {
            stream: Some(true),
            ..request
        };
        let resp = self
            .http
            .post(&url)
            .json(&request)
            .send()
            .await?;
        
        let byte_stream = resp.bytes_stream();
        
        let stream = async_stream::stream! {
            let mut buffer = String::new();
            futures_util::pin_mut!(byte_stream);
            
            while let Some(chunk_result) = byte_stream.next().await {
                match chunk_result {
                    Ok(bytes) => {
                        let text = String::from_utf8_lossy(&bytes);
                        buffer.push_str(&text);
                        
                        // 按换行符分割处理
                        while let Some(newline_pos) = buffer.find('\n') {
                            let line = buffer[..newline_pos].trim().to_string();
                            buffer = buffer[newline_pos + 1..].to_string();
                            
                            if line.is_empty() {
                                continue;
                            }
                            
                            match serde_json::from_str::<StreamChunk>(&line) {
                                Ok(chunk) => yield Ok(chunk),
                                Err(e) => {
                                    tracing::warn!("Parse error: {} for line: {}", e, line);
                                }
                            }
                        }
                    }
                    Err(e) => {
                        yield Err(format!("Request error: {}", e));
                        break;
                    }
                }
            }
            
            // 处理缓冲区剩余数据
            let remaining = buffer.trim();
            if !remaining.is_empty() {
                match serde_json::from_str::<StreamChunk>(remaining) {
                    Ok(chunk) => yield Ok(chunk),
                    Err(e) => tracing::warn!("Final parse error: {} for: {}", e, remaining),
                }
            }
        };
        
        Ok(Box::pin(stream))
    }
}
