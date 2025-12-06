import 'dart:async';
import '../models/execution.dart';
import 'api_client.dart';
import 'websocket_service.dart';

class ExecutionService {
  final ApiClient _api;
  final WebSocketService _ws;
  final _outputController = StreamController<ExecutionOutput>.broadcast();
  final _statusController = StreamController<ExecutionEvent>.broadcast();

  ExecutionService({ApiClient? api, WebSocketService? ws})
      : _api = api ?? apiClient,
        _ws = ws ?? WebSocketService() {
    _ws.messages.listen(_handleWebSocketMessage);
  }

  Stream<ExecutionOutput> get outputs => _outputController.stream;
  Stream<ExecutionEvent> get events => _statusController.stream;

  Future<void> connectToKernel(String kernelId) async {
    final url = _api.getWebSocketUrl('/ws/kernel/$kernelId');
    await _ws.connect(url);
  }

  void disconnectFromKernel() {
    _ws.disconnect();
  }

  Future<ExecutionResult> execute(ExecutionRequest request) async {
    final response = await _api.post('/api/execute', request.toJson());
    return ExecutionResult.fromJson(response);
  }

  void executeViaWebSocket(String kernelId, String code, String cellId) {
    _ws.sendExecute(kernelId, code, cellId);
  }

  Future<ExecutionResult> getResult(String executionId) async {
    final response = await _api.get('/api/execute/$executionId');
    return ExecutionResult.fromJson(response);
  }

  Future<void> cancel(String kernelId) async {
    await _api.post('/api/execute/$kernelId/cancel', {});
  }

  void interruptViaWebSocket(String kernelId) {
    _ws.sendInterrupt(kernelId);
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'execution_start':
        _statusController.add(ExecutionEvent(
          type: ExecutionEventType.started,
          cellId: message['cell_id'] as String?,
        ));
        break;

      case 'output':
        final output = ExecutionOutput.fromJson(message);
        _outputController.add(output);
        _statusController.add(ExecutionEvent(
          type: ExecutionEventType.output,
          cellId: message['cell_id'] as String?,
          output: output,
        ));
        break;

      case 'execution_complete':
        _statusController.add(ExecutionEvent(
          type: ExecutionEventType.completed,
          cellId: message['cell_id'] as String?,
          executionCount: message['execution_count'] as int?,
          status: message['status'] as String?,
        ));
        break;

      case 'interrupted':
        _statusController.add(ExecutionEvent(
          type: ExecutionEventType.interrupted,
          cellId: message['cell_id'] as String?,
        ));
        break;

      case 'error':
        _statusController.add(ExecutionEvent(
          type: ExecutionEventType.error,
          cellId: message['cell_id'] as String?,
          error: message['error'] as String?,
        ));
        break;

      case 'pong':
        break;
    }
  }

  void dispose() {
    _ws.dispose();
    _outputController.close();
    _statusController.close();
  }
}

enum ExecutionEventType { started, output, completed, interrupted, error }

class ExecutionEvent {
  final ExecutionEventType type;
  final String? cellId;
  final ExecutionOutput? output;
  final int? executionCount;
  final String? status;
  final String? error;

  ExecutionEvent({
    required this.type,
    this.cellId,
    this.output,
    this.executionCount,
    this.status,
    this.error,
  });
}

final executionService = ExecutionService();
