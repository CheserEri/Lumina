import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://localhost:8080';
  String _baseUrl;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String url) {
    _baseUrl = url;
  }

  Future<List<OllamaModel>> getModels() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/models'));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final modelsResponse = ModelsResponse.fromJson(data);
        return modelsResponse.models;
      } else {
        throw Exception('获取模型列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<ChatResponse> chat(ChatRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return ChatResponse.fromJson(data);
      } else {
        throw Exception('聊天请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Stream<String> chatStream(ChatRequest request) async* {
    final client = http.Client();
    try {
      final httpRequest =
          http.Request('POST', Uri.parse('$_baseUrl/api/chat/stream'))
            ..headers['Content-Type'] = 'application/json'
            ..body = json.encode(request.toJson());

      final response = await client.send(httpRequest);

      if (response.statusCode != 200) {
        throw Exception('流式聊天请求失败: ${response.statusCode}');
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 按行分割处理
        final lines = buffer.split('\n');
        // 保留最后一行（可能是不完整的）
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

          final jsonStr = trimmed.substring(6).trim();
          if (jsonStr.isEmpty) continue;

          try {
            final data = json.decode(jsonStr);
            final content = data['message']?['content'] as String? ?? '';
            final done = data['done'] as bool? ?? false;

            if (content.isNotEmpty) {
              yield content;
            }
            if (done) {
              return;
            }
          } catch (e) {
            continue;
          }
        }
      }

      // 处理缓冲区中剩余的数据
      if (buffer.trim().isNotEmpty && buffer.trim().startsWith('data: ')) {
        final jsonStr = buffer.trim().substring(6).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final data = json.decode(jsonStr);
            final content = data['message']?['content'] as String? ?? '';
            if (content.isNotEmpty) {
              yield content;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/models'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> saveChat(ChatRequest request,
      {String format = 'markdown'}) async {
    try {
      final requestData = request.toJson();
      requestData['format'] = format;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/save_chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('保存聊天失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<List<String>> getSavedChats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/saved_chats'));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final files = data['files'] as List;
        return files.cast<String>();
      } else {
        throw Exception('获取保存的聊天列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<Map<String, dynamic>> deleteSavedChat(String filename) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/delete_chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'filename': filename}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('删除聊天失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<Map<String, dynamic>> renameSavedChat(
      String oldName, String newName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/rename_chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'old_name': oldName, 'new_name': newName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('重命名聊天失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }
}
