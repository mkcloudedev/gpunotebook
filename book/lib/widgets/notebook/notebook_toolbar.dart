import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class NotebookToolbar extends StatelessWidget {
  final VoidCallback? onAddCodeCell;
  final VoidCallback? onAddMarkdownCell;
  final VoidCallback? onRunAll;
  final VoidCallback? onClearOutputs;
  final VoidCallback? onSave;
  final VoidCallback? onToggleVariables;
  final VoidCallback? onTogglePackages;
  final VoidCallback? onToggleOutline;
  final VoidCallback? onShowKeyboardShortcuts;
  final bool showVariables;
  final bool showPackages;
  final bool showOutline;

  const NotebookToolbar({
    super.key,
    this.onAddCodeCell,
    this.onAddMarkdownCell,
    this.onRunAll,
    this.onClearOutputs,
    this.onSave,
    this.onToggleVariables,
    this.onTogglePackages,
    this.onToggleOutline,
    this.onShowKeyboardShortcuts,
    this.showVariables = false,
    this.showPackages = false,
    this.showOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: LucideIcons.plus,
            label: 'Code',
            onTap: onAddCodeCell,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: LucideIcons.type,
            label: 'Markdown',
            onTap: onAddMarkdownCell,
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 24,
            color: AppColors.border,
          ),
          const SizedBox(width: 16),
          _ToolbarButton(
            icon: LucideIcons.playCircle,
            label: 'Run All',
            onTap: onRunAll,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: LucideIcons.eraser,
            label: 'Clear Outputs',
            onTap: onClearOutputs,
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 24,
            color: AppColors.border,
          ),
          const SizedBox(width: 16),
          _ToolbarToggleButton(
            icon: LucideIcons.list,
            label: 'Outline',
            isActive: showOutline,
            onTap: onToggleOutline,
          ),
          const SizedBox(width: 8),
          _ToolbarToggleButton(
            icon: LucideIcons.variable,
            label: 'Variables',
            isActive: showVariables,
            onTap: onToggleVariables,
          ),
          const SizedBox(width: 8),
          _ToolbarToggleButton(
            icon: LucideIcons.package,
            label: 'Packages',
            isActive: showPackages,
            onTap: onTogglePackages,
          ),
          const Spacer(),
          _ToolbarToggleButton(
            icon: LucideIcons.keyboard,
            label: 'Keyboard Shortcuts',
            isActive: false,
            onTap: onShowKeyboardShortcuts,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: LucideIcons.save,
            label: 'Save',
            onTap: onSave,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? AppColors.primary
                : _isHovered
                    ? AppColors.muted
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: _isHovered ? AppColors.border : Colors.transparent,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isPrimary
                    ? AppColors.primaryForeground
                    : _isHovered
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isPrimary
                      ? AppColors.primaryForeground
                      : _isHovered
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarToggleButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToolbarToggleButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<_ToolbarToggleButton> createState() => _ToolbarToggleButtonState();
}

class _ToolbarToggleButtonState extends State<_ToolbarToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.label,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : _isHovered
                      ? AppColors.muted
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withOpacity(0.3)
                    : _isHovered
                        ? AppColors.border
                        : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: isActive
                  ? AppColors.primary
                  : _isHovered
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
