import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the app's [TextTheme] from the archetypes found in the approved
/// v3 design. Colors here are sensible defaults — screens frequently
/// override them per-context (e.g. white text on the gradient hero card)
/// via `copyWith`. Manrope is used for numerals and page/section headings
/// (with the design's letter-spacing, converted from em to logical
/// pixels); Inter is the default for everything else, including titles.
TextTheme buildAppTextTheme() {
  TextStyle manrope(double size, FontWeight weight, double letterSpacingEm, Color color) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacingEm * size,
      color: color,
      height: 1,
    );
  }

  TextStyle inter(double size, FontWeight weight, Color color) {
    return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
  }

  return TextTheme(
    // Page titles (e.g. "Friday", "Resin", "Planner", "Settings").
    displayLarge: manrope(40, FontWeight.w800, -0.03, AppColors.textPrimary),
    displayMedium: manrope(36, FontWeight.w800, -0.03, AppColors.textPrimary),
    displaySmall: manrope(22, FontWeight.w800, -0.02, AppColors.textPrimary),

    // Section headers and bold stat values (e.g. "Today's farm", "5:12").
    headlineLarge: manrope(20, FontWeight.w800, -0.02, AppColors.textPrimary),
    headlineMedium: manrope(17, FontWeight.w800, -0.01, AppColors.textPrimary),
    headlineSmall: inter(17, FontWeight.w700, AppColors.textPrimary),

    // Card/row titles and button labels.
    titleLarge: inter(15, FontWeight.w700, AppColors.textPrimary),
    titleMedium: inter(15, FontWeight.w600, AppColors.textPrimary),
    titleSmall: inter(14, FontWeight.w600, AppColors.textPrimary),

    // Secondary/body text — captions, subtitles, chip text.
    bodyLarge: inter(13, FontWeight.w400, AppColors.textSecondary),
    bodyMedium: inter(12, FontWeight.w400, AppColors.textSecondary),
    bodySmall: inter(11, FontWeight.w600, AppColors.textSecondary),

    // Labels — nav/button text, micro-captions.
    labelLarge: inter(14, FontWeight.w700, AppColors.textPrimary),
    labelMedium: inter(13, FontWeight.w600, AppColors.textSecondary),
    labelSmall: inter(11, FontWeight.w600, AppColors.textSecondary),
  );
}

/// The two giant display numbers that don't fit the standard [TextTheme]
/// scale: the Today hero card's resin count (52px) and the Resin screen's
/// big ring number (60px).
abstract final class AppDisplayNumbers {
  static TextStyle heroNumber({Color color = Colors.white}) {
    return GoogleFonts.manrope(
      fontSize: 52,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.03 * 52,
      color: color,
      height: 1,
    );
  }

  static TextStyle ringNumber({Color color = AppColors.textPrimary}) {
    return GoogleFonts.manrope(
      fontSize: 60,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.04 * 60,
      color: color,
      height: 1,
    );
  }
}
