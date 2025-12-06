import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/keyboard_shortcut.dart';
import '../../services/keyboard_shortcuts_service.dart';

/// Dialog to view and customize keyboard shortcuts
class KeyboardShortcutsDialog extends StatefulWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  State<KeyboardShortcutsDialog> createState() => _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<KeyboardShortcutsDialog> {
  String _searchQuery = '';
  String? _selectedCategory;
  ShortcutAction? _editingAction;

  @override
  Widget build(BuildContext context) {
    final groupedShortcuts = keyboardShortcutsService.getShortcutsByCategory();
    final categories = groupedShortcuts.keys.toList();

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        height: 550,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.keyboard,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const Spacer(),
                // Reset all button
                TextButton.icon(
                  onPressed: _resetAllShortcuts,
                  icon: Icon(LucideIcons.rotateCcw, size: 14),
                  label: Text('Reset All'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 18),
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search and filter
            Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search shortcuts...',
                        hintStyle: TextStyle(color: AppColors.mutedForeground),
                        prefixIcon: Icon(LucideIcons.search, size: 16, color: AppColors.mutedForeground),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(fontSize: 14, color: AppColors.foreground),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Category filter
                Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: Text('All Categories', style: TextStyle(color: AppColors.mutedForeground)),
                      icon: Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
                      dropdownColor: AppColors.card,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Categories', style: TextStyle(color: AppColors.foreground)),
                        ),
                        ...categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat, style: TextStyle(color: AppColors.foreground)),
                        )),
                      ],
                      onChanged: (value) => setState(() => _selectedCategory = value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Shortcuts list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView(
                  padding: EdgeInsets.all(8),
                  children: categories
                      .where((cat) => _selectedCategory == null || cat == _selectedCategory)
                      .map((category) {
                    final shortcuts = groupedShortcuts[category]!
                        .where((s) => _searchQuery.isEmpty ||
                            s.action.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();

                    if (shortcuts.isEmpty) return const SizedBox.shrink();

                    return _CategorySection(
                      category: category,
                      shortcuts: shortcuts,
                      editingAction: _editingAction,
                      onEdit: (action) => setState(() => _editingAction = action),
                      onSaveEdit: _saveShortcut,
                      onCancelEdit: () => setState(() => _editingAction = null),
                      onReset: _resetShortcut,
                    );
                  }).toList(),
                ),
              ),
            ),

            // Footer hint
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Click on a shortcut to customize it. Press the new key combination when editing.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetAllShortcuts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Reset All Shortcuts?', style: TextStyle(color: AppColors.foreground)),
        content: Text(
          'This will reset all keyboard shortcuts to their default values.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Reset All', style: TextStyle(color: AppColors.primaryForeground)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await keyboardShortcutsService.resetAllShortcuts();
      setState(() {});
    }
  }

  Future<void> _resetShortcut(ShortcutAction action) async {
    await keyboardShortcutsService.resetShortcut(action);
    setState(() => _editingAction = null);
  }

  Future<void> _saveShortcut(ShortcutAction action, KeyboardShortcut shortcut) async {
    // Check for conflicts
    final conflicts = keyboardShortcutsService.findConflicts(shortcut);
    if (conflicts.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Shortcut Conflict', style: TextStyle(color: AppColors.foreground)),
            ],
          ),
          content: Text(
            'This shortcut is already used by:\n${conflicts.map((c) => '• ${c.action.displayName}').join('\n')}\n\nDo you want to override?',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              child: Text('Override', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    await keyboardShortcutsService.updateShortcut(action, shortcut);
    setState(() => _editingAction = null);
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<KeyboardShortcut> shortcuts;
  final ShortcutAction? editingAction;
  final Function(ShortcutAction) onEdit;
  final Function(ShortcutAction, KeyboardShortcut) onSaveEdit;
  final VoidCallback onCancelEdit;
  final Function(ShortcutAction) onReset;

  const _CategorySection({
    required this.category,
    required this.shortcuts,
    required this.editingAction,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Shortcuts in this category
        ...shortcuts.map((shortcut) {
          final isEditing = editingAction == shortcut.action;
          return _ShortcutRow(
            shortcut: shortcut,
            isEditing: isEditing,
            onTap: () => onEdit(shortcut.action),
            onSave: (newShortcut) => onSaveEdit(shortcut.action, newShortcut),
            onCancel: onCancelEdit,
            onReset: () => onReset(shortcut.action),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final KeyboardShortcut shortcut;
  final bool isEditing;
  final VoidCallback onTap;
  final Function(KeyboardShortcut) onSave;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  const _ShortcutRow({
    required this.shortcut,
    required this.isEditing,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
    required this.onReset,
  });

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  bool _isHovered = false;
  final FocusNode _focusNode = FocusNode();

  // Captured keys when editing
  LogicalKeyboardKey? _capturedKey;
  bool _capturedCtrl = false;
  bool _capturedShift = false;
  bool _capturedAlt = false;
  bool _capturedMeta = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _startEditing();
    }
  }

  @override
  void didUpdateWidget(_ShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      _startEditing();
    } else if (!widget.isEditing && oldWidget.isEditing) {
      _resetCapture();
    }
  }

  void _startEditing() {
    _capturedKey = widget.shortcut.key;
    _capturedCtrl = widget.shortcut.ctrl;
    _capturedShift = widget.shortcut.shift;
    _capturedAlt = widget.shortcut.alt;
    _capturedMeta = widget.shortcut.meta;
    Future.microtask(() => _focusNode.requestFocus());
  }

  void _resetCapture() {
    _capturedKey = null;
    _capturedCtrl = false;
    _capturedShift = false;
    _capturedAlt = false;
    _capturedMeta = false;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ignore modifier-only presses
      if (_isModifierKey(event.logicalKey)) {
        setState(() {
          _capturedCtrl = HardwareKeyboard.instance.isControlPressed;
          _capturedShift = HardwareKeyboard.instance.isShiftPressed;
          _capturedAlt = HardwareKeyboard.instance.isAltPressed;
          _capturedMeta = HardwareKeyboard.instance.isMetaPressed;
        });
        return;
      }

      // Escape cancels editing
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onCancel();
        return;
      }

      // Capture the key with modifiers
      setState(() {
        _capturedKey = event.logicalKey;
        _capturedCtrl = HardwareKeyboard.instance.isControlPressed;
        _capturedShift = HardwareKeyboard.instance.isShiftPressed;
        _capturedAlt = HardwareKeyboard.instance.isAltPressed;
        _capturedMeta = HardwareKeyboard.instance.isMetaPressed;
      });
    }
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  void _saveShortcut() {
    if (_capturedKey != null) {
      widget.onSave(KeyboardShortcut(
        action: widget.shortcut.action,
        key: _capturedKey!,
        ctrl: _capturedCtrl,
        shift: _capturedShift,
        alt: _capturedAlt,
        meta: _capturedMeta,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      return _buildEditingRow();
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.shortcut.action.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              _ShortcutBadge(shortcut: widget.shortcut),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditingRow() {
    final displayShortcut = _capturedKey != null
        ? KeyboardShortcut(
            action: widget.shortcut.action,
            key: _capturedKey!,
            ctrl: _capturedCtrl,
            shift: _capturedShift,
            alt: _capturedAlt,
            meta: _capturedMeta,
          )
        : widget.shortcut;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.shortcut.action.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Press new key combination or Esc to cancel',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _ShortcutBadge(shortcut: displayShortcut, isEditing: true),
            const SizedBox(width: 8),
            // Reset button
            IconButton(
              onPressed: widget.onReset,
              icon: Icon(LucideIcons.rotateCcw, size: 14),
              tooltip: 'Reset to default',
              color: AppColors.mutedForeground,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Save button
            IconButton(
              onPressed: _saveShortcut,
              icon: Icon(LucideIcons.check, size: 14),
              tooltip: 'Save',
              color: AppColors.success,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Cancel button
            IconButton(
              onPressed: widget.onCancel,
              icon: Icon(LucideIcons.x, size: 14),
              tooltip: 'Cancel',
              color: AppColors.destructive,
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final KeyboardShortcut shortcut;
  final bool isEditing;

  const _ShortcutBadge({required this.shortcut, this.isEditing = false});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    if (shortcut.ctrl) parts.add('Ctrl');
    if (shortcut.alt) parts.add('Alt');
    if (shortcut.shift) parts.add('Shift');
    if (shortcut.meta) parts.add('Cmd');
    parts.add(_getKeyLabel(shortcut.key));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts.map((part) {
        final isLast = part == parts.last;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEditing ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEditing ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  color: isEditing ? AppColors.primaryForeground : AppColors.foreground,
                ),
              ),
            ),
            if (!isLast)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.backspace) return '⌫';
    if (key == LogicalKeyboardKey.delete) return 'Del';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.backslash) return '\\';
    if (key == LogicalKeyboardKey.slash) return '/';

    // F keys
    for (int i = 1; i <= 12; i++) {
      if (key == LogicalKeyboardKey.findKeyByKeyId(0x00070000003A + i - 1)) {
        return 'F$i';
      }
    }

    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();

    return '?';
  }
}
