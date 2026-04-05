use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub ollama: OllamaConfig,
    pub server: ServerConfig,
    pub chat_history: ChatHistoryConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct OllamaConfig {
    pub base_url: String,
    pub timeout_secs: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ChatHistoryConfig {
    pub save_directory: String,
    pub auto_save: bool,
    pub auto_save_interval: u64, // 自动保存间隔（秒）
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            ollama: OllamaConfig {
                // 填写 Ollama 服务地址，如本地部署: "http://localhost:11434"
                // 或局域网地址: "http://192.168.x.x:11434"
                base_url: "http://192.168.x.x:11434".to_string(),
                timeout_secs: 300,
            },
            server: ServerConfig {
                host: "0.0.0.0".to_string(),
                port: 3000,
            },
            chat_history: ChatHistoryConfig {
                // 填写聊天历史保存目录路径
                save_directory: "/tmp/lumina_chats".to_string(),
                auto_save: true,
                auto_save_interval: 300, // 5分钟
            },
        }
    }
}
