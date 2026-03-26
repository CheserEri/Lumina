use crate::models::{SaveChatRequest, SaveChatResponse};
use anyhow::{Context, Result};
use chrono::Local;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::Instant;

pub struct ChatHistoryManager {
    save_directory: PathBuf,
    last_auto_save: Mutex<Instant>,
    auto_save_interval: u64,
}

impl ChatHistoryManager {
    pub fn new(save_directory: &str, auto_save_interval: u64) -> Result<Self> {
        let path = PathBuf::from(save_directory);

        // 确保目录存在
        if !path.exists() {
            fs::create_dir_all(&path).context(format!("无法创建保存目录: {:?}", path))?;
            tracing::info!("创建聊天历史保存目录: {:?}", path);
        }

        Ok(Self {
            save_directory: path,
            last_auto_save: Mutex::new(Instant::now()),
            auto_save_interval,
        })
    }

    pub fn should_auto_save(&self) -> bool {
        let last_save = self.last_auto_save.lock().unwrap();
        last_save.elapsed().as_secs() >= self.auto_save_interval
    }

    pub fn update_last_auto_save(&self) {
        let mut last_save = self.last_auto_save.lock().unwrap();
        *last_save = Instant::now();
    }

    pub fn save_chat(&self, request: &SaveChatRequest) -> Result<SaveChatResponse> {
        let timestamp = Local::now().format("%Y%m%d_%H%M%S");
        let model_name = request.model.replace(':', "_").replace('/', "_");

        // 根据格式选择扩展名和内容
        let format = request.format.as_deref().unwrap_or("markdown");
        let (extension, content) = match format {
            "json" => {
                let filename = format!("chat_{}_{}.json", timestamp, model_name);
                (
                    filename,
                    self.generate_json_content(request, &timestamp.to_string()),
                )
            }
            "txt" => {
                let filename = format!("chat_{}_{}.txt", timestamp, model_name);
                (
                    filename,
                    self.generate_txt_content(request, &timestamp.to_string()),
                )
            }
            _ => {
                // 默认为markdown
                let filename = format!("chat_{}_{}.md", timestamp, model_name);
                (
                    filename,
                    self.generate_markdown_content(request, &timestamp.to_string()),
                )
            }
        };

        let file_path = self.save_directory.join(&extension);

        // 写入文件
        fs::write(&file_path, content).context(format!("无法写入文件: {:?}", file_path))?;

        tracing::info!("聊天历史已保存到: {:?}", file_path);

        Ok(SaveChatResponse {
            success: true,
            file_path: Some(file_path.to_string_lossy().to_string()),
            message: Some(format!("聊天历史已保存到: {}", extension)),
        })
    }

    fn generate_markdown_content(&self, request: &SaveChatRequest, timestamp: &str) -> String {
        let mut content = String::new();

        // 标题
        content.push_str(&format!("# 聊天记录 - {}\n\n", timestamp));

        // 模型信息
        content.push_str(&format!("**模型**: {}\n", request.model));
        content.push_str(&format!(
            "**保存时间**: {}\n\n",
            Local::now().format("%Y-%m-%d %H:%M:%S")
        ));

        // 分隔线
        content.push_str("---\n\n");

        // 聊天内容
        for message in &request.messages {
            match message.role.as_str() {
                "user" => {
                    content.push_str("## 用户\n\n");
                    content.push_str(&format!("{}\n\n", message.content));
                }
                "assistant" => {
                    content.push_str("## AI助手\n\n");
                    content.push_str(&format!("{}\n\n", message.content));
                }
                _ => {
                    content.push_str(&format!("## {}\n\n", message.role));
                    content.push_str(&format!("{}\n\n", message.content));
                }
            }
            content.push_str("---\n\n");
        }

        content
    }

    fn generate_json_content(&self, request: &SaveChatRequest, timestamp: &str) -> String {
        let json_data = serde_json::json!({
            "timestamp": timestamp,
            "model": request.model,
            "save_time": Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
            "messages": request.messages
        });

        serde_json::to_string_pretty(&json_data).unwrap_or_default()
    }

    fn generate_txt_content(&self, request: &SaveChatRequest, timestamp: &str) -> String {
        let mut content = String::new();

        content.push_str(&format!("聊天记录 - {}\n", timestamp));
        content.push_str(&format!("模型: {}\n", request.model));
        content.push_str(&format!(
            "保存时间: {}\n\n",
            Local::now().format("%Y-%m-%d %H:%M:%S")
        ));
        content.push_str("=".repeat(50).as_str());
        content.push_str("\n\n");

        for message in &request.messages {
            match message.role.as_str() {
                "user" => {
                    content.push_str("用户:\n");
                    content.push_str(&format!("{}\n\n", message.content));
                }
                "assistant" => {
                    content.push_str("AI助手:\n");
                    content.push_str(&format!("{}\n\n", message.content));
                }
                _ => {
                    content.push_str(&format!("{}:\n", message.role));
                    content.push_str(&format!("{}\n\n", message.content));
                }
            }
            content.push_str("-".repeat(50).as_str());
            content.push_str("\n\n");
        }

        content
    }

    pub fn list_saved_chats(&self) -> Result<Vec<String>> {
        let mut files = Vec::new();

        if !self.save_directory.exists() {
            return Ok(files);
        }

        for entry in fs::read_dir(&self.save_directory)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_file() {
                if let Some(ext) = path.extension() {
                    if ext == "md" {
                        if let Some(name) = path.file_name() {
                            files.push(name.to_string_lossy().to_string());
                        }
                    }
                }
            }
        }

        files.sort();
        files.reverse(); // 最新的文件在前

        Ok(files)
    }

    pub fn get_save_directory(&self) -> &Path {
        &self.save_directory
    }

    pub fn delete_chat(&self, filename: &str) -> Result<SaveChatResponse> {
        let file_path = self.save_directory.join(filename);

        if !file_path.exists() {
            return Ok(SaveChatResponse {
                success: false,
                file_path: None,
                message: Some(format!("文件不存在: {}", filename)),
            });
        }

        fs::remove_file(&file_path).context(format!("无法删除文件: {:?}", file_path))?;

        tracing::info!("聊天历史已删除: {:?}", file_path);

        Ok(SaveChatResponse {
            success: true,
            file_path: None,
            message: Some(format!("文件已删除: {}", filename)),
        })
    }

    pub fn rename_chat(&self, old_name: &str, new_name: &str) -> Result<SaveChatResponse> {
        let old_path = self.save_directory.join(old_name);
        let new_path = self.save_directory.join(new_name);

        if !old_path.exists() {
            return Ok(SaveChatResponse {
                success: false,
                file_path: None,
                message: Some(format!("文件不存在: {}", old_name)),
            });
        }

        if new_path.exists() {
            return Ok(SaveChatResponse {
                success: false,
                file_path: None,
                message: Some(format!("目标文件已存在: {}", new_name)),
            });
        }

        fs::rename(&old_path, &new_path)
            .context(format!("无法重命名文件: {:?} -> {:?}", old_path, new_path))?;

        tracing::info!("聊天历史已重命名: {:?} -> {:?}", old_path, new_path);

        Ok(SaveChatResponse {
            success: true,
            file_path: Some(new_path.to_string_lossy().to_string()),
            message: Some(format!("文件已重命名: {} -> {}", old_name, new_name)),
        })
    }
}
