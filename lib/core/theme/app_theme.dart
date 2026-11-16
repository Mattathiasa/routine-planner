import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_theme.dart';

/// The app's light theme (exact values from the approved v3 design) and
/// the dark theme derived from the same tokens ([AppColorsDark]). A
/// manual [ColorScheme] is used rather than [ColorScheme.fromSeed]: the
/// design has specific exact colors a seed's algorithmic tonal palette
/// wouldn't reproduce. Both themes register the [AppColorScheme]
/// extension that `context.colors` resolves.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColorScheme.light, Brightness.light);

  static ThemeData dark() => _build(AppColorScheme.dark, Brightness.dark);

  static ThemeData _build(AppColorScheme colors, Brightness brightness) {
    final onPrimary = brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF10142E);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.primaryHover,
      secondary: colors.primary,
      onSecondary: onPrimary,
      error: brightness == Brightness.light
          ? const Color(0xFFBA1A1A)
          : const Color(0xFFFFB4AB),
      onError: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF690005),
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: buildAppTextTheme(colors),
      fontFamily: GoogleFonts.inter().fontFamily,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      extensions: [colors],
    );
  }
}
