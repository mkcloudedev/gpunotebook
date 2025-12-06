import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_message.dart';
import '../../models/cell.dart';
import '../../models/chat_request.dart';
import '../../services/ai_service.dart';
import '../../services/chat_history_service.dart';

class AIChatPanel extends StatefulWidget {
  final String notebookId;
  final List<Cell> Function() getCells;
  final String? Function() getSelectedCellId;
  final Function(String code, int? position) onCreateCell;
  final Function(String cellId, String code) onEditCell;
  final Function(String cellId) onDeleteCell;
  final Function(String cellId) onExecuteCell;

  const AIChatPanel({
    super.key,
    required this.notebookId,
    required this.getCells,
    required this.getSelectedCellId,
    required this.onCreateCell,
    required this.onEditCell,
    required this.onDeleteCell,
    required this.onExecuteCell,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  AIProvider _selectedProvider = AIProvider.claude;
  bool _isLoading = false;
  String _streamingContent = '';
  StreamSubscription? _streamSubscription;
  bool _historyLoaded = false;

  List<AIMessage> _messages = [];

  static const String _welcomeContent = 'Hello! I can help you with your notebook. I can:\n\n'
      '• Create and edit code cells\n'
      '• Execute code and show results\n'
      '• Explain errors and suggest fixes\n'
      '• Help optimize your code\n\n'
      'What would you like to do?';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await chatHistoryService.getHistory(widget.notebookId);
    if (mounted) {
      setState(() {
        if (history.isEmpty) {
          _messages = [AIMessage(
            id: '0',
            role: MessageRole.assistant,
            content: _welcomeContent,
            timestamp: DateTime.now(),
          )];
        } else {
          _messages = history;
        }
        _historyLoaded = true;
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveHistory() async {
    await chatHistoryService.saveHistory(widget.notebookId, _messages);
  }

  void _clearChat() {
    setState(() {
      _messages = [AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: _welcomeContent,
        timestamp: DateTime.now(),
      )];
    });
    chatHistoryService.clearHistory(widget.notebookId);
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
    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessageList()),
          _buildQuickActions(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(LucideIcons.bot, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.foreground)),
                Text('Ready to help', style: TextStyle(fontSize: 10, color: AppColors.success)),
              ],
            ),
          ),
          _buildProviderSelector(),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Clear chat',
            child: GestureDetector(
              onTap: _clearChat,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(LucideIcons.trash2, size: 14, color: AppColors.mutedForeground),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return PopupMenuButton<AIProvider>(
      initialValue: _selectedProvider,
      onSelected: (provider) => setState(() => _selectedProvider = provider),
      itemBuilder: (context) => [
        PopupMenuItem(value: AIProvider.claude, child: Text('Claude')),
        PopupMenuItem(value: AIProvider.openai, child: Text('GPT-4')),
        PopupMenuItem(value: AIProvider.gemini, child: Text('Gemini')),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getProviderIcon(), size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(_selectedProvider.name, style: TextStyle(fontSize: 12, color: AppColors.foreground)),
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  IconData _getProviderIcon() {
    switch (_selectedProvider) {
      case AIProvider.claude:
        return LucideIcons.sparkles;
      case AIProvider.openai:
        return LucideIcons.bot;
      case AIProvider.gemini:
        return LucideIcons.gem;
    }
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(12),
      itemCount: _messages.length + (_isLoading && _streamingContent.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildStreamingMessage();
        }
        return _ChatMessage(
          message: _messages[index],
          onActionTap: _handleAction,
        );
      },
    );
  }

  Widget _buildStreamingMessage() {
    // Try to extract displayable content from streaming
    // If it looks like JSON, try to extract just the message part
    String displayContent = _streamingContent;

    // If the content appears to be JSON with a message field, try to extract it
    if (_streamingContent.contains('"message"')) {
      final messageMatch = RegExp(r'"message"\s*:\s*"([^"]*(?:\\.[^"]*)*)"').firstMatch(_streamingContent);
      if (messageMatch != null) {
        displayContent = _cleanEscapeSequences(messageMatch.group(1) ?? _streamingContent);
      }
    } else {
      // If not JSON format, show as-is but clean escape sequences
      displayContent = _cleanEscapeSequences(_streamingContent);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                displayContent,
                style: TextStyle(fontSize: 13, color: AppColors.foreground, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionChip(
              icon: LucideIcons.play,
              label: 'Run cell',
              onTap: () => _sendQuickPrompt('Execute the selected cell and show the output'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.bug,
              label: 'Debug',
              onTap: () => _sendQuickPrompt('Help me debug the error in the current cell'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.zap,
              label: 'Optimize',
              onTap: () => _sendQuickPrompt('Optimize the code in the selected cell for better performance'),
            ),
            const SizedBox(width: 6),
            _QuickActionChip(
              icon: LucideIcons.fileText,
              label: 'Explain',
              onTap: () => _sendQuickPrompt('Explain what the code in the selected cell does'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessage();
                }
              },
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(fontSize: 13, color: AppColors.foreground),
                decoration: InputDecoration(
                  hintText: 'Ask anything... (Enter to send, Shift+Enter for new line)',
                  hintStyle: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _sendMessage,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(LucideIcons.send, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              disabledBackgroundColor: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  void _sendQuickPrompt(String prompt) {
    _inputController.text = prompt;
    _sendMessage();
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

    try {
      final currentCells = widget.getCells();
      final request = ChatRequest(
        provider: _selectedProvider,
        messages: _messages.where((m) => m.role != MessageRole.system).toList(),
        systemPrompt: aiService.buildNotebookSystemPrompt(
          currentCells.map((c) => <String, dynamic>{
            'id': c.id,
            'type': c.cellType.name,
            'source': c.source,
            'outputs': c.outputs.map((o) => <String, dynamic>{'type': o.outputType, 'text': o.text}).toList(),
          }).toList(),
        ),
      );

      final buffer = StringBuffer();
      await for (final chunk in aiService.chatStream(request)) {
        buffer.write(chunk);
        setState(() => _streamingContent = buffer.toString());
        _scrollToBottom();
      }

      final responseContent = buffer.toString();
      final displayContent = _processAIResponse(responseContent);

      setState(() {
        _messages.add(AIMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: MessageRole.assistant,
          content: displayContent,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
        _streamingContent = '';
      });
      _saveHistory();
    } catch (e) {
      setState(() {
        _messages.add(AIMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: MessageRole.assistant,
          content: 'Sorry, I encountered an error: $e',
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
        _streamingContent = '';
      });
      _saveHistory();
    }

    _scrollToBottom();
  }

  String _processAIResponse(String content) {
    print('Processing AI response (${content.length} chars)');

    try {
      // Try to find JSON block with message and actions
      // Look for JSON that starts with { and has "message"
      final jsonStart = content.indexOf('{');
      if (jsonStart != -1) {
        // Find the matching closing brace
        int braceCount = 0;
        int jsonEnd = -1;
        for (int i = jsonStart; i < content.length; i++) {
          if (content[i] == '{') braceCount++;
          if (content[i] == '}') braceCount--;
          if (braceCount == 0) {
            jsonEnd = i + 1;
            break;
          }
        }

        if (jsonEnd != -1) {
          final jsonStr = content.substring(jsonStart, jsonEnd);
          print('Found JSON block: ${jsonStr.substring(0, jsonStr.length > 200 ? 200 : jsonStr.length)}...');

          final json = jsonDecode(jsonStr) as Map<String, dynamic>;

          if (json.containsKey('message')) {
            // Extract message for display - JSON decode already handles escape sequences
            final message = json['message'] as String? ?? content;

            // Process actions
            final actions = json['actions'] as List<dynamic>?;
            print('Found ${actions?.length ?? 0} actions');
            if (actions != null && actions.isNotEmpty) {
              for (final action in actions) {
                final actionMap = action as Map<String, dynamic>;
                print('Processing action: ${actionMap['tool']}');
                _handleAction(AIAction.fromJson(actionMap));
              }
            }

            // Message is already unescaped by JSON decode, just return it
            return message;
          }
        }
      }
    } catch (e, stackTrace) {
      // If JSON parsing fails, try to extract just code blocks
      print('AI response parse error: $e');
      print('Stack trace: $stackTrace');
    }

    // If not JSON or parsing failed, clean escape sequences from raw text
    return _cleanEscapeSequences(content);
  }

  String _cleanEscapeSequences(String text) {
    // Replace literal escape sequences with actual characters
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\\', '\\');
  }

  void _handleAction(AIAction action) {
    print('=== AI ACTION ===');
    print('Tool: ${action.tool.name}');
    print('Params keys: ${action.params.keys.toList()}');
    print('Full params: ${action.params}');

    switch (action.tool) {
      case AIToolType.createCell:
        // Handle both 'source' and 'code' parameter names
        // JSON decode already unescapes the strings
        final source = (action.params['source'] ?? action.params['code'] ?? '') as String;
        // Handle position as int or string
        final positionRaw = action.params['position'];
        final position = positionRaw is int ? positionRaw : (positionRaw is String ? int.tryParse(positionRaw) : null);
        print('Creating cell at position $position with source length: ${source.length}');
        print('Source preview: ${source.substring(0, source.length > 100 ? 100 : source.length)}...');
        if (source.isNotEmpty) {
          widget.onCreateCell(source, position);
          print('Cell created successfully');
        } else {
          print('ERROR: Empty source, skipping cell creation');
        }
        break;

      case AIToolType.editCell:
        // Handle both 'cell_id' and 'cellId' parameter names
        final cellId = (action.params['cell_id'] ?? action.params['cellId']) as String?;
        final source = (action.params['source'] ?? action.params['code']) as String?;
        if (cellId != null && source != null) {
          print('Editing cell $cellId');
          widget.onEditCell(cellId, source);
        }
        break;

      case AIToolType.deleteCell:
        final cellId = (action.params['cell_id'] ?? action.params['cellId']) as String?;
        if (cellId != null) {
          print('Deleting cell $cellId');
          widget.onDeleteCell(cellId);
        }
        break;

      case AIToolType.executeCode:
        final cellId = (action.params['cell_id'] ?? action.params['cellId'] ?? widget.getSelectedCellId()) as String?;
        if (cellId != null) {
          print('Executing cell $cellId');
          widget.onExecuteCell(cellId);
        }
        break;

      case AIToolType.readCellOutput:
      case AIToolType.listCells:
        // These are read-only actions, no client-side action needed
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatMessage extends StatelessWidget {
  final AIMessage message;
  final Function(AIAction) onActionTap;

  const _ChatMessage({required this.message, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 13,
                  color: isUser ? AppColors.primaryForeground : AppColors.foreground,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.user, size: 14, color: AppColors.foreground),
            ),
          ],
        ],
      ),
    );
  }
}

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
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.1) : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: _isHovered ? AppColors.primary : AppColors.mutedForeground),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(fontSize: 11, color: _isHovered ? AppColors.primary : AppColors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
