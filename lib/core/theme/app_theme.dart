import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_theme.dart';

/// The app's single (light-only) theme, built from the approved v3 design.
/// A manual [ColorScheme] is used rather than [ColorScheme.fromSeed]: the
/// design has specific exact colors a seed's algorithmic tonal palette
/// wouldn't reproduce.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primaryHover,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: buildAppTextTheme(),
      fontFamily: GoogleFonts.inter().fontFamily,
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
    );
  }
}
