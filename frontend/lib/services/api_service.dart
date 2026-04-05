import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import '../models/chat_models.dart';

class ApiService {
  static const String defaultBaseUrl = '';
  String _baseUrl;
  String? _token;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  set baseUrl(String url) {
    _baseUrl = url;
  }

  set token(String? value) {
    _token = value;
  }

  Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/api/auth/register',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      final data = json.decode(response.responseText!);
      if (data['token'] != null) {
        _token = data['token'];
      }
      return data;
    } catch (e) {
      throw Exception('注册失败: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/api/auth/login',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: json.encode({
          'username': username,
          'password': password,
        }),
      );
      final data = json.decode(response.responseText!);
      if (data['token'] != null) {
        _token = data['token'];
      }
      return data;
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  Future<List<OllamaModel>> getModels() async {
    try {
      final response = await html.HttpRequest.getString(
        '$_baseUrl/api/models',
      );
      final data = json.decode(response);
      final modelsResponse = ModelsResponse.fromJson(data);
      return modelsResponse.models;
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<ChatResponse> chat(ChatRequest request) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/api/chat',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          ..._authHeaders,
        },
        sendData: json.encode(request.toJson()),
      );
      final data = json.decode(response.responseText!);
      return ChatResponse.fromJson(data);
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Stream<String> chatStream(ChatRequest request) async* {
    try {
      final completer = Completer<void>();
      final controller = StreamController<String>();

      final xhr = html.HttpRequest();
      xhr
        ..open('POST', '$_baseUrl/api/chat/stream')
        ..setRequestHeader('Content-Type', 'application/json')
        ..responseType = 'text'
        ..onReadyStateChange.listen((_) {
          if (xhr.readyState == html.HttpRequest.DONE) {
            controller.close();
            completer.complete();
          }
        });

      String buffer = '';
      xhr.onProgress.listen((event) {
        final text = xhr.responseText ?? '';
        final newContent = text.substring(buffer.length);
        buffer = text;

        final lines = newContent.split('\n');
        final lastLine = lines.removeLast();

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
              controller.add(content);
            }
            if (done) {
              controller.close();
              completer.complete();
            }
          } catch (_) {}
        }
      });

      xhr.send(json.encode(request.toJson()));

      await for (final chunk in controller.stream) {
        yield chunk;
      }

      await completer.future;
    } catch (e) {
      throw Exception('流式聊天请求失败: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      await html.HttpRequest.getString('$_baseUrl/api/models');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> saveChat(
    ChatRequest request, {
    String format = 'markdown',
  }) async {
    try {
      final requestData = request.toJson();
      requestData['format'] = format;

      final response = await html.HttpRequest.request(
        '$_baseUrl/api/save_chat',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          ..._authHeaders,
        },
        sendData: json.encode(requestData),
      );
      return json.decode(response.responseText!);
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<List<String>> getSavedChats() async {
    try {
      final response = await html.HttpRequest.getString(
        '$_baseUrl/api/saved_chats',
      );
      final data = json.decode(response);
      final files = data['files'] as List;
      return files.cast<String>();
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<Map<String, dynamic>> deleteSavedChat(String filename) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/api/delete_chat',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          ..._authHeaders,
        },
        sendData: json.encode({'filename': filename}),
      );
      return json.decode(response.responseText!);
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  Future<Map<String, dynamic>> renameSavedChat(
    String oldName,
    String newName,
  ) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl/api/rename_chat',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          ..._authHeaders,
        },
        sendData: json.encode({'old_name': oldName, 'new_name': newName}),
      );
      return json.decode(response.responseText!);
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }
}
