import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/notebook.dart';
import '../models/cell.dart';
import '../widgets/layout/main_layout.dart';

class NotebookEditorScreen extends StatefulWidget {
  final String notebookId;

  const NotebookEditorScreen({
    super.key,
    required this.notebookId,
  });

  @override
  State<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends State<NotebookEditorScreen> {
  late Notebook _notebook;
  String? _selectedCellId;
  String _kernelStatus = 'idle';

  @override
  void initState() {
    super.initState();
    _notebook = Notebook(
      id: widget.notebookId,
      name: 'Image Detection Model',
      cells: [
        const Cell(
          id: '1',
          cellType: CellType.code,
          source: 'import torch\nimport numpy as np\nfrom PIL import Image\n\nprint(f"PyTorch version: {torch.__version__}")\nprint(f"CUDA available: {torch.cuda.is_available()}")\nif torch.cuda.is_available():\n    print(f"GPU: {torch.cuda.get_device_name(0)}")',
          executionCount: 1,
          status: CellStatus.success,
          outputs: [
            CellOutput(outputType: 'stream', text: 'PyTorch version: 2.1.0\nCUDA available: True\nGPU: NVIDIA RTX 4090'),
          ],
        ),
        const Cell(
          id: '2',
          cellType: CellType.code,
          source: '# Load DINOv2 model\nmodel = torch.hub.load(\'facebookresearch/dinov2\', \'dinov2_vits14\')\nmodel = model.cuda()\nmodel.eval()\nprint("Model loaded successfully")',
          executionCount: 2,
          status: CellStatus.success,
          outputs: [
            CellOutput(outputType: 'stream', text: 'Downloading: 100%|██████████| 89.2M/89.2M [00:02<00:00, 35.2MB/s]\nModel loaded successfully'),
          ],
        ),
        const Cell(
          id: '3',
          cellType: CellType.code,
          source: '# This cell has an error\nx = undefined_variable',
          executionCount: 3,
          status: CellStatus.error,
          outputs: [
            CellOutput(outputType: 'error', text: 'NameError: name \'undefined_variable\' is not defined'),
          ],
        ),
        const Cell(
          id: '4',
          cellType: CellType.code,
          source: '# Ready to run\nprint("Hello, GPU Notebook!")',
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: _notebook.name,
      child: Column(
        children: [
          // Notebook Toolbar
          _buildToolbar(),
          // Cells
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      ..._notebook.cells.map((cell) => Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _CodeCellWidget(
                          cell: cell,
                          isSelected: cell.id == _selectedCellId,
                          onSelect: () => setState(() => _selectedCellId = cell.id),
                          onRun: () => _runCell(cell.id),
                          onChange: (source) => _updateCellSource(cell.id, source),
                          onDelete: () => _deleteCell(cell.id),
                          onMoveUp: () => _moveCell(cell.id, -1),
                          onMoveDown: () => _moveCell(cell.id, 1),
                        ),
                      )),
                      _buildAddCellButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Run All button
          _ToolbarButton(
            icon: LucideIcons.play,
            label: 'Run All',
            onTap: _runAllCells,
          ),
          const SizedBox(width: 8),
          // Stop button
          _ToolbarButton(
            icon: LucideIcons.square,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          // Restart button
          _ToolbarButton(
            icon: LucideIcons.rotateCcw,
            onTap: _restartKernel,
          ),
          Container(
            width: 1,
            height: 24,
            margin: EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.border,
          ),
          // Add Code cell
          _ToolbarButton(
            icon: LucideIcons.plus,
            label: 'Code',
            onTap: () => _addCell(CellType.code),
          ),
          const SizedBox(width: 8),
          // Add Markdown cell
          _ToolbarButton(
            icon: LucideIcons.plus,
            label: 'Markdown',
            onTap: () => _addCell(CellType.markdown),
          ),
          const Spacer(),
          // Clear outputs
          _ToolbarButton(
            icon: LucideIcons.eraser,
            label: 'Clear Outputs',
            onTap: _clearOutputs,
          ),
          const SizedBox(width: 8),
          // Save
          _ToolbarButton(
            icon: LucideIcons.save,
            label: 'Save',
            onTap: () {},
          ),
          Container(
            width: 1,
            height: 24,
            margin: EdgeInsets.symmetric(horizontal: 12),
            color: AppColors.border,
          ),
          // Kernel status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _kernelStatus == 'busy' ? AppColors.warning : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _kernelStatus == 'busy' ? 'Running' : 'Python 3.11',
                style: TextStyle(fontSize: 14, color: AppColors.foreground),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddCellButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AddCellButton(label: '+ Code', onTap: () => _addCell(CellType.code)),
          const SizedBox(width: 12),
          _AddCellButton(label: '+ Markdown', onTap: () => _addCell(CellType.markdown)),
        ],
      ),
    );
  }

  void _addCell(CellType type) {
    final newCell = Cell(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cellType: type,
      source: '',
    );
    setState(() {
      final cells = List<Cell>.from(_notebook.cells);
      cells.add(newCell);
      _notebook = _notebook.copyWith(cells: cells);
      _selectedCellId = newCell.id;
    });
  }

  void _deleteCell(String cellId) {
    setState(() {
      final cells = _notebook.cells.where((c) => c.id != cellId).toList();
      _notebook = _notebook.copyWith(cells: cells);
      if (_selectedCellId == cellId) _selectedCellId = null;
    });
  }

  void _moveCell(String cellId, int direction) {
    setState(() {
      final cells = List<Cell>.from(_notebook.cells);
      final index = cells.indexWhere((c) => c.id == cellId);
      if (index == -1) return;
      final newIndex = index + direction;
      if (newIndex < 0 || newIndex >= cells.length) return;
      final cell = cells.removeAt(index);
      cells.insert(newIndex, cell);
      _notebook = _notebook.copyWith(cells: cells);
    });
  }

  void _updateCellSource(String cellId, String source) {
    setState(() {
      final cells = _notebook.cells.map((cell) {
        if (cell.id == cellId) return cell.copyWith(source: source);
        return cell;
      }).toList();
      _notebook = _notebook.copyWith(cells: cells);
    });
  }

  void _runCell(String cellId) {
    setState(() {
      _kernelStatus = 'busy';
      final cells = _notebook.cells.map((cell) {
        if (cell.id == cellId) return cell.copyWith(status: CellStatus.running);
        return cell;
      }).toList();
      _notebook = _notebook.copyWith(cells: cells);
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _kernelStatus = 'idle';
          final cells = _notebook.cells.map((cell) {
            if (cell.id == cellId) {
              return cell.copyWith(
                status: CellStatus.success,
                executionCount: (cell.executionCount ?? 0) + 1,
                outputs: [const CellOutput(outputType: 'stream', text: 'Execution completed successfully!')],
              );
            }
            return cell;
          }).toList();
          _notebook = _notebook.copyWith(cells: cells);
        });
      }
    });
  }

  void _runAllCells() {
    for (final cell in _notebook.cells) {
      if (cell.cellType == CellType.code) {
        _runCell(cell.id);
      }
    }
  }

  void _clearOutputs() {
    setState(() {
      final cells = _notebook.cells.map((cell) {
        return cell.copyWith(outputs: [], executionCount: null, status: CellStatus.idle);
      }).toList();
      _notebook = _notebook.copyWith(cells: cells);
    });
  }

  void _restartKernel() {
    setState(() => _kernelStatus = 'starting');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _kernelStatus = 'idle');
    });
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, this.label, required this.onTap});

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.label != null ? 12 : 8, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: _isHovered ? AppColors.foreground : AppColors.mutedForeground),
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Text(widget.label!, style: TextStyle(fontSize: 13, color: _isHovered ? AppColors.foreground : AppColors.mutedForeground)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCellButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCellButton({required this.label, required this.onTap});

  @override
  State<_AddCellButton> createState() => _AddCellButtonState();
}

class _AddCellButtonState extends State<_AddCellButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isHovered ? AppColors.border : AppColors.muted),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 13, color: _isHovered ? AppColors.foreground : AppColors.mutedForeground),
          ),
        ),
      ),
    );
  }
}

class _CodeCellWidget extends StatefulWidget {
  final Cell cell;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onRun;
  final Function(String) onChange;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _CodeCellWidget({
    required this.cell,
    required this.isSelected,
    required this.onSelect,
    required this.onRun,
    required this.onChange,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_CodeCellWidget> createState() => _CodeCellWidgetState();
}

class _CodeCellWidgetState extends State<_CodeCellWidget> {
  late TextEditingController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cell.source);
  }

  @override
  void didUpdateWidget(_CodeCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cell.source != widget.cell.source) {
      _controller.text = widget.cell.source;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.cell.status) {
      case CellStatus.running:
        return AppColors.warning;
      case CellStatus.success:
        return AppColors.success;
      case CellStatus.error:
        return AppColors.destructive;
      default:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected ? AppColors.primary : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cell header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                  ),
                ),
                child: Row(
                  children: [
                    // Execution count
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        widget.cell.executionCount != null ? '[${widget.cell.executionCount}]' : '[ ]',
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: _statusColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                    ),
                    const Spacer(),
                    // Cell actions (visible on hover)
                    if (_isHovered || widget.isSelected) ...[
                      _CellAction(icon: LucideIcons.play, onTap: widget.onRun),
                      _CellAction(icon: LucideIcons.chevronUp, onTap: widget.onMoveUp),
                      _CellAction(icon: LucideIcons.chevronDown, onTap: widget.onMoveDown),
                      _CellAction(icon: LucideIcons.copy, onTap: () {}),
                      _CellAction(icon: LucideIcons.trash2, onTap: widget.onDelete),
                    ],
                  ],
                ),
              ),
              // Code editor
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 60),
                padding: EdgeInsets.all(12),
                color: AppColors.codeBg,
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  style: AppTheme.monoStyle,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: widget.onChange,
                ),
              ),
              // Output
              if (widget.cell.outputs.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.cell.outputs.map((output) {
                      final isError = output.outputType == 'error';
                      return SelectableText(
                        output.text ?? '',
                        style: AppTheme.monoStyle.copyWith(
                          color: isError ? AppColors.destructive : AppColors.foreground,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CellAction({required this.icon, required this.onTap});

  @override
  State<_CellAction> createState() => _CellActionState();
}

class _CellActionState extends State<_CellAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            widget.icon,
            size: 14,
            color: _isHovered ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
