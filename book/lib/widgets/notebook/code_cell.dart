import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/cell.dart';

class CodeCell extends StatefulWidget {
  final Cell cell;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final VoidCallback? onDelete;
  final void Function(String)? onSourceChange;

  const CodeCell({
    super.key,
    required this.cell,
    this.isSelected = false,
    this.onTap,
    this.onRun,
    this.onDelete,
    this.onSourceChange,
  });

  @override
  State<CodeCell> createState() => _CodeCellState();
}

class _CodeCellState extends State<CodeCell> {
  late TextEditingController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.cell.source);
  }

  @override
  void didUpdateWidget(CodeCell oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : _isHovered
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildCodeEditor(),
              if (widget.cell.outputs.isNotEmpty) _buildOutputs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
      ),
      child: Row(
        children: [
          _buildExecutionCount(),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _getStatusColor(),
              ),
            ),
          ),
          const Spacer(),
          if (_isHovered || widget.isSelected) _buildActions(),
        ],
      ),
    );
  }

  Widget _buildExecutionCount() {
    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.cell.executionCount != null
            ? '[${widget.cell.executionCount}]'
            : '[ ]',
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: LucideIcons.play,
          onTap: widget.onRun,
          tooltip: 'Run cell',
        ),
        _ActionButton(
          icon: LucideIcons.trash2,
          onTap: widget.onDelete,
          tooltip: 'Delete cell',
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        maxLines: null,
        style: AppTheme.monoStyle,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onSourceChange,
      ),
    );
  }

  Widget _buildOutputs() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.cell.outputs.map((output) {
          if (output.outputType == 'error') {
            return Text(
              output.evalue ?? 'Error',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.destructive,
              ),
            );
          }
          return Text(
            output.text ?? '',
            style: AppTheme.monoStyle,
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.cell.status) {
      case CellStatus.running:
        return AppColors.warning;
      case CellStatus.success:
        return AppColors.success;
      case CellStatus.error:
        return AppColors.destructive;
      case CellStatus.idle:
      default:
        return AppColors.mutedForeground;
    }
  }

  String _getStatusText() {
    switch (widget.cell.status) {
      case CellStatus.running:
        return 'Running';
      case CellStatus.success:
        return 'Success';
      case CellStatus.error:
        return 'Error';
      case CellStatus.idle:
      default:
        return 'Idle';
    }
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    this.onTap,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? AppColors.destructive : AppColors.foreground;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.all(6),
            margin: EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: _isHovered ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? color : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
