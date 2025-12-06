import 'package:flutter/material.dart';

/// Enum for theme modes
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Provider for managing app theme state
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark; // Default to dark theme

  AppThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    notifyListeners();
  }
}

/// Global theme provider instance
final themeProvider = ThemeProvider();

/// InheritedWidget for theme access
class ThemeScope extends InheritedNotifier<ThemeProvider> {
  const ThemeScope({
    super.key,
    required ThemeProvider themeProvider,
    required super.child,
  }) : super(notifier: themeProvider);

  static ThemeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope?.notifier ?? themeProvider;
  }
}
