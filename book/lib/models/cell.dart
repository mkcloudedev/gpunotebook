enum CellType { code, markdown }

enum CellStatus { idle, running, success, error }

class CellOutput {
  final String outputType;
  final String? text;
  final Map<String, dynamic>? data;
  final String? ename;
  final String? evalue;
  final List<String>? traceback;

  const CellOutput({
    required this.outputType,
    this.text,
    this.data,
    this.ename,
    this.evalue,
    this.traceback,
  });

  factory CellOutput.fromJson(Map<String, dynamic> json) {
    // Handle text field - can be String, List<String>, or null
    String? textValue;
    final rawText = json['text'];
    if (rawText is String) {
      textValue = rawText;
    } else if (rawText is List) {
      textValue = rawText.join('');
    }

    // Handle data field
    Map<String, dynamic>? dataMap;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      dataMap = rawData;
      // If no text but data has text/plain, use that
      if (textValue == null && rawData['text/plain'] != null) {
        final plainText = rawData['text/plain'];
        if (plainText is String) {
          textValue = plainText;
        } else if (plainText is List) {
          textValue = plainText.join('');
        }
      }
    }

    return CellOutput(
      outputType: json['output_type'] as String? ?? json['type'] as String? ?? 'stream',
      text: textValue,
      data: dataMap,
      ename: json['ename'] as String?,
      evalue: json['evalue'] as String?,
      traceback: (json['traceback'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

/// Metadata for a cell
class CellMetadata {
  final bool hidden;
  final bool editable;
  final bool deletable;
  final String? name;
  final DateTime? createdAt;
  final DateTime? lastModified;
  final Map<String, dynamic> custom;

  const CellMetadata({
    this.hidden = false,
    this.editable = true,
    this.deletable = true,
    this.name,
    this.createdAt,
    this.lastModified,
    this.custom = const {},
  });

  CellMetadata copyWith({
    bool? hidden,
    bool? editable,
    bool? deletable,
    String? name,
    DateTime? createdAt,
    DateTime? lastModified,
    Map<String, dynamic>? custom,
  }) {
    return CellMetadata(
      hidden: hidden ?? this.hidden,
      editable: editable ?? this.editable,
      deletable: deletable ?? this.deletable,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      custom: custom ?? this.custom,
    );
  }

  factory CellMetadata.fromJson(Map<String, dynamic> json) {
    return CellMetadata(
      hidden: json['hidden'] as bool? ?? false,
      editable: json['editable'] as bool? ?? true,
      deletable: json['deletable'] as bool? ?? true,
      name: json['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastModified: json['last_modified'] != null
          ? DateTime.tryParse(json['last_modified'] as String)
          : null,
      custom: (json['custom'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hidden': hidden,
      'editable': editable,
      'deletable': deletable,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (lastModified != null) 'last_modified': lastModified!.toIso8601String(),
      if (custom.isNotEmpty) 'custom': custom,
    };
  }
}

/// Predefined tag types for cells
enum CellTagType {
  important,    // Important cell
  todo,         // TODO item
  skip,         // Skip during run all
  slow,         // Slow execution warning
  test,         // Test cell
  setup,        // Setup/initialization cell
  cleanup,      // Cleanup cell
  visualization,// Chart/plot cell
  dataLoad,     // Data loading cell
  model,        // ML model cell
  custom,       // Custom tag
}

/// Tag for a cell
class CellTag {
  final String label;
  final CellTagType type;
  final int color;

  const CellTag({
    required this.label,
    required this.type,
    required this.color,
  });

  CellTag copyWith({
    String? label,
    CellTagType? type,
    int? color,
  }) {
    return CellTag(
      label: label ?? this.label,
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }

  factory CellTag.fromJson(Map<String, dynamic> json) {
    return CellTag(
      label: json['label'] as String? ?? '',
      type: CellTagType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CellTagType.custom,
      ),
      color: json['color'] as int? ?? 0xFF3B82F6,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'type': type.name,
      'color': color,
    };
  }

  /// Create a predefined tag
  static CellTag predefined(CellTagType type) {
    switch (type) {
      case CellTagType.important:
        return const CellTag(label: 'Important', type: CellTagType.important, color: 0xFFEF4444);
      case CellTagType.todo:
        return const CellTag(label: 'TODO', type: CellTagType.todo, color: 0xFFF59E0B);
      case CellTagType.skip:
        return const CellTag(label: 'Skip', type: CellTagType.skip, color: 0xFF6B7280);
      case CellTagType.slow:
        return const CellTag(label: 'Slow', type: CellTagType.slow, color: 0xFFEC4899);
      case CellTagType.test:
        return const CellTag(label: 'Test', type: CellTagType.test, color: 0xFF8B5CF6);
      case CellTagType.setup:
        return const CellTag(label: 'Setup', type: CellTagType.setup, color: 0xFF10B981);
      case CellTagType.cleanup:
        return const CellTag(label: 'Cleanup', type: CellTagType.cleanup, color: 0xFF14B8A6);
      case CellTagType.visualization:
        return const CellTag(label: 'Visualization', type: CellTagType.visualization, color: 0xFF6366F1);
      case CellTagType.dataLoad:
        return const CellTag(label: 'Data Load', type: CellTagType.dataLoad, color: 0xFF0EA5E9);
      case CellTagType.model:
        return const CellTag(label: 'Model', type: CellTagType.model, color: 0xFFF97316);
      case CellTagType.custom:
        return const CellTag(label: 'Custom', type: CellTagType.custom, color: 0xFF3B82F6);
    }
  }
}

class Cell {
  final String id;
  final CellType cellType;
  final String source;
  final List<CellOutput> outputs;
  final int? executionCount;
  final CellStatus status;
  final List<CellTag> tags;
  final CellMetadata metadata;

  const Cell({
    required this.id,
    required this.cellType,
    required this.source,
    this.outputs = const [],
    this.executionCount,
    this.status = CellStatus.idle,
    this.tags = const [],
    this.metadata = const CellMetadata(),
  });

  Cell copyWith({
    String? id,
    CellType? cellType,
    String? source,
    List<CellOutput>? outputs,
    int? executionCount,
    CellStatus? status,
    List<CellTag>? tags,
    CellMetadata? metadata,
  }) {
    return Cell(
      id: id ?? this.id,
      cellType: cellType ?? this.cellType,
      source: source ?? this.source,
      outputs: outputs ?? this.outputs,
      executionCount: executionCount ?? this.executionCount,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if cell has a specific tag type
  bool hasTag(CellTagType type) {
    return tags.any((t) => t.type == type);
  }

  /// Check if cell should be skipped during "Run All"
  bool get shouldSkip => hasTag(CellTagType.skip);

  /// Check if cell is marked as important
  bool get isImportant => hasTag(CellTagType.important);
}
