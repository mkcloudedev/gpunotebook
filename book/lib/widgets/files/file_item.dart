import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/file_info.dart';

class FileItem extends StatefulWidget {
  final FileInfo file;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const FileItem({
    super.key,
    required this.file,
    this.onTap,
    this.onDelete,
  });

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted.withOpacity(0.5) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.file.isDirectory
                          ? 'Directory'
                          : widget.file.sizeFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(widget.file.modifiedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              if (_isHovered) ...[
                const SizedBox(width: 12),
                _ActionButton(
                  icon: LucideIcons.trash2,
                  onTap: widget.onDelete,
                  isDestructive: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final (icon, color) = _getFileIconAndColor();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  (IconData, Color) _getFileIconAndColor() {
    if (widget.file.isDirectory) {
      return (LucideIcons.folder, AppColors.warning);
    }

    final ext = widget.file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'py':
        return (LucideIcons.fileCode, const Color(0xFF3776AB));
      case 'ipynb':
        return (LucideIcons.fileCode, AppColors.warning);
      case 'js':
      case 'ts':
        return (LucideIcons.fileCode, const Color(0xFFF7DF1E));
      case 'json':
        return (LucideIcons.braces, AppColors.success);
      case 'md':
        return (LucideIcons.fileText, AppColors.mutedForeground);
      case 'csv':
      case 'xlsx':
        return (LucideIcons.fileSpreadsheet, AppColors.success);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return (LucideIcons.image, AppColors.primary);
      case 'pdf':
        return (LucideIcons.file, AppColors.destructive);
      default:
        return (LucideIcons.file, AppColors.mutedForeground);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    this.onTap,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(6),
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
    );
  }
}
