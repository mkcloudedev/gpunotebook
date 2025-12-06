enum KernelStatus { idle, busy, starting, error, dead }

class Kernel {
  final String id;
  final String name;
  final KernelStatus status;
  final int executionCount;
  final String? notebookId;
  final DateTime createdAt;
  final DateTime lastActivity;

  const Kernel({
    required this.id,
    required this.name,
    required this.status,
    this.executionCount = 0,
    this.notebookId,
    required this.createdAt,
    required this.lastActivity,
  });

  Kernel copyWith({
    String? id,
    String? name,
    KernelStatus? status,
    int? executionCount,
    String? notebookId,
    DateTime? createdAt,
    DateTime? lastActivity,
  }) {
    return Kernel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      executionCount: executionCount ?? this.executionCount,
      notebookId: notebookId ?? this.notebookId,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  factory Kernel.fromJson(Map<String, dynamic> json) {
    return Kernel(
      id: json['id'] as String? ?? json['kernel_id'] as String,
      name: json['name'] as String? ?? 'python3',
      status: KernelStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => KernelStatus.idle,
      ),
      executionCount: json['execution_count'] as int? ?? 0,
      notebookId: json['notebook_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'execution_count': executionCount,
        'notebook_id': notebookId,
        'created_at': createdAt.toIso8601String(),
        'last_activity': lastActivity.toIso8601String(),
      };
}
