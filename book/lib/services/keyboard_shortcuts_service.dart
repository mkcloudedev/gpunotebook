import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/services.dart';
import '../models/keyboard_shortcut.dart';

/// Service to manage keyboard shortcuts
class KeyboardShortcutsService {
  static const _storageKey = 'gpu_notebook_keyboard_shortcuts';
  static KeyboardShortcutsService? _instance;
  static KeyboardShortcutsService get instance {
    _instance ??= KeyboardShortcutsService._();
    return _instance!;
  }

  KeyboardShortcutsService._();

  List<KeyboardShortcut> _shortcuts = [];
  List<KeyboardShortcut> get shortcuts => List.unmodifiable(_shortcuts);

  /// Initialize the service and load saved shortcuts
  Future<void> init() async {
    await _loadShortcuts();
  }

  /// Get default shortcuts
  static List<KeyboardShortcut> getDefaultShortcuts() {
    return [
      // Cell Operations
      KeyboardShortcut(
        action: ShortcutAction.runCell,
        key: LogicalKeyboardKey.enter,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.runCellAndAdvance,
        key: LogicalKeyboardKey.enter,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.runAllCells,
        key: LogicalKeyboardKey.f5,
      ),
      KeyboardShortcut(
        action: ShortcutAction.addCodeCellBelow,
        key: LogicalKeyboardKey.keyB,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.addCodeCellAbove,
        key: LogicalKeyboardKey.keyB,
        ctrl: true,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.addMarkdownCellBelow,
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.addMarkdownCellAbove,
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.deleteCell,
        key: LogicalKeyboardKey.keyD,
        ctrl: true,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.duplicateCell,
        key: LogicalKeyboardKey.keyD,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.moveCellUp,
        key: LogicalKeyboardKey.arrowUp,
        ctrl: true,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.moveCellDown,
        key: LogicalKeyboardKey.arrowDown,
        ctrl: true,
        shift: true,
      ),

      // Navigation
      KeyboardShortcut(
        action: ShortcutAction.selectCellAbove,
        key: LogicalKeyboardKey.arrowUp,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.selectCellBelow,
        key: LogicalKeyboardKey.arrowDown,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.focusEditor,
        key: LogicalKeyboardKey.enter,
      ),

      // Edit
      KeyboardShortcut(
        action: ShortcutAction.save,
        key: LogicalKeyboardKey.keyS,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.undo,
        key: LogicalKeyboardKey.keyZ,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.redo,
        key: LogicalKeyboardKey.keyZ,
        ctrl: true,
        shift: true,
      ),

      // View
      KeyboardShortcut(
        action: ShortcutAction.toggleVariables,
        key: LogicalKeyboardKey.keyV,
        ctrl: true,
        alt: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.togglePackages,
        key: LogicalKeyboardKey.keyP,
        ctrl: true,
        alt: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.toggleOutline,
        key: LogicalKeyboardKey.keyO,
        ctrl: true,
        alt: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.toggleSplitView,
        key: LogicalKeyboardKey.backslash,
        ctrl: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.toggleAIChat,
        key: LogicalKeyboardKey.keyI,
        ctrl: true,
        alt: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.clearOutputs,
        key: LogicalKeyboardKey.keyL,
        ctrl: true,
        shift: true,
      ),

      // Misc
      KeyboardShortcut(
        action: ShortcutAction.showCommandPalette,
        key: LogicalKeyboardKey.keyP,
        ctrl: true,
        shift: true,
      ),
      KeyboardShortcut(
        action: ShortcutAction.showKeyboardShortcuts,
        key: LogicalKeyboardKey.slash,
        ctrl: true,
      ),
    ];
  }

  /// Load shortcuts from localStorage
  Future<void> _loadShortcuts() async {
    try {
      final stored = html.window.localStorage[_storageKey];
      if (stored != null && stored.isNotEmpty) {
        final List<dynamic> data = jsonDecode(stored);
        _shortcuts = data.map((e) => KeyboardShortcut.fromJson(e)).toList();
      } else {
        _shortcuts = getDefaultShortcuts();
      }
    } catch (e) {
      _shortcuts = getDefaultShortcuts();
    }
  }

  /// Save shortcuts to localStorage
  Future<void> _saveShortcuts() async {
    try {
      final json = jsonEncode(_shortcuts.map((s) => s.toJson()).toList());
      html.window.localStorage[_storageKey] = json;
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Get shortcut for an action
  KeyboardShortcut? getShortcut(ShortcutAction action) {
    for (final shortcut in _shortcuts) {
      if (shortcut.action == action) {
        return shortcut;
      }
    }
    return null;
  }

  /// Update a shortcut
  Future<void> updateShortcut(ShortcutAction action, KeyboardShortcut newShortcut) async {
    final index = _shortcuts.indexWhere((s) => s.action == action);
    if (index >= 0) {
      _shortcuts[index] = newShortcut;
    } else {
      _shortcuts.add(newShortcut);
    }
    await _saveShortcuts();
  }

  /// Reset a shortcut to default
  Future<void> resetShortcut(ShortcutAction action) async {
    final defaults = getDefaultShortcuts();
    final defaultShortcut = defaults.firstWhere(
      (s) => s.action == action,
      orElse: () => KeyboardShortcut(action: action, key: LogicalKeyboardKey.space),
    );

    await updateShortcut(action, defaultShortcut);
  }

  /// Reset all shortcuts to default
  Future<void> resetAllShortcuts() async {
    _shortcuts = getDefaultShortcuts();
    await _saveShortcuts();
  }

  /// Check if a key event matches any shortcut
  ShortcutAction? matchEvent(KeyEvent event) {
    for (final shortcut in _shortcuts) {
      if (shortcut.matches(event)) {
        return shortcut.action;
      }
    }
    return null;
  }

  /// Check for conflicting shortcuts
  List<KeyboardShortcut> findConflicts(KeyboardShortcut shortcut) {
    return _shortcuts.where((s) {
      return s.action != shortcut.action &&
          s.key == shortcut.key &&
          s.ctrl == shortcut.ctrl &&
          s.shift == shortcut.shift &&
          s.alt == shortcut.alt &&
          s.meta == shortcut.meta;
    }).toList();
  }

  /// Get shortcuts grouped by category
  Map<String, List<KeyboardShortcut>> getShortcutsByCategory() {
    final Map<String, List<KeyboardShortcut>> grouped = {};

    for (final shortcut in _shortcuts) {
      final category = shortcut.action.category;
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(shortcut);
    }

    return grouped;
  }
}

/// Global instance
final keyboardShortcutsService = KeyboardShortcutsService.instance;
