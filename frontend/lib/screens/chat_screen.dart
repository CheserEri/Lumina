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
  static const int _maxMessages = 100;
  static const int _autoSaveMessageCount = 10;
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF10A37F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'L',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Lumina'),
          ],
        ),
        actions: [
          if (_models.isNotEmpty) _buildModelSelector(isDark),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新模型',
            onPressed: _loadModels,
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined, size: 20),
            tooltip: '聊天历史',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 20),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('保存对话'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 12),
                    Text('清空对话'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'save') {
                _saveChat();
              } else if (value == 'clear') {
                _clearChat();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeMessage(isDark)
                : _buildChatList(isDark),
          ),
          if (_isStreaming) _buildStreamingIndicator(isDark),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildModelSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: isDark ? const Color(0xFF444654) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
        child: PopupMenuButton<String>(
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
                      const Icon(Icons.smart_toy_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(m.name),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    _selectedModel.isEmpty ? '选择模型' : _selectedModel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF10A37F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10A37F).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '你好，有什么可以帮你的吗？',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 36),
            _buildSuggestionChips(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDark) {
    final suggestions = [
      {'icon': Icons.code, 'text': '用 Python 写一个快速排序'},
      {'icon': Icons.science, 'text': '解释薛定谔方程'},
      {'icon': Icons.article, 'text': '帮我写一篇文章'},
      {'icon': Icons.lightbulb, 'text': 'E = mc² 的含义'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: suggestions.map((s) {
        return Material(
          color: isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _messageController.text = s['text'] as String;
              _sendMessage();
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s['icon'] as IconData,
                    size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      s['text'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatList(bool isDark) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 8,
      radius: const Radius.circular(4),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isLast = index == _messages.length - 1;
          return _ChatMessageRow(
            message: message,
            isStreaming: isLast && _isStreaming,
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildStreamingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.grey[400]! : Colors.grey[500]!,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI 正在思考...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF212121) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '未连接到服务器',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2F2F2F)
                          : const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF444444)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: '给 Lumina 发送消息...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF333333),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: _isLoading || _isStreaming
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFF10A37F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _isLoading || _isStreaming ? Colors.grey[400] : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isLoading || _isStreaming
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF10A37F).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isLoading || _isStreaming
                          ? Icons.hourglass_empty
                          : Icons.arrow_upward,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _isLoading || _isStreaming ? null : _sendMessage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Lumina 可能会犯错，请核实重要信息。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageRow extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final bool isDark;

  const _ChatMessageRow({
    required this.message,
    required this.isStreaming,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Container(
      color: isUser
          ? (isDark ? const Color(0xFF212121) : Colors.white)
          : (isDark ? const Color(0xFF171717) : const Color(0xFFF7F7F8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF10A37F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
            ),
          if (isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF555555) : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isUser ? '你' : 'Lumina',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
                isUser
                    ? Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      )
                    : ChatBubble(
                        message: message,
                        isStreaming: isStreaming,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
