import 'package:flutter/material.dart';

/// Tokens de design derivados de `specs/4 - frontend_flow.md`.
class AppColors {
  static const bg = Color(0xFF0F1419);
  static const surface = Color(0xFF1A2332);
  static const surface2 = Color(0xFF212D40);
  static const primary = Color(0xFF3B9EFF);
  static const accent = Color(0xFFF5A623);
  static const success = Color(0xFF34C759);
  static const danger = Color(0xFFFF453A);
  static const text = Color(0xFFE8ECF1);
  static const textMuted = Color(0xFF8B9CB3);
  static const border = Color(0xFF2B3A52);
}

ThemeData buildSintonizeTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.danger,
    onPrimary: Color(0xFF04121F),
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF04121F),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
