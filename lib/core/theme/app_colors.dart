import 'package:flutter/painting.dart';

/// Exact colors from the approved v3 design (`design/v3/*.dc.html`). Light
/// base only — the mockups have no dark-mode counterpart to derive one
/// from.
abstract final class AppColors {
  // Neutrals
  static const background = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0E1116);
  static const textSecondary = Color(0xFF5F6774);
  static const divider = Color(0xFFEEF0F3);
  static const border = Color(0xFFE3E6EB);

  // Accent (indigo)
  static const primary = Color(0xFF3B4FE0);
  static const primaryHover = Color(0xFF2B3BC0);
  static const primaryContainer = Color(0xFFEEF0FD);
  static const onGradientSecondary = Color(0xFFDCE0FF);

  // Semantic
  static const success = Color(0xFF0F7552);
  static const successContainer = Color(0xFFE7F6EF);
  static const successDot = Color(0xFF12B76A);
  static const warning = Color(0xFFA35F0B);
  static const warningContainer = Color(0xFFFDF0E1);

  // Elements (fixed mapping)
  static const pyro = Color(0xFFE8590C);
  static const hydro = Color(0xFF1C7ED6);
  static const electro = Color(0xFF7048E8);

  // Rarity chips
  static const rarity5Background = Color(0xFFFDF0E1);
  static const rarity5Text = Color(0xFFA35F0B);
  static const rarity4Background = Color(0xFFF0EAFB);
  static const rarity4Text = Color(0xFF6B46C1);

  // Icon-tile tint rotation (visual variety, not semantic)
  static const tileGreenBackground = Color(0xFFE8F5EE);
  static const tileGreenIcon = Color(0xFF2F855A);
  static const tileBlueBackground = Color(0xFFE7F0FB);
  static const tileBlueIcon = Color(0xFF2B6CB0);
  static const tilePurpleBackground = Color(0xFFF0EAFB);
  static const tilePurpleIcon = Color(0xFF6B46C1);
  static const tileAmberBackground = Color(0xFFFDF0E1);
  static const tileAmberIcon = Color(0xFFA86A12);
}
