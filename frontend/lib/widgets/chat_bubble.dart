import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import 'markdown_latex_widget.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;

  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownLatexWidget(data: message.content, isUser: false),
        if (isStreaming && message.content.isEmpty)
          _buildStreamingIndicator(isDark),
      ],
    );
  }

  Widget _buildStreamingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDark ? Colors.grey[400]! : Colors.grey[500]!,
          ),
        ),
      ),
    );
  }
}
