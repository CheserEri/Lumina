class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class ChatRequest {
  final String model;
  final List<ChatMessage> messages;
  final bool stream;

  ChatRequest({
    required this.model,
    required this.messages,
    this.stream = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': stream,
    };
  }
}

class ChatResponse {
  final String model;
  final ChatMessage message;
  final String? doneReason;
  final bool done;

  ChatResponse({
    required this.model,
    required this.message,
    this.doneReason,
    required this.done,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      model: json['model'] as String? ?? '',
      message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
      doneReason: json['done_reason'] as String?,
      done: json['done'] as bool? ?? false,
    );
  }
}

class OllamaModel {
  final String name;
  final String modifiedAt;
  final int size;

  OllamaModel({
    required this.name,
    required this.modifiedAt,
    required this.size,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      modifiedAt: json['modified_at'] as String,
      size: json['size'] as int,
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class ModelsResponse {
  final List<OllamaModel> models;

  ModelsResponse({required this.models});

  factory ModelsResponse.fromJson(Map<String, dynamic> json) {
    final modelsList = json['models'] as List<dynamic>;
    return ModelsResponse(
      models: modelsList
          .map((m) => OllamaModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
