import 'ai_message.dart';
import 'cell.dart';

class ChatRequest {
  final AIProvider provider;
  final List<AIMessage> messages;
  final String? systemPrompt;
  final int maxTokens;
  final double temperature;
  final NotebookContext? notebookContext;

  ChatRequest({
    required this.provider,
    required this.messages,
    this.systemPrompt,
    this.maxTokens = 4096,
    this.temperature = 0.7,
    this.notebookContext,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (notebookContext != null) 'notebook_context': notebookContext!.toJson(),
      };
}

class NotebookContext {
  final String notebookId;
  final List<Cell> cells;
  final String? selectedCellId;

  NotebookContext({
    required this.notebookId,
    required this.cells,
    this.selectedCellId,
  });

  Map<String, dynamic> toJson() => {
        'notebook_id': notebookId,
        'cells': cells.map((c) => {
          'id': c.id,
          'type': c.cellType.name,
          'source': c.source,
          'outputs': c.outputs.map((o) => {
            'type': o.outputType,
            'text': o.text,
          }).toList(),
          'execution_count': c.executionCount,
          'status': c.status.name,
        }).toList(),
        if (selectedCellId != null) 'selected_cell_id': selectedCellId,
      };
}

class ChatResponse {
  final String provider;
  final String content;
  final String model;
  final ChatUsage? usage;
  final List<AIAction>? actions;

  ChatResponse({
    required this.provider,
    required this.content,
    required this.model,
    this.usage,
    this.actions,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      provider: json['provider'] as String,
      content: json['content'] as String,
      model: json['model'] as String,
      usage: json['usage'] != null
          ? ChatUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      actions: (json['actions'] as List<dynamic>?)
          ?.map((a) => AIAction.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatUsage {
  final int inputTokens;
  final int outputTokens;

  ChatUsage({required this.inputTokens, required this.outputTokens});

  factory ChatUsage.fromJson(Map<String, dynamic> json) {
    return ChatUsage(
      inputTokens: json['input_tokens'] as int? ?? 0,
      outputTokens: json['output_tokens'] as int? ?? 0,
    );
  }
}

enum AIToolType { executeCode, createCell, editCell, deleteCell, readCellOutput, listCells }

class AIAction {
  final AIToolType tool;
  final Map<String, dynamic> params;

  AIAction({required this.tool, required this.params});

  factory AIAction.fromJson(Map<String, dynamic> json) {
    // Extract params - could be in 'params' key or at root level
    Map<String, dynamic> extractedParams = {};

    // First, check if there's a params object
    if (json['params'] is Map<String, dynamic>) {
      extractedParams = Map<String, dynamic>.from(json['params'] as Map<String, dynamic>);
    }

    // Also look for common parameter keys at root level and merge them
    // This handles AI responses that put source/code/position at root instead of in params
    final rootKeys = ['source', 'code', 'position', 'cell_id', 'cellId', 'type'];
    for (final key in rootKeys) {
      if (json.containsKey(key) && json[key] != null) {
        extractedParams[key] = json[key];
      }
    }

    return AIAction(
      tool: AIToolType.values.firstWhere(
        (t) => t.name == json['tool'],
        orElse: () => AIToolType.listCells,
      ),
      params: extractedParams,
    );
  }
}
