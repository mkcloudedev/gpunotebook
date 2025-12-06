import 'api_client.dart';

class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      isDirectory: json['is_directory'] as bool? ??
                   json['file_type'] == 'directory' ||
                   json['type'] == 'directory',
      size: json['size'] as int? ?? 0,
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'] as String)
          : DateTime.now(),
    );
  }
}

class StorageInfo {
  final int used;
  final int total;

  StorageInfo({required this.used, required this.total});

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      used: json['used'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  double get usedGB => used / (1024 * 1024 * 1024);
  double get totalGB => total / (1024 * 1024 * 1024);
  double get percent => total > 0 ? (used / total) * 100 : 0;
}

class FileService {
  final ApiClient _api;

  FileService({ApiClient? api}) : _api = api ?? apiClient;

  Future<List<FileItem>> list(String path) async {
    try {
      final response = await _api.get('/api/files?path=$path');
      final files = response['files'] as List<dynamic>? ?? [];
      return files.map((f) => FileItem.fromJson(f as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StorageInfo> getStorageInfo() async {
    try {
      final response = await _api.get('/api/files/storage');
      return StorageInfo.fromJson(response);
    } catch (e) {
      return StorageInfo(used: 0, total: 0);
    }
  }

  Future<bool> createDirectory(String path) async {
    try {
      await _api.post('/api/files/mkdir', {'path': path});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> delete(String path) async {
    try {
      await _api.delete('/api/files?path=$path');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> read(String path) async {
    try {
      final response = await _api.get('/api/files/read?path=$path');
      return response['content'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> uploadFile(String filename, List<int> bytes, String path) async {
    try {
      await _api.uploadFile('/api/files/upload', filename, bytes, path);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final fileService = FileService();
