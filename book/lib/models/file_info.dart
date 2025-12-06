enum FileType { file, directory }

class FileInfo {
  final String name;
  final String path;
  final FileType fileType;
  final int size;
  final DateTime modifiedAt;
  final String? mimeType;

  const FileInfo({
    required this.name,
    required this.path,
    required this.fileType,
    required this.size,
    required this.modifiedAt,
    this.mimeType,
  });

  bool get isDirectory => fileType == FileType.directory;
  bool get isFile => fileType == FileType.file;

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
