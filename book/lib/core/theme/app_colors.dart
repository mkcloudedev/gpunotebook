import 'package:flutter/material.dart';
import 'theme_provider.dart';

/// Color scheme that supports light and dark themes
/// Static colors are const for compatibility, dynamic colors use getters
class AppColors {
  // Private constructor
  AppColors._();

  // Theme check helper
  static bool get _isDark => themeProvider.isDarkMode;

  // ===== PRIMARY COLORS (constant - same in both themes) =====
  static const Color primary = Color(0xFF3B82F6);  // Blue 500
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // ===== STATUS COLORS (constant - same in both themes) =====
  static const Color success = Color(0xFF22C55E);     // Green 500
  static const Color warning = Color(0xFFF59E0B);     // Amber 500
  static const Color destructive = Color(0xFFEF4444); // Red 500

  // ===== CODE COLORS (constant) =====
  static const Color codeText = Color(0xFF2563EB);    // Blue 600
  static const Color codeKeyword = Color(0xFF7C3AED); // Purple 600
  static const Color codeString = Color(0xFF16A34A);  // Green 600

  // ===== SIDEBAR COLORS (constant - always dark) =====
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarFg = Color(0xFFF8FAFC);
  static const Color sidebarMuted = Color(0xFF94A3B8);
  static const Color sidebarActive = Color(0xFF3B82F6);
  static const Color sidebarHover = Color(0xFF1E293B);

  // ===== THEME-AWARE COLORS (getters for dynamic colors) =====

  // Background colors
  static Color get background => _isDark
      ? const Color(0xFF0F172A)  // Dark: Slate 900
      : const Color(0xFFF8FAFC); // Light: Slate 50

  static Color get foreground => _isDark
      ? const Color(0xFFF8FAFC)  // Dark: Light text
      : const Color(0xFF0F172A); // Light: Dark text

  // Card colors
  static Color get card => _isDark
      ? const Color(0xFF1E293B)  // Dark: Slate 800
      : const Color(0xFFFFFFFF); // Light: White

  static Color get cardForeground => _isDark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF0F172A);

  // Secondary colors
  static Color get secondary => _isDark
      ? const Color(0xFF1E293B)  // Dark: Slate 800
      : const Color(0xFFF1F5F9); // Light: Slate 100

  static Color get secondaryForeground => _isDark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF0F172A);

  // Muted colors
  static Color get muted => _isDark
      ? const Color(0xFF334155)  // Dark: Slate 700
      : const Color(0xFFE2E8F0); // Light: Slate 200

  static Color get mutedForeground => _isDark
      ? const Color(0xFF94A3B8)  // Dark: Slate 400
      : const Color(0xFF64748B); // Light: Slate 500

  // Border color
  static Color get border => _isDark
      ? const Color(0xFF334155)  // Dark: Slate 700
      : const Color(0xFFE2E8F0); // Light: Slate 200

  // Code background
  static Color get codeBg => _isDark
      ? const Color(0xFF1E293B)  // Dark: Slate 800
      : const Color(0xFFF1F5F9); // Light: Slate 100

  static Color get codeComment => _isDark
      ? const Color(0xFF64748B)  // Dark: Slate 500
      : const Color(0xFF94A3B8); // Light: Slate 400

  // Accent colors
  static Color get accent => _isDark
      ? const Color(0xFF1E293B)
      : const Color(0xFFF1F5F9);

  static Color get accentForeground => _isDark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF0F172A);

  // Input colors
  static Color get inputBg => _isDark
      ? const Color(0xFF0F172A)
      : const Color(0xFFFFFFFF);

  static Color get inputBorder => _isDark
      ? const Color(0xFF334155)
      : const Color(0xFFCBD5E1);

  // Popover colors
  static Color get popoverBg => _isDark
      ? const Color(0xFF1E293B)
      : const Color(0xFFFFFFFF);

  static Color get popoverForeground => _isDark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF0F172A);

  // Hover colors
  static Color get hover => _isDark
      ? const Color(0xFF1E293B)
      : const Color(0xFFF1F5F9);

  // ===== SYNTAX HIGHLIGHTING (dynamic for theme) =====
  static Color get syntaxKeyword => _isDark
      ? const Color(0xFFFF79C6)  // Pink (Dracula)
      : const Color(0xFFD73A49); // Red (GitHub Light)

  static Color get syntaxBuiltin => _isDark
      ? const Color(0xFF8BE9FD)  // Cyan (Dracula)
      : const Color(0xFF005CC5); // Blue (GitHub Light)

  static Color get syntaxString => _isDark
      ? const Color(0xFFF1FA8C)  // Yellow (Dracula)
      : const Color(0xFF032F62); // Dark Blue (GitHub Light)

  static Color get syntaxComment => _isDark
      ? const Color(0xFF6272A4)  // Gray (Dracula)
      : const Color(0xFF6A737D); // Gray (GitHub Light)

  static Color get syntaxNumber => _isDark
      ? const Color(0xFFBD93F9)  // Purple (Dracula)
      : const Color(0xFF005CC5); // Blue (GitHub Light)

  static Color get syntaxFunction => _isDark
      ? const Color(0xFF50FA7B)  // Green (Dracula)
      : const Color(0xFF6F42C1); // Purple (GitHub Light)

  static Color get syntaxDecorator => _isDark
      ? const Color(0xFFFFB86C)  // Orange (Dracula)
      : const Color(0xFFE36209); // Orange (GitHub Light)

  static Color get syntaxClassName => _isDark
      ? const Color(0xFF8BE9FD)  // Cyan (Dracula)
      : const Color(0xFF6F42C1); // Purple (GitHub Light)

  static Color get syntaxOperator => _isDark
      ? const Color(0xFFFF79C6)  // Pink (Dracula)
      : const Color(0xFFD73A49); // Red (GitHub Light)
}
