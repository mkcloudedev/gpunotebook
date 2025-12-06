import 'dart:convert';
import '../models/ai_message.dart';
import 'api_client.dart';

/// Service to persist AI chat history per notebook or global
class ChatHistoryService {
  static const String globalChatId = 'global_ai_assistant';

  final ApiClient _api;

  // In-memory cache of conversations
  final Map<String, List<AIMessage>> _cache = {};

  ChatHistoryService({ApiClient? api}) : _api = api ?? apiClient;

  bool _isGlobalChat(String id) => id == globalChatId;

  /// Get chat history for a notebook or global chat
  Future<List<AIMessage>> getHistory(String id) async {
    // Return from cache if available
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    try {
      final endpoint = _isGlobalChat(id)
          ? '/api/ai/history'
          : '/api/notebooks/$id/chat';

      final response = await _api.get(endpoint);
      final messages = (response['messages'] as List<dynamic>?)
              ?.map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];
      _cache[id] = messages;
      return messages;
    } catch (e) {
      // If API fails, return empty list but keep trying
      return _cache[id] ?? [];
    }
  }

  /// Save chat history for a notebook or global chat
  Future<bool> saveHistory(String id, List<AIMessage> messages) async {
    // Update cache immediately
    _cache[id] = messages;

    try {
      final endpoint = _isGlobalChat(id)
          ? '/api/ai/history'
          : '/api/notebooks/$id/chat';

      await _api.post(endpoint, {
        'messages': messages.map((m) => m.toJson()).toList(),
      });
      return true;
    } catch (e) {
      // Failed to save to backend, but cache is updated
      return false;
    }
  }

  /// Add a message to history
  Future<void> addMessage(String id, AIMessage message) async {
    final history = await getHistory(id);
    history.add(message);
    await saveHistory(id, history);
  }

  /// Clear chat history for a notebook or global chat
  Future<void> clearHistory(String id) async {
    _cache[id] = [];
    try {
      final endpoint = _isGlobalChat(id)
          ? '/api/ai/history'
          : '/api/notebooks/$id/chat';

      await _api.delete(endpoint);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get cached history (no API call)
  List<AIMessage> getCachedHistory(String id) {
    return _cache[id] ?? [];
  }

  /// Update cache without API call
  void updateCache(String id, List<AIMessage> messages) {
    _cache[id] = messages;
  }
}

final chatHistoryService = ChatHistoryService();
