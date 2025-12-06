import 'dart:async';
import 'dart:convert';
import '../models/ai_message.dart';
import '../models/chat_request.dart';
import 'api_client.dart';

class AIService {
  final ApiClient _api;

  AIService({ApiClient? api}) : _api = api ?? apiClient;

  Future<ChatResponse> chat(ChatRequest request) async {
    final response = await _api.post('/api/ai/chat', request.toJson());
    return ChatResponse.fromJson(response);
  }

  Stream<String> chatStream(ChatRequest request) async* {
    await for (final chunk in _api.streamSSE('/api/ai/chat/stream', request.toJson())) {
      if (chunk.isNotEmpty && chunk != '[DONE]') {
        try {
          final data = jsonDecode(chunk) as Map<String, dynamic>;
          final content = data['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (e) {
          yield chunk;
        }
      }
    }
  }

  Future<String> explainCode(String code, {String? error, AIProvider provider = AIProvider.claude}) async {
    final response = await _api.post('/api/ai/explain', {
      'code': code,
      if (error != null) 'error': error,
      'provider': provider.name,
    });
    return response['explanation'] as String? ?? '';
  }

  Future<String> completeCode(String code, int cursorPosition, {AIProvider provider = AIProvider.claude}) async {
    final response = await _api.post('/api/ai/complete', {
      'code': code,
      'cursor_position': cursorPosition,
      'language': 'python',
      'provider': provider.name,
    });
    return response['completion'] as String? ?? '';
  }

  String buildNotebookSystemPrompt(List<Map<String, dynamic>> cells) {
    final cellsJson = jsonEncode(cells);
    return """
You are an expert AI assistant integrated into a Jupyter-like notebook environment.
Your goal is to help the user analyze data and write code in the notebook.

You have the following tools at your disposal:
- `createCell(source: str, position: int)`: Create a NEW code cell. Use ONLY when adding new functionality.
- `editCell(cell_id: str, source: str)`: Edit an EXISTING cell. Use for debugging, fixing, or improving existing code.
- `executeCode(cell_id: str)`: Execute a code cell by its ID.
- `deleteCell(cell_id: str)`: Delete a cell by its ID.

IMPORTANT RULES:
1. When user asks to DEBUG, FIX, or OPTIMIZE existing code: Use `editCell` with the cell's ID. NEVER delete and recreate.
2. When user asks to ADD NEW code or features: Use `createCell`.
3. ALWAYS preserve existing cells when debugging - just edit them in place.
4. Each cell has an "id" field - use this ID for editCell and executeCode.

The current notebook state (JSON):
$cellsJson

Respond with JSON containing "message" and "actions":

Example for DEBUGGING (editing existing cell):
{
  "message": "I fixed the error in your code.",
  "actions": [
    {
      "tool": "editCell",
      "cell_id": "existing-cell-id-here",
      "source": "# Fixed code here\\nprint('fixed')"
    }
  ]
}

Example for ADDING NEW code:
{
  "message": "Here's a new cell with the code.",
  "actions": [
    {
      "tool": "createCell",
      "source": "print('Hello')",
      "position": 0
    }
  ]
}
""";
  }
}

final aiService = AIService();
