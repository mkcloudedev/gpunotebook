import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'theme_provider.dart';

class AppTheme {
  /// Get the current theme based on theme provider
  static ThemeData get theme => themeProvider.isDarkMode ? darkTheme : lightTheme;

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFFF1F5F9),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme().apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF64748B),
        size: 16,
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF1E293B),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme().apply(
        bodyColor: const Color(0xFFF8FAFC),
        displayColor: const Color(0xFFF8FAFC),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF94A3B8),
        size: 16,
      ),
    );
  }

  static TextStyle get monoStyle {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      color: AppColors.foreground,
    );
  }

  static TextStyle get codeKeyword {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      color: AppColors.syntaxKeyword,
    );
  }

  static TextStyle get codeString {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      color: AppColors.syntaxString,
    );
  }

  static TextStyle get codeText {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      color: AppColors.codeText,
    );
  }

  static TextStyle get codeComment {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      color: AppColors.syntaxComment,
      fontStyle: FontStyle.italic,
    );
  }
}
