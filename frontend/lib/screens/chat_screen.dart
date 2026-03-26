import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import '../widgets/chat_bubble.dart';
import 'history_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  static const int _maxMessages = 100; // 限制最大消息数量
  static const int _autoSaveMessageCount = 10; // 每10条消息自动保存一次
  String _selectedModel = '';
  List<OllamaModel> _models = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamingContent = '';
  bool _isConnected = false;
  int _messageCountSinceLastSave = 0;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initConnection() async {
    final connected = await _apiService.testConnection();
    setState(() {
      _isConnected = connected;
    });

    if (connected) {
      await _loadModels();
    }
  }

  Future<void> _loadModels() async {
    try {
      final models = await _apiService.getModels();
      setState(() {
        _models = models;
        if (models.isNotEmpty) {
          _selectedModel = models.first.name;
        }
      });
    } catch (e) {
      _showError('加载模型失败: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    if (_selectedModel.isEmpty) {
      _showError('请先选择一个模型');
      return;
    }

    setState(() {
      // 清理旧消息以防止内存问题
      if (_messages.length > _maxMessages) {
        _messages.removeRange(0, _messages.length - _maxMessages);
      }

      _messages.add(ChatMessage(role: 'user', content: text));
      _isLoading = true;
      _streamingContent = '';
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final request = ChatRequest(
        model: _selectedModel,
        messages: _messages
            .where((m) => m.isUser || (m.isAssistant && m.content.isNotEmpty))
            .toList(),
        stream: true,
      );

      setState(() {
        _isLoading = false;
        _isStreaming = true;
        _messages.add(ChatMessage(role: 'assistant', content: ''));
      });

      bool receivedAnyContent = false;

      await for (final chunk in _apiService.chatStream(request)) {
        debugPrint('收到chunk: "$chunk"');
        receivedAnyContent = true;
        setState(() {
          _streamingContent += chunk;
          if (_messages.isNotEmpty && _messages.last.isAssistant) {
            _messages[_messages.length - 1] = ChatMessage(
              role: 'assistant',
              content: _streamingContent,
            );
          }
        });
        _scrollToBottom();
      }

      // 如果流式模式没有收到任何内容，尝试非流式模式
      if (!receivedAnyContent) {
        debugPrint('流式模式未收到内容，尝试非流式模式');
        final nonStreamRequest = ChatRequest(
          model: _selectedModel,
          messages: _messages
              .where((m) => m.isUser || (m.isAssistant && m.content.isNotEmpty))
              .toList(),
          stream: false,
        );

        final response = await _apiService.chat(nonStreamRequest);
        setState(() {
          if (_messages.isNotEmpty && _messages.last.isAssistant) {
            _messages[_messages.length - 1] = ChatMessage(
              role: 'assistant',
              content: response.message.content,
            );
          }
        });
      }

      setState(() {
        _isStreaming = false;
      });

      // 检查是否需要自动保存
      _checkAutoSave();
    } catch (e) {
      debugPrint('发送消息错误: $e');
      setState(() {
        _isStreaming = false;
        _isLoading = false;
        if (_messages.isNotEmpty && _messages.last.content.isEmpty) {
          _messages.removeLast();
        }
      });
      _showError('发送消息失败: $e');
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _streamingContent = '';
    });
  }

  void _saveChat({String format = 'markdown'}) async {
    if (_messages.isEmpty) {
      _showError('没有聊天内容可保存');
      return;
    }

    try {
      final request = ChatRequest(
        model: _selectedModel,
        messages: _messages.where((m) => m.content.isNotEmpty).toList(),
        stream: false,
      );

      final response = await _apiService.saveChat(request, format: format);

      if (response['success'] == true) {
        _showSuccess('聊天已保存: ${response['message']}');
      } else {
        _showError('保存失败: ${response['message']}');
      }
    } catch (e) {
      _showError('保存聊天失败: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _checkAutoSave() {
    _messageCountSinceLastSave++;
    if (_messageCountSinceLastSave >= _autoSaveMessageCount) {
      _autoSaveChat();
      _messageCountSinceLastSave = 0;
    }
  }

  void _autoSaveChat() async {
    if (_messages.isEmpty || _selectedModel.isEmpty) return;

    try {
      final request = ChatRequest(
        model: _selectedModel,
        messages: _messages.where((m) => m.content.isNotEmpty).toList(),
        stream: false,
      );

      final response = await _apiService.saveChat(request);

      if (response['success'] == true) {
        _showSuccess('聊天已自动保存');
      }
    } catch (e) {
      // 自动保存失败时不显示错误，避免打扰用户
      debugPrint('自动保存失败: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenCodeLumina'),
        actions: [
          if (_models.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.model_training),
              tooltip: '选择模型',
              onSelected: (model) {
                setState(() {
                  _selectedModel = model;
                });
              },
              itemBuilder: (context) => _models
                  .map(
                    (m) => PopupMenuItem(
                      value: m.name,
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m.name)),
                          Text(
                            m.sizeFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新模型',
            onPressed: _loadModels,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: _clearChat,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存对话',
            onPressed: () => _saveChat(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '聊天历史',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(isDark),
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeMessage(isDark)
                : _buildChatList(),
          ),
          if (_isStreaming) _buildStreamingIndicator(),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F7F8),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? '已连接服务器' : '未连接服务器',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const Spacer(),
          if (_selectedModel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedModel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF10A37F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '欢迎使用 OpenCodeLumina',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF343541),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '基于 Ollama 的智能助手\n支持 Markdown 和 LaTeX 数学公式',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSuggestionChips(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDark) {
    final suggestions = [
      '用 Python 写一个快速排序算法',
      '解释薛定谔方程的含义',
      '帮我写一篇关于人工智能的文章',
      'E = mc² 是什么意思？',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () {
            _messageController.text = suggestion;
            _sendMessage();
          },
          backgroundColor: isDark ? const Color(0xFF444654) : Colors.white,
          side: BorderSide(
            color: isDark ? Colors.transparent : const Color(0xFFE5E5E5),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _messages.length,
      itemExtent: 80.0, // 添加固定高度以提高滚动性能
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLast = index == _messages.length - 1;
        return ChatBubble(
          message: message,
          isStreaming: isLast && _isStreaming,
        );
      },
    );
  }

  Widget _buildStreamingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF10A37F),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 正在思考...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF343541) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF555555) : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF40414F)
                      : const Color(0xFFF7F7F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF343541),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: _isLoading || _isStreaming
                    ? Colors.grey
                    : const Color(0xFF10A37F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading || _isStreaming ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
