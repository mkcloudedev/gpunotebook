import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketState { disconnected, connecting, connected, error }

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamController<WebSocketState>? _stateController;
  WebSocketState _state = WebSocketState.disconnected;
  bool _isDisposed = false;

  WebSocketService() {
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
    _stateController = StreamController<WebSocketState>.broadcast();
  }

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;
  Stream<WebSocketState> get stateStream => _stateController!.stream;
  WebSocketState get state => _state;
  bool get isConnected => _state == WebSocketState.connected;

  Future<void> connect(String url) async {
    if (_isDisposed) return;
    if (_state == WebSocketState.connecting || _state == WebSocketState.connected) {
      return;
    }

    _updateState(WebSocketState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      await _channel!.ready;
      if (_isDisposed) return;
      _updateState(WebSocketState.connected);

      _channel!.stream.listen(
        (data) {
          if (_isDisposed) return;
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController?.add(message);
          } catch (e) {
            _messageController?.addError('Failed to parse message: $e');
          }
        },
        onError: (error) {
          if (_isDisposed) return;
          _updateState(WebSocketState.error);
          _messageController?.addError(error);
        },
        onDone: () {
          if (_isDisposed) return;
          _updateState(WebSocketState.disconnected);
        },
      );
    } catch (e) {
      if (_isDisposed) return;
      _updateState(WebSocketState.error);
      rethrow;
    }
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null || _state != WebSocketState.connected) {
      throw StateError('WebSocket not connected');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  void sendExecute(String kernelId, String code, String cellId) {
    send({
      'type': 'execute',
      'kernel_id': kernelId,
      'code': code,
      'cell_id': cellId,
    });
  }

  void sendInterrupt(String kernelId) {
    send({
      'type': 'interrupt',
      'kernel_id': kernelId,
    });
  }

  void sendPing() {
    send({'type': 'ping'});
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    if (!_isDisposed) {
      _updateState(WebSocketState.disconnected);
    }
  }

  void _updateState(WebSocketState newState) {
    if (_isDisposed) return;
    _state = newState;
    _stateController?.add(newState);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _channel?.sink.close();
    _channel = null;
    _messageController?.close();
    _stateController?.close();
    _messageController = null;
    _stateController = null;
  }
}
