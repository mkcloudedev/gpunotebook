import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_message.dart';
import '../../models/chat_request.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/chat_history_service.dart';
import '../../services/ai_tools_service.dart';
import '../../widgets/ai/ai_action_modal.dart';

class AIAssistantContent extends StatefulWidget {
  final Function(String notebookId)? onOpenNotebook;
  final Function(String title)? onConversationChanged;
  final VoidCallback? onRefreshNeeded;

  const AIAssistantContent({
    super.key,
    this.onOpenNotebook,
    this.onConversationChanged,
    this.onRefreshNeeded,
  });

  @override
  State<AIAssistantContent> createState() => AIAssistantContentState();
}

class AIAssistantContentState extends State<AIAssistantContent> {
  static String get _globalChatId => ChatHistoryService.globalChatId;
  String? _currentConversationId;

  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  AIProvider _selectedProvider = AIProvider.claude;
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  String _streamingContent = '';
  StreamSubscription? _streamSubscription;

  List<AIMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await chatHistoryService.getHistory(_globalChatId);
      if (mounted) {
        setState(() {
          if (history.isEmpty) {
            _messages = [_getWelcomeMessage()];
          } else {
            _messages = history;
          }
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = [_getWelcomeMessage()];
          _isLoadingHistory = false;
        });
      }
    }
  }

  AIMessage _getWelcomeMessage() {
    return AIMessage(
      id: '1',
      role: MessageRole.assistant,
      content: 'Hello! I\'m your AI coding assistant. I can help you with:\n\n'
          '• Writing and debugging code\n'
          '• Explaining complex concepts\n'
          '• Optimizing GPU-accelerated code\n'
          '• Data analysis with pandas/numpy\n'
          '• Machine learning with PyTorch\n\n'
          '**Actions I can perform:**\n'
          '• Execute code directly\n'
          '• Create new notebooks\n'
          '• Add code to existing notebooks\n'
          '• Train ML models\n\n'
          'Use the action buttons below or just ask me!',
      timestamp: DateTime.now(),
    );
  }

  void _showActionModal(AIActionType actionType, {String? code}) {
    showDialog(
      context: context,
      builder: (context) => AIActionModal(
        actionType: actionType,
        initialCode: code,
        onOpenNotebook: widget.onOpenNotebook,
        onResult: (result) {
          // Add result to chat
          setState(() {
            _messages.add(AIMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              role: MessageRole.assistant,
              content: _formatToolResult(result),
              timestamp: DateTime.now(),
            ));
          });
          _saveHistory();
          _scrollToBottom();
        },
      ),
    );
  }

  String _formatToolResult(AIToolResult result) {
    final buffer = StringBuffer();
    buffer.writeln('**${result.tool.name.replaceAll('_', ' ').toUpperCase()}**\n');

    if (result.success) {
      buffer.writeln('✅ ${result.message ?? 'Completed successfully'}');
    } else {
      buffer.writeln('❌ ${result.error ?? 'Failed'}');
    }

    if (result.outputs != null && result.outputs!.isNotEmpty) {
      buffer.writeln('\n**Output:**');
      buffer.writeln('```');
      for (final output in result.outputs!) {
        buffer.writeln(output.text ?? output.data?.toString() ?? '');
      }
      buffer.writeln('```');
    }

    if (result.data != null) {
      if (result.data!['notebook_id'] != null) {
        buffer.writeln('\nNotebook ID: `${result.data!['notebook_id']}`');
      }
    }

    return buffer.toString();
  }

  /// Extract code blocks from AI response
  List<String> _extractCodeBlocks(String content) {
    final regex = RegExp(r'```(?:python|py)?\n([\s\S]*?)```');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)?.trim() ?? '').where((c) => c.isNotEmpty).toList();
  }

  Future<void> _saveHistory() async {
    final chatId = _currentConversationId ?? _globalChatId;
    await chatHistoryService.saveHistory(chatId, _messages);
    // Notify parent to refresh conversations list
    widget.onRefreshNeeded?.call();
  }

  /// Create a new conversation
  Future<void> createNewConversation() async {
    try {
      final response = await apiClient.post('/api/ai/conversations', {'title': 'New Chat'});
      final convId = response['id'] as String?;
      if (convId != null && mounted) {
        setState(() {
          _currentConversationId = convId;
          _messages = [_getWelcomeMessage()];
        });
        widget.onConversationChanged?.call('New Chat');
        widget.onRefreshNeeded?.call();
      }
    } catch (e) {
      // Fall back to clearing current chat
      setState(() {
        _messages = [_getWelcomeMessage()];
      });
    }
  }

  /// Load a specific conversation
  Future<void> loadConversation(String convId) async {
    try {
      final response = await apiClient.get('/api/ai/conversations/$convId');
      final messages = (response['messages'] as List<dynamic>?)
          ?.map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];

      if (mounted) {
        setState(() {
          _currentConversationId = convId;
          if (messages.isEmpty) {
            _messages = [_getWelcomeMessage()];
          } else {
            _messages = messages;
          }
        });
        // Get title from first user message
        String title = 'Chat';
        for (final m in messages) {
          if (m.role == MessageRole.user) {
            title = m.content.length > 30 ? '${m.content.substring(0, 30)}...' : m.content;
            break;
          }
        }
        widget.onConversationChanged?.call(title);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Main chat area
        Expanded(
          child: Column(
            children: [
              // Chat messages
              Expanded(
                child: _isLoadingHistory
                    ? Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16),
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoading && index == _messages.length) {
                                return _buildTypingIndicator();
                              }
                              return _ChatBubble(
                                message: _messages[index],
                                onCopy: () => _copyMessage(_messages[index].content),
                                onExecuteCode: (code) => _showActionModal(AIActionType.executeCode, code: code),
                                onSendToNotebook: (code) => _showActionModal(AIActionType.sendToNotebook, code: code),
                                onCreateNotebook: (code) => _showActionModal(AIActionType.createNotebook, code: code),
                              );
                            },
                          ),
              ),
              // Actions bar
              _buildActionsBar(),
              // Quick actions bar
              _buildQuickActionsBar(),
              // Input
              _buildInput(),
            ],
          ),
        ),
        // Side panel
        _buildSidePanel(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(LucideIcons.messageSquare, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Start a conversation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          const SizedBox(height: 8),
          Text('Ask me anything about coding, debugging, or GPU programming', style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getProviderIcon(_selectedProvider), size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _streamingContent.isNotEmpty
                  ? SelectableText(
                      _streamingContent,
                      style: TextStyle(fontSize: 14, color: AppColors.foreground, height: 1.5),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(0),
                        const SizedBox(width: 4),
                        _buildDot(1),
                        const SizedBox(width: 4),
                        _buildDot(2),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.mutedForeground.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildActionsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('Actions: ', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(width: 8),
          _ActionButton2(
            icon: LucideIcons.play,
            label: 'Execute Code',
            color: AppColors.success,
            onTap: () => _showActionModal(AIActionType.executeCode),
          ),
          const SizedBox(width: 8),
          _ActionButton2(
            icon: LucideIcons.filePlus,
            label: 'New Notebook',
            color: AppColors.primary,
            onTap: () => _showActionModal(AIActionType.createNotebook),
          ),
          const SizedBox(width: 8),
          _ActionButton2(
            icon: LucideIcons.send,
            label: 'To Notebook',
            color: Colors.orange,
            onTap: () => _showActionModal(AIActionType.sendToNotebook),
          ),
          const SizedBox(width: 8),
          _ActionButton2(
            icon: LucideIcons.brain,
            label: 'Train Model',
            color: Colors.purple,
            onTap: () => _showActionModal(AIActionType.trainModel),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Quick: ', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(width: 8),
            _QuickActionChip(
              icon: LucideIcons.bug,
              label: 'Debug',
              onTap: () => _sendQuickAction('Help me debug this code. What could be wrong and how can I fix it?'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.zap,
              label: 'Optimize',
              onTap: () => _sendQuickAction('How can I optimize this code for better performance on GPU?'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.fileText,
              label: 'Explain',
              onTap: () => _sendQuickAction('Can you explain how this code works step by step?'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.code2,
              label: 'Generate',
              onTap: () => _sendQuickAction('Write Python code that'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.testTube,
              label: 'Test',
              onTap: () => _sendQuickAction('Write unit tests for this code using pytest'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.fileCode,
              label: 'Document',
              onTap: () => _sendQuickAction('Add docstrings and comments to document this code'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Provider selector
          PopupMenuButton<AIProvider>(
            initialValue: _selectedProvider,
            onSelected: (provider) => setState(() => _selectedProvider = provider),
            tooltip: 'Select AI Provider',
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getProviderIcon(_selectedProvider), size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _selectedProvider.name[0].toUpperCase() + _selectedProvider.name.substring(1),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
                ],
              ),
            ),
            itemBuilder: (context) => [
              _buildProviderMenuItem(AIProvider.claude, 'Claude', LucideIcons.sparkles),
              _buildProviderMenuItem(AIProvider.openai, 'OpenAI', LucideIcons.bot),
              _buildProviderMenuItem(AIProvider.gemini, 'Gemini', LucideIcons.gem),
            ],
          ),
          const SizedBox(width: 12),
          // Input field
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              style: TextStyle(fontSize: 14, color: AppColors.foreground),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask anything about coding, GPU, or ML...',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send button
          ElevatedButton(
            onPressed: _isLoading ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(LucideIcons.send, size: 18),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<AIProvider> _buildProviderMenuItem(AIProvider provider, String name, IconData icon) {
    return PopupMenuItem(
      value: provider,
      child: Row(
        children: [
          Icon(icon, size: 16, color: _selectedProvider == provider ? AppColors.primary : AppColors.mutedForeground),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(color: _selectedProvider == provider ? AppColors.primary : AppColors.foreground)),
          const Spacer(),
          if (_selectedProvider == provider)
            Icon(LucideIcons.check, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Prompts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
                const Spacer(),
                Tooltip(
                  message: 'Clear chat',
                  child: GestureDetector(
                    onTap: _clearChat,
                    child: Icon(LucideIcons.trash2, size: 14, color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Prompt templates
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _PromptCard(
                    icon: LucideIcons.bug,
                    title: 'Debug Code',
                    description: 'Find and fix errors',
                    onTap: () => _sendQuickAction('I have a bug in my code. Can you help me identify the issue and suggest a fix?'),
                  ),
                  const SizedBox(height: 8),
                  _PromptCard(
                    icon: LucideIcons.zap,
                    title: 'Optimize for GPU',
                    description: 'CUDA optimization tips',
                    onTap: () => _sendQuickAction('How can I optimize this code to run faster on NVIDIA GPU with CUDA?'),
                  ),
                  const SizedBox(height: 8),
                  _PromptCard(
                    icon: LucideIcons.brain,
                    title: 'ML Architecture',
                    description: 'Neural network design',
                    onTap: () => _sendQuickAction('Help me design a neural network architecture for my problem'),
                  ),
                  const SizedBox(height: 8),
                  _PromptCard(
                    icon: LucideIcons.barChart,
                    title: 'Data Analysis',
                    description: 'Pandas & visualization',
                    onTap: () => _sendQuickAction('Show me how to analyze this dataset using pandas and create visualizations'),
                  ),
                  const SizedBox(height: 8),
                  _PromptCard(
                    icon: LucideIcons.gitBranch,
                    title: 'Code Review',
                    description: 'Best practices check',
                    onTap: () => _sendQuickAction('Review this code and suggest improvements for readability and best practices'),
                  ),
                  const SizedBox(height: 8),
                  _PromptCard(
                    icon: LucideIcons.cpu,
                    title: 'PyTorch Model',
                    description: 'Training & inference',
                    onTap: () => _sendQuickAction('Help me create a PyTorch model with training loop and inference code'),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Provider status
          Padding(
            padding: EdgeInsets.all(12),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(_getProviderIcon(_selectedProvider), size: 16, color: AppColors.success),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProvider.name[0].toUpperCase() + _selectedProvider.name.substring(1),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
                        ),
                        Text('Ready', style: TextStyle(fontSize: 10, color: AppColors.success)),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.claude:
        return LucideIcons.sparkles;
      case AIProvider.openai:
        return LucideIcons.bot;
      case AIProvider.gemini:
        return LucideIcons.gem;
    }
  }

  void _sendQuickAction(String prompt) {
    _inputController.text = prompt;
    _inputFocusNode.requestFocus();
    // Move cursor to end
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  void _copyMessage(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Clipboard not available in web context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard not available'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _clearChat() async {
    setState(() {
      _messages.clear();
      _messages.add(AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: 'Chat cleared. How can I help you?',
        timestamp: DateTime.now(),
      ));
    });
    await chatHistoryService.clearHistory(_globalChatId);
    await _saveHistory();
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isLoading) return;

    final userMessage = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _streamingContent = '';
      _inputController.clear();
    });
    _scrollToBottom();

    // Save user message immediately
    _saveHistory();

    try {
      final request = ChatRequest(
        messages: _messages.where((m) => m.role != MessageRole.system).toList(),
        provider: _selectedProvider,
      );

      final buffer = StringBuffer();
      await for (final chunk in aiService.chatStream(request)) {
        buffer.write(chunk);
        if (mounted) {
          setState(() => _streamingContent = buffer.toString());
          _scrollToBottom();
        }
      }

      final responseContent = buffer.toString();

      if (mounted) {
        setState(() {
          _messages.add(AIMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            role: MessageRole.assistant,
            content: responseContent.isNotEmpty ? responseContent : 'I apologize, but I couldn\'t generate a response. Please try again.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
          _streamingContent = '';
        });
        _scrollToBottom();
        // Save after receiving response
        _saveHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AIMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            role: MessageRole.assistant,
            content: 'Error: $e\n\nPlease check your API key in Settings and try again.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
          _streamingContent = '';
        });
        _scrollToBottom();
        // Save error message too
        _saveHistory();
      }
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
}

// ============================================================================
// CHAT BUBBLE
// ============================================================================

class _ChatBubble extends StatefulWidget {
  final AIMessage message;
  final VoidCallback onCopy;
  final Function(String code)? onExecuteCode;
  final Function(String code)? onSendToNotebook;
  final Function(String code)? onCreateNotebook;

  const _ChatBubble({
    required this.message,
    required this.onCopy,
    this.onExecuteCode,
    this.onSendToNotebook,
    this.onCreateNotebook,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _isHovered = false;

  /// Extract code blocks from content
  List<String> _extractCodeBlocks(String content) {
    final regex = RegExp(r'```(?:python|py)?\n?([\s\S]*?)```');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)?.trim() ?? '').where((c) => c.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final codeBlocks = !isUser ? _extractCodeBlocks(widget.message.content) : <String>[];
    final hasCode = codeBlocks.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: isUser ? null : Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      widget.message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser ? AppColors.primaryForeground : AppColors.foreground,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_isHovered && !isUser) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _ActionButton(
                          icon: LucideIcons.copy,
                          tooltip: 'Copy',
                          onTap: widget.onCopy,
                        ),
                        if (hasCode && widget.onExecuteCode != null)
                          _CodeActionButton(
                            icon: LucideIcons.play,
                            label: 'Run',
                            color: AppColors.success,
                            onTap: () => widget.onExecuteCode!(codeBlocks.first),
                          ),
                        if (hasCode && widget.onSendToNotebook != null)
                          _CodeActionButton(
                            icon: LucideIcons.send,
                            label: 'To Notebook',
                            color: Colors.orange,
                            onTap: () => widget.onSendToNotebook!(codeBlocks.first),
                          ),
                        if (hasCode && widget.onCreateNotebook != null)
                          _CodeActionButton(
                            icon: LucideIcons.filePlus,
                            label: 'New Notebook',
                            color: AppColors.primary,
                            onTap: () => widget.onCreateNotebook!(codeBlocks.first),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.user, size: 16, color: AppColors.foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CodeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.muted : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 12, color: AppColors.mutedForeground),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION CHIP
// ============================================================================

class _QuickActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.1) : AppColors.muted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: _isHovered ? AppColors.primary : AppColors.mutedForeground),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? AppColors.primary : AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROMPT CARD
// ============================================================================

class _PromptCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PromptCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
                    ),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: _isHovered ? AppColors.primary : AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACTION BUTTON 2 (For Actions Bar)
// ============================================================================

class _ActionButton2 extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton2({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton2> createState() => _ActionButton2State();
}

class _ActionButton2State extends State<_ActionButton2> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withOpacity(0.15) : widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered ? widget.color : widget.color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
