import 'package:flutter/services.dart';

/// Represents a keyboard shortcut action
enum ShortcutAction {
  // Cell operations
  runCell,
  runCellAndAdvance,
  runAllCells,
  addCodeCellAbove,
  addCodeCellBelow,
  addMarkdownCellAbove,
  addMarkdownCellBelow,
  deleteCell,
  duplicateCell,
  moveCellUp,
  moveCellDown,

  // Navigation
  selectCellAbove,
  selectCellBelow,
  focusEditor,

  // Edit operations
  save,
  undo,
  redo,
  cut,
  copy,
  paste,
  selectAll,

  // View
  toggleVariables,
  togglePackages,
  toggleOutline,
  toggleSplitView,
  toggleAIChat,
  clearOutputs,

  // Misc
  showCommandPalette,
  showKeyboardShortcuts,
}

/// Extension to get display name for actions
extension ShortcutActionExtension on ShortcutAction {
  String get displayName {
    switch (this) {
      case ShortcutAction.runCell:
        return 'Run Cell';
      case ShortcutAction.runCellAndAdvance:
        return 'Run Cell & Advance';
      case ShortcutAction.runAllCells:
        return 'Run All Cells';
      case ShortcutAction.addCodeCellAbove:
        return 'Add Code Cell Above';
      case ShortcutAction.addCodeCellBelow:
        return 'Add Code Cell Below';
      case ShortcutAction.addMarkdownCellAbove:
        return 'Add Markdown Cell Above';
      case ShortcutAction.addMarkdownCellBelow:
        return 'Add Markdown Cell Below';
      case ShortcutAction.deleteCell:
        return 'Delete Cell';
      case ShortcutAction.duplicateCell:
        return 'Duplicate Cell';
      case ShortcutAction.moveCellUp:
        return 'Move Cell Up';
      case ShortcutAction.moveCellDown:
        return 'Move Cell Down';
      case ShortcutAction.selectCellAbove:
        return 'Select Cell Above';
      case ShortcutAction.selectCellBelow:
        return 'Select Cell Below';
      case ShortcutAction.focusEditor:
        return 'Focus Editor';
      case ShortcutAction.save:
        return 'Save';
      case ShortcutAction.undo:
        return 'Undo';
      case ShortcutAction.redo:
        return 'Redo';
      case ShortcutAction.cut:
        return 'Cut';
      case ShortcutAction.copy:
        return 'Copy';
      case ShortcutAction.paste:
        return 'Paste';
      case ShortcutAction.selectAll:
        return 'Select All';
      case ShortcutAction.toggleVariables:
        return 'Toggle Variables Panel';
      case ShortcutAction.togglePackages:
        return 'Toggle Packages Panel';
      case ShortcutAction.toggleOutline:
        return 'Toggle Outline Panel';
      case ShortcutAction.toggleSplitView:
        return 'Toggle Split View';
      case ShortcutAction.toggleAIChat:
        return 'Toggle AI Chat';
      case ShortcutAction.clearOutputs:
        return 'Clear All Outputs';
      case ShortcutAction.showCommandPalette:
        return 'Show Command Palette';
      case ShortcutAction.showKeyboardShortcuts:
        return 'Show Keyboard Shortcuts';
    }
  }

  String get category {
    switch (this) {
      case ShortcutAction.runCell:
      case ShortcutAction.runCellAndAdvance:
      case ShortcutAction.runAllCells:
      case ShortcutAction.addCodeCellAbove:
      case ShortcutAction.addCodeCellBelow:
      case ShortcutAction.addMarkdownCellAbove:
      case ShortcutAction.addMarkdownCellBelow:
      case ShortcutAction.deleteCell:
      case ShortcutAction.duplicateCell:
      case ShortcutAction.moveCellUp:
      case ShortcutAction.moveCellDown:
        return 'Cell Operations';
      case ShortcutAction.selectCellAbove:
      case ShortcutAction.selectCellBelow:
      case ShortcutAction.focusEditor:
        return 'Navigation';
      case ShortcutAction.save:
      case ShortcutAction.undo:
      case ShortcutAction.redo:
      case ShortcutAction.cut:
      case ShortcutAction.copy:
      case ShortcutAction.paste:
      case ShortcutAction.selectAll:
        return 'Edit';
      case ShortcutAction.toggleVariables:
      case ShortcutAction.togglePackages:
      case ShortcutAction.toggleOutline:
      case ShortcutAction.toggleSplitView:
      case ShortcutAction.toggleAIChat:
      case ShortcutAction.clearOutputs:
        return 'View';
      case ShortcutAction.showCommandPalette:
      case ShortcutAction.showKeyboardShortcuts:
        return 'Misc';
    }
  }
}

/// Represents a keyboard shortcut binding
class KeyboardShortcut {
  final ShortcutAction action;
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta; // Command on macOS

  const KeyboardShortcut({
    required this.action,
    required this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  /// Create from JSON
  factory KeyboardShortcut.fromJson(Map<String, dynamic> json) {
    return KeyboardShortcut(
      action: ShortcutAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => ShortcutAction.runCell,
      ),
      key: LogicalKeyboardKey.findKeyByKeyId(json['keyId'] ?? 0) ??
          LogicalKeyboardKey.space,
      ctrl: json['ctrl'] ?? false,
      shift: json['shift'] ?? false,
      alt: json['alt'] ?? false,
      meta: json['meta'] ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'keyId': key.keyId,
      'ctrl': ctrl,
      'shift': shift,
      'alt': alt,
      'meta': meta,
    };
  }

  /// Copy with modifications
  KeyboardShortcut copyWith({
    ShortcutAction? action,
    LogicalKeyboardKey? key,
    bool? ctrl,
    bool? shift,
    bool? alt,
    bool? meta,
  }) {
    return KeyboardShortcut(
      action: action ?? this.action,
      key: key ?? this.key,
      ctrl: ctrl ?? this.ctrl,
      shift: shift ?? this.shift,
      alt: alt ?? this.alt,
      meta: meta ?? this.meta,
    );
  }

  /// Check if this shortcut matches a key event
  bool matches(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final keyboard = HardwareKeyboard.instance;

    return event.logicalKey == key &&
        keyboard.isControlPressed == ctrl &&
        keyboard.isShiftPressed == shift &&
        keyboard.isAltPressed == alt &&
        keyboard.isMetaPressed == meta;
  }

  /// Get display string for the shortcut
  String get displayString {
    final parts = <String>[];

    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    if (meta) parts.add('Cmd');

    parts.add(_getKeyLabel(key));

    return parts.join(' + ');
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    // Handle special keys
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'PgUp';
    if (key == LogicalKeyboardKey.pageDown) return 'PgDn';

    // F keys
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';

    // Get key label from the key itself
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();

    return '?';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyboardShortcut &&
        other.key == key &&
        other.ctrl == ctrl &&
        other.shift == shift &&
        other.alt == alt &&
        other.meta == meta;
  }

  @override
  int get hashCode => Object.hash(key, ctrl, shift, alt, meta);
}
