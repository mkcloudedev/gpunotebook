import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/ai_message.dart';
import '../widgets/layout/main_layout.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  AIProvider _selectedProvider = AIProvider.claude;
  bool _isLoading = false;

  final List<AIMessage> _messages = [
    AIMessage(
      id: '1',
      role: MessageRole.assistant,
      content: 'Hello! I\'m your AI coding assistant. I can help you with:\n\n• Writing and debugging code\n• Explaining concepts\n• Optimizing GPU-accelerated code\n• Data analysis with pandas/numpy\n• Machine learning with PyTorch\n\nHow can I assist you today?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'AI Assistant',
      child: Row(
        children: [
          // Main content
          Expanded(
            child: Column(
              children: [
                // Header card
                _buildHeader(),
                // Messages
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoading && index == _messages.length) {
                              return _buildTypingIndicator();
                            }
                            return _ChatBubble(message: _messages[index]);
                          },
                        ),
                ),
                // Input
                _buildInput(),
              ],
            ),
          ),
          // Side panel
          _buildSidePanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code block header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.codeBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
              child: Text(
                '%ai',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.mutedForeground),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chat with ${_selectedProvider.name} for code assistance',
                        style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Provider selector
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(_getProviderIcon(_selectedProvider), size: 16, color: AppColors.foreground),
                            const SizedBox(width: 8),
                            Text(_selectedProvider.name, style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                            const SizedBox(width: 8),
                            Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _clearChat,
                        icon: Icon(LucideIcons.rotateCcw, size: 16),
                        label: Text('New Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.muted,
                          foregroundColor: AppColors.foreground,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
          Text(
            'Start a conversation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about coding, debugging, or GPU programming',
            style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
          ),
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
            child: Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.mutedForeground, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.mutedForeground, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.mutedForeground, shape: BoxShape.circle)),
              ],
            ),
          ),
        ],
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
          Expanded(
            child: TextField(
              controller: _inputController,
              style: TextStyle(fontSize: 14, color: AppColors.foreground),
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Icon(LucideIcons.send, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text('Quick Prompts', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ],
            ),
          ),
          // Quick prompts
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _QuickPrompt(
                    icon: LucideIcons.bug,
                    title: 'Debug Code',
                    description: 'Find and fix errors in code',
                    onTap: () => _setPrompt('Help me debug this code:'),
                  ),
                  const SizedBox(height: 8),
                  _QuickPrompt(
                    icon: LucideIcons.zap,
                    title: 'Optimize Performance',
                    description: 'Improve code speed and efficiency',
                    onTap: () => _setPrompt('How can I optimize this for GPU:'),
                  ),
                  const SizedBox(height: 8),
                  _QuickPrompt(
                    icon: LucideIcons.fileText,
                    title: 'Explain Code',
                    description: 'Understand complex code',
                    onTap: () => _setPrompt('Explain this code:'),
                  ),
                  const SizedBox(height: 8),
                  _QuickPrompt(
                    icon: LucideIcons.code2,
                    title: 'Generate Code',
                    description: 'Create new code from description',
                    onTap: () => _setPrompt('Write code that:'),
                  ),
                  const SizedBox(height: 8),
                  _QuickPrompt(
                    icon: LucideIcons.testTube,
                    title: 'Write Tests',
                    description: 'Generate unit tests',
                    onTap: () => _setPrompt('Write unit tests for:'),
                  ),
                ],
              ),
            ),
          ),
          // Provider status
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getProviderIcon(_selectedProvider), size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedProvider.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                        Text('Connected', style: TextStyle(fontSize: 11, color: AppColors.success)),
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

  void _setPrompt(String prompt) {
    _inputController.text = prompt;
  }

  void _sendMessage() {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final userMessage = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _inputController.clear();
    });

    _scrollToBottom();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(AIMessage(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            role: MessageRole.assistant,
            content: _generateResponse(content),
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  String _generateResponse(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('gpu') || lowerQuery.contains('cuda')) {
      return '''Great question about GPU programming! Here are some key points:

**Checking GPU availability:**
```python
import torch
print(torch.cuda.is_available())
print(torch.cuda.device_count())
```

**Moving tensors to GPU:**
```python
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
tensor = tensor.to(device)
```

**Memory management:**
```python
torch.cuda.empty_cache()
torch.cuda.memory_allocated()
```

Would you like me to explain any of these concepts in more detail?''';
    } else if (lowerQuery.contains('debug') || lowerQuery.contains('error')) {
      return '''I'd be happy to help debug your code! To give you the best assistance, please share:

1. **The code** that's causing issues
2. **The error message** you're seeing
3. **Expected behavior** vs actual behavior

Common debugging tips:
- Check variable types with `type(var)`
- Use `print()` statements to trace execution
- For GPU issues, check `torch.cuda.is_available()`

Paste your code and I'll help identify the problem!''';
    } else {
      return '''I understand you're asking about: "$query"

I'd be happy to help! To give you the best answer, could you provide more details about:

1. What programming language or framework you're using?
2. What specific problem you're trying to solve?
3. Any error messages you're seeing?

Feel free to share code snippets and I'll help debug or improve them!''';
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
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

class _ChatBubble extends StatelessWidget {
  final AIMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
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
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? AppColors.primaryForeground : AppColors.foreground,
                  height: 1.5,
                ),
              ),
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
    );
  }
}

class _QuickPrompt extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _QuickPrompt({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_QuickPrompt> createState() => _QuickPromptState();
}

class _QuickPromptState extends State<_QuickPrompt> {
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
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(widget.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.description, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}
