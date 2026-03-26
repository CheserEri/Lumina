import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<String> _savedChats = [];
  bool _isLoading = false;
  String _saveDirectory = '';

  @override
  void initState() {
    super.initState();
    _loadSavedChats();
  }

  Future<void> _loadSavedChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 这里需要调用一个获取保存目录的API
      // 暂时使用默认值
      _saveDirectory = 'E:\\Code\\History';

      // 这里需要实现获取保存的聊天列表
      // 暂时使用模拟数据
      setState(() {
        _savedChats = [];
        _isLoading = false;
      });
    } catch (e) {
      _showError('加载保存的聊天失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChat(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除文件 "$filename" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _apiService.deleteSavedChat(filename);
        if (response['success'] == true) {
          _showSuccess('文件已删除');
          _loadSavedChats();
        } else {
          _showError('删除失败: ${response['message']}');
        }
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _renameChat(String oldName) async {
    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名文件'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新文件名',
            hintText: '输入新的文件名',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        final response = await _apiService.renameSavedChat(oldName, newName);
        if (response['success'] == true) {
          _showSuccess('文件已重命名');
          _loadSavedChats();
        } else {
          _showError('重命名失败: ${response['message']}');
        }
      } catch (e) {
        _showError('重命名失败: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天历史管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedChats,
            tooltip: '刷新列表',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoHeader(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedChats.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildChatList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F7F8),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '保存目录: $_saveDirectory',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            '${_savedChats.length} 个文件',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无保存的聊天记录',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '聊天记录会自动保存到 $_saveDirectory',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedChats.length,
      itemBuilder: (context, index) {
        final filename = _savedChats[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(filename),
            subtitle: Text('点击查看内容'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _renameChat(filename),
                  tooltip: '重命名',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteChat(filename),
                  tooltip: '删除',
                ),
              ],
            ),
            onTap: () {
              // 这里可以添加查看文件内容的逻辑
              _showFilePreview(filename);
            },
          ),
        );
      },
    );
  }

  void _showFilePreview(String filename) {
    // 这里可以添加查看文件内容的逻辑
    // 暂时显示一个简单的对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('文件: $filename'),
        content: const Text('文件预览功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
