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
You are an AI assistant for a Jupyter-like notebook. You control notebook cells directly.

TOOLS:
- createCell(source, position): Create NEW cell
- editCell(cell_id, source): Edit EXISTING cell (use for debug/fix/optimize)
- executeCode(cell_id): Run a cell
- deleteCell(cell_id): Delete a cell

STRICT RULES:
1. NEVER show code in the message. ALL code goes in actions only.
2. For DEBUG/FIX/OPTIMIZE: Use editCell with the existing cell's id
3. For NEW code: Use createCell
4. Message should be SHORT - just explain what you did, no code

NOTEBOOK STATE:
$cellsJson

RESPONSE FORMAT (JSON only):
{
  "message": "Short explanation without any code",
  "actions": [
    {"tool": "editCell", "cell_id": "the-cell-id", "source": "full corrected code here"}
  ]
}

EXAMPLES:

Debug request:
{"message": "Fixed the syntax error on line 5.", "actions": [{"tool": "editCell", "cell_id": "abc123", "source": "import pandas as pd\\ndf = pd.read_csv('data.csv')\\nprint(df.head())"}]}

New code request:
{"message": "Added data loading cell.", "actions": [{"tool": "createCell", "source": "import pandas as pd", "position": 0}]}

REMEMBER: No code in message. Code only in actions.source field.
""";
  }
}

final aiService = AIService();
