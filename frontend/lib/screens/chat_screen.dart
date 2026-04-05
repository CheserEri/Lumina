import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import '../widgets/chat_bubble.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  final ApiService apiService;

  const ChatScreen({super.key, required this.apiService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
  bool _sidebarOpen = true;

  ApiService get _apiService => widget.apiService;

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
      _showError('Failed to load models: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    if (_selectedModel.isEmpty) {
      _showError('Please select a model first');
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
      setState(() {
        _isStreaming = false;
        _isLoading = false;
        if (_messages.isNotEmpty && _messages.last.content.isEmpty) {
          _messages.removeLast();
        }
      });
      _showError('Failed to send message: $e');
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
      _showError('No messages to save');
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
        _showSuccess('Chat saved: ${response['message']}');
      } else {
        _showError('Save failed: ${response['message']}');
      }
    } catch (e) {
      _showError('Failed to save chat: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2d3433),
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
        _showSuccess('Chat auto-saved');
      }
    } catch (e) {
      debugPrint('Auto-save failed: $e');
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
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF9e3f4e)),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          if (_sidebarOpen) _buildSidebar(isDark),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isDark),
                Expanded(
                  child: _messages.isEmpty
                      ? _buildWelcomeArea(isDark)
                      : _buildChatList(isDark),
                ),
                if (_isStreaming) _buildStreamingIndicator(isDark),
                _buildInputArea(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    final surfaceColor =
        isDark ? const Color(0xFF1a1a2e) : const Color(0xFFebeeed);
    final textColor =
        isDark ? const Color(0xFFe0e0e0) : const Color(0xFF5b5f65);

    return Container(
      width: 260,
      color: surfaceColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5d5e6d).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF5d5e6d),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Lumina',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF2d3433),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _clearChat,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF2a2a3e)
                      : Colors.white.withOpacity(0.5),
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF2d3433),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark
                          ? Colors.transparent
                          : const Color(0xFF5d5e6d).withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  icon: Icons.history_outlined,
                  label: 'Recent Threads',
                  textColor: textColor,
                  onTap: () {},
                ),
                _SidebarItem(
                  icon: Icons.star_outline,
                  label: 'Saved Prompts',
                  textColor: textColor,
                  onTap: () {},
                ),
                _SidebarItem(
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  textColor: textColor,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SidebarItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  textColor: textColor,
                  onTap: () {},
                ),
                _SidebarItem(
                  icon: Icons.history,
                  label: 'Chat History',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HistoryScreen()),
                    );
                  },
                ),
                const Divider(height: 24, thickness: 0.5),
                _SidebarItem(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  textColor: const Color(0xFF9e3f4e),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF171717).withOpacity(0.8)
            : const Color(0xFFf9f9f8).withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFe5e5e5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: () {
              setState(() {
                _sidebarOpen = !_sidebarOpen;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Lumina AI',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF2d3433),
            ),
          ),
          const SizedBox(width: 24),
          if (_models.isNotEmpty) _buildModelSelector(isDark),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        tooltip: 'Select model',
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
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2a2a3e) : const Color(0xFFf0f0f0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedModel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : const Color(0xFF5b5f65),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeArea(bool isDark) {
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
                color: const Color(0xFF5d5e6d).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF5d5e6d),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'What shall we curate today?',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: Color(0xFF2d3433),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your intellectual workspace for profound synthesis\nand intentional creation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : const Color(0xFF5b5f65),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 48),
            _buildSuggestionCards(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCards(bool isDark) {
    final suggestions = [
      {
        'icon': Icons.description,
        'title': 'Summarize a document',
        'desc': 'Extract the essence from long-form content.'
      },
      {
        'icon': Icons.code,
        'title': 'Analyze code',
        'desc': 'Debug or refactor complex logic flows.'
      },
      {
        'icon': Icons.mail,
        'title': 'Write an email',
        'desc': 'Draft professional and curated messages.'
      },
    ];

    final containerColor =
        isDark ? const Color(0xFF2a2a3e) : const Color(0xFFf2f4f3);
    final hoverColor =
        isDark ? const Color(0xFF33334a) : const Color(0xFFebeeed);
    final titleColor = isDark ? Colors.white : const Color(0xFF2d3433);
    final descColor = isDark ? Colors.grey[400] : const Color(0xFF5b5f65);
    final iconColor = const Color(0xFF5d5e6d);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: suggestions.map((s) {
        return Material(
          color: containerColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _messageController.text = s['title'] as String;
              _sendMessage();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(s['icon'] as IconData, color: iconColor, size: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['desc'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: descColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
      thickness: 6,
      radius: const Radius.circular(3),
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
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.grey[400]! : Colors.grey[500]!,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AI is thinking...',
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? const Color(0xFF171717) : const Color(0xFFf9f9f8))
                .withOpacity(0),
            isDark ? const Color(0xFF171717) : const Color(0xFFf9f9f8),
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFffffff).withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? Colors.black
                                    : const Color(0xFF2d3433))
                                .withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'How can I help you today?',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey[500]
                                : const Color(0xFFadb3b2),
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF2d3433),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isLoading || _isStreaming
                          ? Colors.grey[400]
                          : const Color(0xFF5d5e6d),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isLoading || _isStreaming
                            ? Icons.hourglass_empty
                            : Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed:
                          _isLoading || _isStreaming ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lumina may provide information for inspiration. Please verify facts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[600] : const Color(0xFFadb3b2),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: textColor.withOpacity(0.8)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
    final bgColor = isUser
        ? (isDark ? const Color(0xFF1a1a1a) : Colors.white)
        : (isDark ? const Color(0xFF171717) : const Color(0xFFf2f4f3));

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF5d5e6d)
                  : const Color(0xFF5d5e6d).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: isUser
                  ? const Icon(Icons.person, color: Colors.white, size: 14)
                  : const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF5d5e6d),
                      size: 14,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    isUser ? 'You' : 'Lumina',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.grey[300] : const Color(0xFF2d3433),
                    ),
                  ),
                ),
                isUser
                    ? Text(
                        message.content,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF2d3433),
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
