import '../models/notebook.dart';
import '../models/cell.dart';
import 'api_client.dart';

class NotebookService {
  final ApiClient _api;

  NotebookService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<Notebook>> list() async {
    try {
      final response = await _api.getList('/api/notebooks');
      return response.map((n) => _notebookFromJson(n as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Notebook?> get(String id) async {
    try {
      final response = await _api.get('/api/notebooks/$id');
      return _notebookFromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Notebook?> create(String name, {String? kernelName}) async {
    try {
      final response = await _api.post('/api/notebooks', {
        'name': name,
        if (kernelName != null) 'kernel_name': kernelName,
      });
      return _notebookFromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Notebook?> update(String id, {String? name, List<Cell>? cells}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (cells != null) {
        data['cells'] = cells.map((c) => {
          'id': c.id,
          'cell_type': c.cellType.name,
          'source': c.source,
          'outputs': c.outputs.map((o) => {
            'output_type': o.outputType,
            if (o.text != null) 'text': o.text,
            if (o.data != null) 'data': o.data,
            if (o.ename != null) 'ename': o.ename,
            if (o.evalue != null) 'evalue': o.evalue,
            if (o.traceback != null) 'traceback': o.traceback,
          }).toList(),
          if (c.executionCount != null) 'execution_count': c.executionCount,
          'status': c.status.name,
        }).toList();
      }
      final response = await _api.put('/api/notebooks/$id', data);
      return _notebookFromJson(response);
    } catch (e) {
      print('Error updating notebook: $e');
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.delete('/api/notebooks/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Cell?> addCell(String notebookId, CellType type, String source, {int? position}) async {
    try {
      final response = await _api.post('/api/notebooks/$notebookId/cells', {
        'cell_type': type.name,
        'source': source,
        if (position != null) 'position': position,
      });
      return _cellFromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Cell?> updateCell(String notebookId, String cellId, {String? source}) async {
    try {
      final response = await _api.put('/api/notebooks/$notebookId/cells/$cellId', {
        if (source != null) 'source': source,
      });
      return _cellFromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteCell(String notebookId, String cellId) async {
    try {
      await _api.delete('/api/notebooks/$notebookId/cells/$cellId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> exportToPython(String notebookId) async {
    try {
      final response = await _api.get('/api/notebooks/$notebookId/export/python');
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> exportToIpynb(String notebookId) async {
    try {
      final response = await _api.get('/api/notebooks/$notebookId/export/ipynb');
      if (response is Map) {
        return response.toString();
      }
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  String getExportPythonUrl(String notebookId) {
    return '${ApiClient.baseUrl}/api/notebooks/$notebookId/export/python';
  }

  String getExportIpynbUrl(String notebookId) {
    return '${ApiClient.baseUrl}/api/notebooks/$notebookId/export/ipynb';
  }

  String getExportHtmlUrl(String notebookId) {
    return '${ApiClient.baseUrl}/api/notebooks/$notebookId/export/html';
  }

  Notebook _notebookFromJson(Map<String, dynamic> json) {
    return Notebook(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      cells: (json['cells'] as List<dynamic>?)
              ?.map((c) => _cellFromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      kernelId: json['kernel_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Cell _cellFromJson(Map<String, dynamic> json) {
    return Cell(
      id: json['id'] as String? ?? '',
      cellType: CellType.values.firstWhere(
        (t) => t.name == (json['cell_type'] ?? json['type']),
        orElse: () => CellType.code,
      ),
      source: json['source'] as String? ?? '',
      outputs: (json['outputs'] as List<dynamic>?)
              ?.map((o) => CellOutput.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      executionCount: json['execution_count'] as int?,
      status: CellStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CellStatus.idle,
      ),
    );
  }
}

final notebookService = NotebookService();
