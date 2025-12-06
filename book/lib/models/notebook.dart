import 'cell.dart';

class Notebook {
  final String id;
  final String name;
  final List<Cell> cells;
  final String? kernelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Notebook({
    required this.id,
    required this.name,
    required this.cells,
    this.kernelId,
    required this.createdAt,
    required this.updatedAt,
  });

  Notebook copyWith({
    String? id,
    String? name,
    List<Cell>? cells,
    String? kernelId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id ?? this.id,
      name: name ?? this.name,
      cells: cells ?? this.cells,
      kernelId: kernelId ?? this.kernelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
