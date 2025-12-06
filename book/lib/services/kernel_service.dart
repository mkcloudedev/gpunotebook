import '../models/kernel.dart';
import 'api_client.dart';

class KernelService {
  final ApiClient _api;

  KernelService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<Kernel>> list() async {
    try {
      final response = await _api.getList('/api/kernels');
      return response.map((k) => Kernel.fromJson(k as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Kernel> create(String name, {String? notebookId}) async {
    final response = await _api.post('/api/kernels', {
      'name': name,
      if (notebookId != null) 'notebook_id': notebookId,
    });
    return Kernel.fromJson(response);
  }

  Future<Kernel> get(String kernelId) async {
    final response = await _api.get('/api/kernels/$kernelId');
    return Kernel.fromJson(response);
  }

  Future<KernelStatus> getStatus(String kernelId) async {
    final response = await _api.get('/api/kernels/$kernelId/status');
    return KernelStatus.values.firstWhere(
      (s) => s.name == response['status'],
      orElse: () => KernelStatus.dead,
    );
  }

  Future<void> interrupt(String kernelId) async {
    await _api.post('/api/kernels/$kernelId/interrupt', {});
  }

  Future<Kernel> restart(String kernelId) async {
    final response = await _api.post('/api/kernels/$kernelId/restart', {});
    return Kernel.fromJson(response);
  }

  Future<void> shutdown(String kernelId) async {
    await _api.delete('/api/kernels/$kernelId');
  }

  Future<List<dynamic>?> getVariables(String kernelId) async {
    try {
      final response = await _api.get('/api/kernels/$kernelId/variables');
      return response['variables'] as List<dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> complete(String kernelId, String code, int cursorPos) async {
    try {
      final response = await _api.post('/api/kernels/$kernelId/complete', {
        'code': code,
        'cursor_pos': cursorPos,
      });
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> inspect(String kernelId, String code, int cursorPos) async {
    try {
      final response = await _api.post('/api/kernels/$kernelId/inspect', {
        'code': code,
        'cursor_pos': cursorPos,
      });
      return response;
    } catch (e) {
      return null;
    }
  }
}

final kernelService = KernelService();
