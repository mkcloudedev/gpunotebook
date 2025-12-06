import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cell.dart';

/// Widget to display and manage cell tags
class CellTagsWidget extends StatelessWidget {
  final List<CellTag> tags;
  final Function(CellTag) onAddTag;
  final Function(CellTag) onRemoveTag;
  final bool isEditable;

  const CellTagsWidget({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && !isEditable) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Display existing tags
        ...tags.map((tag) => _TagChip(
              tag: tag,
              onRemove: isEditable ? () => onRemoveTag(tag) : null,
            )),
        // Add tag button
        if (isEditable)
          _AddTagButton(
            existingTags: tags,
            onAddTag: onAddTag,
          ),
      ],
    );
  }
}

class _TagChip extends StatefulWidget {
  final CellTag tag;
  final VoidCallback? onRemove;

  const _TagChip({
    required this.tag,
    this.onRemove,
  });

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tagColor = Color(widget.tag.color);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: tagColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tagColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tag icon based on type
            Icon(
              _getTagIcon(widget.tag.type),
              size: 10,
              color: tagColor,
            ),
            const SizedBox(width: 4),
            // Tag label
            Text(
              widget.tag.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: tagColor,
              ),
            ),
            // Remove button
            if (widget.onRemove != null && _isHovered) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onRemove,
                child: Icon(
                  LucideIcons.x,
                  size: 10,
                  color: tagColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getTagIcon(CellTagType type) {
    switch (type) {
      case CellTagType.important:
        return LucideIcons.alertCircle;
      case CellTagType.todo:
        return LucideIcons.checkSquare;
      case CellTagType.skip:
        return LucideIcons.skipForward;
      case CellTagType.slow:
        return LucideIcons.clock;
      case CellTagType.test:
        return LucideIcons.testTube2;
      case CellTagType.setup:
        return LucideIcons.settings;
      case CellTagType.cleanup:
        return LucideIcons.trash2;
      case CellTagType.visualization:
        return LucideIcons.lineChart;
      case CellTagType.dataLoad:
        return LucideIcons.database;
      case CellTagType.model:
        return LucideIcons.brain;
      case CellTagType.custom:
        return LucideIcons.tag;
    }
  }
}

class _AddTagButton extends StatefulWidget {
  final List<CellTag> existingTags;
  final Function(CellTag) onAddTag;

  const _AddTagButton({
    required this.existingTags,
    required this.onAddTag,
  });

  @override
  State<_AddTagButton> createState() => _AddTagButtonState();
}

class _AddTagButtonState extends State<_AddTagButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showTagMenu(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.muted
                : AppColors.muted.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.plus,
                size: 10,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 2),
              Text(
                'Tag',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<CellTag>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height + 200,
      ),
      items: _buildMenuItems(),
      elevation: 8,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
    ).then((selectedTag) {
      if (selectedTag != null) {
        widget.onAddTag(selectedTag);
      }
    });
  }

  List<PopupMenuEntry<CellTag>> _buildMenuItems() {
    final items = <PopupMenuEntry<CellTag>>[];

    // Predefined tags section
    items.add(
      PopupMenuItem<CellTag>(
        enabled: false,
        height: 24,
        child: Text(
          'PREDEFINED TAGS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    // Add predefined tags
    for (final type in CellTagType.values) {
      if (type == CellTagType.custom) continue;

      final tag = CellTag.predefined(type);
      final isAlreadyAdded = widget.existingTags.any((t) => t.type == type);

      items.add(
        PopupMenuItem<CellTag>(
          value: isAlreadyAdded ? null : tag,
          enabled: !isAlreadyAdded,
          height: 36,
          child: _TagMenuItem(tag: tag, isDisabled: isAlreadyAdded),
        ),
      );
    }

    // Custom tag section
    items.add(const PopupMenuDivider(height: 1));
    items.add(
      PopupMenuItem<CellTag>(
        height: 36,
        onTap: () {
          // Show custom tag dialog after menu closes
          Future.delayed(const Duration(milliseconds: 100), () {
            _showCustomTagDialog(context);
          });
        },
        child: Row(
          children: [
            Icon(LucideIcons.edit3, size: 14, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Create Custom Tag...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  void _showCustomTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CustomTagDialog(
        onCreateTag: (tag) {
          widget.onAddTag(tag);
        },
      ),
    );
  }
}

class _TagMenuItem extends StatelessWidget {
  final CellTag tag;
  final bool isDisabled;

  const _TagMenuItem({
    required this.tag,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = Color(tag.color);
    final opacity = isDisabled ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getTagIcon(tag.type),
              size: 10,
              color: tagColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tag.label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
          ),
          if (isDisabled)
            Icon(
              LucideIcons.check,
              size: 14,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  IconData _getTagIcon(CellTagType type) {
    switch (type) {
      case CellTagType.important:
        return LucideIcons.alertCircle;
      case CellTagType.todo:
        return LucideIcons.checkSquare;
      case CellTagType.skip:
        return LucideIcons.skipForward;
      case CellTagType.slow:
        return LucideIcons.clock;
      case CellTagType.test:
        return LucideIcons.testTube2;
      case CellTagType.setup:
        return LucideIcons.settings;
      case CellTagType.cleanup:
        return LucideIcons.trash2;
      case CellTagType.visualization:
        return LucideIcons.lineChart;
      case CellTagType.dataLoad:
        return LucideIcons.database;
      case CellTagType.model:
        return LucideIcons.brain;
      case CellTagType.custom:
        return LucideIcons.tag;
    }
  }
}

class _CustomTagDialog extends StatefulWidget {
  final Function(CellTag) onCreateTag;

  const _CustomTagDialog({required this.onCreateTag});

  @override
  State<_CustomTagDialog> createState() => _CustomTagDialogState();
}

class _CustomTagDialogState extends State<_CustomTagDialog> {
  final _controller = TextEditingController();
  int _selectedColor = 0xFF3B82F6;

  final _colorOptions = [
    0xFF3B82F6, // Blue
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF10B981, // Green
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF0EA5E9, // Sky
    0xFFF97316, // Orange
    0xFF14B8A6, // Teal
    0xFF6366F1, // Indigo
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 320,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.tag,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Custom Tag',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tag name input
            Text(
              'Tag Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'Enter tag name...',
                hintStyle: TextStyle(
                  color: AppColors.mutedForeground,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            Text(
              'Tag Color',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.foreground
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            LucideIcons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Preview
            Text(
              'Preview',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(_selectedColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Color(_selectedColor).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.tag,
                          size: 12,
                          color: Color(_selectedColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _controller.text.isEmpty
                              ? 'Custom Tag'
                              : _controller.text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(_selectedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final name = _controller.text.trim();
                    if (name.isNotEmpty) {
                      final tag = CellTag(
                        label: name,
                        type: CellTagType.custom,
                        color: _selectedColor,
                      );
                      widget.onCreateTag(tag);
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to view/edit cell metadata
class CellMetadataDialog extends StatefulWidget {
  final Cell cell;
  final Function(CellMetadata) onSave;

  const CellMetadataDialog({
    super.key,
    required this.cell,
    required this.onSave,
  });

  @override
  State<CellMetadataDialog> createState() => _CellMetadataDialogState();
}

class _CellMetadataDialogState extends State<CellMetadataDialog> {
  late TextEditingController _nameController;
  late bool _hidden;
  late bool _editable;
  late bool _deletable;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cell.metadata.name ?? '');
    _hidden = widget.cell.metadata.hidden;
    _editable = widget.cell.metadata.editable;
    _deletable = widget.cell.metadata.deletable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.info,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cell Metadata',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        'Cell ID: ${widget.cell.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cell name
            Text(
              'Cell Name (Optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'Give this cell a name...',
                hintStyle: TextStyle(color: AppColors.mutedForeground),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Properties
            Text(
              'Properties',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _PropertySwitch(
                    icon: LucideIcons.eyeOff,
                    label: 'Hidden',
                    description: 'Hide cell in read-only view',
                    value: _hidden,
                    onChanged: (v) => setState(() => _hidden = v),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _PropertySwitch(
                    icon: LucideIcons.lock,
                    label: 'Editable',
                    description: 'Allow editing cell content',
                    value: _editable,
                    onChanged: (v) => setState(() => _editable = v),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  _PropertySwitch(
                    icon: LucideIcons.trash2,
                    label: 'Deletable',
                    description: 'Allow deleting this cell',
                    value: _deletable,
                    onChanged: (v) => setState(() => _deletable = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.info, size: 14, color: AppColors.mutedForeground),
                      const SizedBox(width: 8),
                      Text(
                        'Cell Information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Type',
                    value: widget.cell.cellType.name.toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Status',
                    value: widget.cell.status.name,
                  ),
                  if (widget.cell.executionCount != null)
                    _InfoRow(
                      label: 'Execution #',
                      value: widget.cell.executionCount.toString(),
                    ),
                  _InfoRow(
                    label: 'Lines',
                    value: widget.cell.source.split('\n').length.toString(),
                  ),
                  _InfoRow(
                    label: 'Characters',
                    value: widget.cell.source.length.toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final metadata = widget.cell.metadata.copyWith(
                      name: _nameController.text.isEmpty ? null : _nameController.text,
                      hidden: _hidden,
                      editable: _editable,
                      deletable: _deletable,
                      lastModified: DateTime.now(),
                    );
                    widget.onSave(metadata);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertySwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final Function(bool) onChanged;

  const _PropertySwitch({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
