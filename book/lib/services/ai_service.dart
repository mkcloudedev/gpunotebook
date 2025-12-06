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
- `executeCode(cell_id: str)`: Execute a code cell by its ID.
- `createCell(source: str, position: int)`: Create a new code cell with the given source code at the given position.
- `editCell(cell_id: str, source: str)`: Edit the source code of an existing cell.
- `deleteCell(cell_id: str)`: Delete a cell by its ID.
- `readCellOutput(cell_id: str)`: Read the output of a code cell.
- `listCells()`: List all the cells in the notebook.

The current state of the notebook is as follows (in JSON format):
$cellsJson

You MUST use the information from this JSON to answer the user's questions about the notebook.
Do NOT use the `listCells` tool if the information is already in this JSON.
When providing code, always wrap it in a `createCell` or `editCell` tool call.
Do not provide code as plain text.
If you need to see the output of a cell, use the `readCellOutput` tool.
Respond with a JSON object containing a "message" for the user and a list of "actions" to take.
Example response:
{
  "message": "I see you want to add a new cell. Here's the code to do that.",
  "actions": [
    {
      "tool": "createCell",
      "params": {
        "source": "print('Hello, World!')"
      }
    }
  ]
}
""";
  }
}

final aiService = AIService();
