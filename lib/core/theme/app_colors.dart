import 'package:flutter/material.dart';

/// Exact colors from the approved v3 design (`design/v3/*.dc.html`) — the
/// light palette, and the source tokens the dark palette in
/// [AppColorsDark] is derived from. Widgets read colors through
/// `context.colors` (an [AppColorScheme] theme extension) so the same
/// token name resolves per-brightness; these raw constants exist only to
/// define the two palettes.
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

  // Element-avatar tints (distinct from the solid badge colors above —
  // these are the soft circle background + text pair behind an entity's
  // initial letter).
  static const pyroAvatarBackground = Color(0xFFFDEBE3);
  static const pyroAvatarText = Color(0xFFB33F0A);
  static const hydroAvatarBackground = Color(0xFFE3F0FC);
  static const hydroAvatarText = Color(0xFF17609F);
  static const electroAvatarBackground = Color(0xFFEFE9FD);
  static const electroAvatarText = Color(0xFF5B34C9);

  // Weapon-tile background (Planner's square weapon avatar).
  static const weaponTileBackground = Color(0xFFF1F3F6);

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

/// The dark palette, derived token-for-token from [AppColors]: same hues,
/// inverted lightness roles — deep neutral grounds from the light theme's
/// ink color, containers darkened to ~15% lightness of their hue, and
/// foreground accents lightened until they hold AA contrast on
/// [surface]. No token exists here that doesn't exist in [AppColors].
abstract final class AppColorsDark {
  // Neutrals — ground taken from the light theme's ink (#0E1116).
  static const background = Color(0xFF0E1116);
  static const surface = Color(0xFF171B22);
  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFF9AA3B1);
  static const divider = Color(0xFF232833);
  static const border = Color(0xFF2C3340);

  // Accent (same indigo hue, lightened for contrast on dark surfaces).
  static const primary = Color(0xFF8A97F2);
  static const primaryHover = Color(0xFFA5B0F6);
  static const primaryContainer = Color(0xFF222A58);
  static const onGradientSecondary = AppColors.onGradientSecondary;

  // Semantic
  static const success = Color(0xFF3FCE96);
  static const successContainer = Color(0xFF11352A);
  static const successDot = AppColors.successDot;
  static const warning = Color(0xFFE2A757);
  static const warningContainer = Color(0xFF3A2B12);

  // Elements (lightened a step so the badges read on dark)
  static const pyro = Color(0xFFF07438);
  static const hydro = Color(0xFF4D9DE8);
  static const electro = Color(0xFF9775F0);

  // Element-avatar tints
  static const pyroAvatarBackground = Color(0xFF3B2318);
  static const pyroAvatarText = Color(0xFFF09A74);
  static const hydroAvatarBackground = Color(0xFF16293D);
  static const hydroAvatarText = Color(0xFF82BAE8);
  static const electroAvatarBackground = Color(0xFF261E3F);
  static const electroAvatarText = Color(0xFFB6A0F2);

  // Weapon-tile background
  static const weaponTileBackground = Color(0xFF222733);

  // Rarity chips
  static const rarity5Background = Color(0xFF3A2B12);
  static const rarity5Text = Color(0xFFE2B165);
  static const rarity4Background = Color(0xFF2A2144);
  static const rarity4Text = Color(0xFFBCA2EC);

  // Icon-tile tint rotation
  static const tileGreenBackground = Color(0xFF14311F);
  static const tileGreenIcon = Color(0xFF66C793);
  static const tileBlueBackground = Color(0xFF152639);
  static const tileBlueIcon = Color(0xFF75AAE2);
  static const tilePurpleBackground = Color(0xFF2A2144);
  static const tilePurpleIcon = Color(0xFFBCA2EC);
  static const tileAmberBackground = Color(0xFF3A2B12);
  static const tileAmberIcon = Color(0xFFDBA24E);
}

/// Theme-resolved token set: the one place widgets read colors from
/// (`context.colors.x`), so every token flips with brightness. Field set
/// mirrors [AppColors]/[AppColorsDark] exactly.
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.border,
    required this.primary,
    required this.primaryHover,
    required this.primaryContainer,
    required this.onGradientSecondary,
    required this.success,
    required this.successContainer,
    required this.successDot,
    required this.warning,
    required this.warningContainer,
    required this.pyro,
    required this.hydro,
    required this.electro,
    required this.pyroAvatarBackground,
    required this.pyroAvatarText,
    required this.hydroAvatarBackground,
    required this.hydroAvatarText,
    required this.electroAvatarBackground,
    required this.electroAvatarText,
    required this.weaponTileBackground,
    required this.rarity5Background,
    required this.rarity5Text,
    required this.rarity4Background,
    required this.rarity4Text,
    required this.tileGreenBackground,
    required this.tileGreenIcon,
    required this.tileBlueBackground,
    required this.tileBlueIcon,
    required this.tilePurpleBackground,
    required this.tilePurpleIcon,
    required this.tileAmberBackground,
    required this.tileAmberIcon,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color border;
  final Color primary;
  final Color primaryHover;
  final Color primaryContainer;
  final Color onGradientSecondary;
  final Color success;
  final Color successContainer;
  final Color successDot;
  final Color warning;
  final Color warningContainer;
  final Color pyro;
  final Color hydro;
  final Color electro;
  final Color pyroAvatarBackground;
  final Color pyroAvatarText;
  final Color hydroAvatarBackground;
  final Color hydroAvatarText;
  final Color electroAvatarBackground;
  final Color electroAvatarText;
  final Color weaponTileBackground;
  final Color rarity5Background;
  final Color rarity5Text;
  final Color rarity4Background;
  final Color rarity4Text;
  final Color tileGreenBackground;
  final Color tileGreenIcon;
  final Color tileBlueBackground;
  final Color tileBlueIcon;
  final Color tilePurpleBackground;
  final Color tilePurpleIcon;
  final Color tileAmberBackground;
  final Color tileAmberIcon;

  static const light = AppColorScheme(
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    divider: AppColors.divider,
    border: AppColors.border,
    primary: AppColors.primary,
    primaryHover: AppColors.primaryHover,
    primaryContainer: AppColors.primaryContainer,
    onGradientSecondary: AppColors.onGradientSecondary,
    success: AppColors.success,
    successContainer: AppColors.successContainer,
    successDot: AppColors.successDot,
    warning: AppColors.warning,
    warningContainer: AppColors.warningContainer,
    pyro: AppColors.pyro,
    hydro: AppColors.hydro,
    electro: AppColors.electro,
    pyroAvatarBackground: AppColors.pyroAvatarBackground,
    pyroAvatarText: AppColors.pyroAvatarText,
    hydroAvatarBackground: AppColors.hydroAvatarBackground,
    hydroAvatarText: AppColors.hydroAvatarText,
    electroAvatarBackground: AppColors.electroAvatarBackground,
    electroAvatarText: AppColors.electroAvatarText,
    weaponTileBackground: AppColors.weaponTileBackground,
    rarity5Background: AppColors.rarity5Background,
    rarity5Text: AppColors.rarity5Text,
    rarity4Background: AppColors.rarity4Background,
    rarity4Text: AppColors.rarity4Text,
    tileGreenBackground: AppColors.tileGreenBackground,
    tileGreenIcon: AppColors.tileGreenIcon,
    tileBlueBackground: AppColors.tileBlueBackground,
    tileBlueIcon: AppColors.tileBlueIcon,
    tilePurpleBackground: AppColors.tilePurpleBackground,
    tilePurpleIcon: AppColors.tilePurpleIcon,
    tileAmberBackground: AppColors.tileAmberBackground,
    tileAmberIcon: AppColors.tileAmberIcon,
  );

  static const dark = AppColorScheme(
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    divider: AppColorsDark.divider,
    border: AppColorsDark.border,
    primary: AppColorsDark.primary,
    primaryHover: AppColorsDark.primaryHover,
    primaryContainer: AppColorsDark.primaryContainer,
    onGradientSecondary: AppColorsDark.onGradientSecondary,
    success: AppColorsDark.success,
    successContainer: AppColorsDark.successContainer,
    successDot: AppColorsDark.successDot,
    warning: AppColorsDark.warning,
    warningContainer: AppColorsDark.warningContainer,
    pyro: AppColorsDark.pyro,
    hydro: AppColorsDark.hydro,
    electro: AppColorsDark.electro,
    pyroAvatarBackground: AppColorsDark.pyroAvatarBackground,
    pyroAvatarText: AppColorsDark.pyroAvatarText,
    hydroAvatarBackground: AppColorsDark.hydroAvatarBackground,
    hydroAvatarText: AppColorsDark.hydroAvatarText,
    electroAvatarBackground: AppColorsDark.electroAvatarBackground,
    electroAvatarText: AppColorsDark.electroAvatarText,
    weaponTileBackground: AppColorsDark.weaponTileBackground,
    rarity5Background: AppColorsDark.rarity5Background,
    rarity5Text: AppColorsDark.rarity5Text,
    rarity4Background: AppColorsDark.rarity4Background,
    rarity4Text: AppColorsDark.rarity4Text,
    tileGreenBackground: AppColorsDark.tileGreenBackground,
    tileGreenIcon: AppColorsDark.tileGreenIcon,
    tileBlueBackground: AppColorsDark.tileBlueBackground,
    tileBlueIcon: AppColorsDark.tileBlueIcon,
    tilePurpleBackground: AppColorsDark.tilePurpleBackground,
    tilePurpleIcon: AppColorsDark.tilePurpleIcon,
    tileAmberBackground: AppColorsDark.tileAmberBackground,
    tileAmberIcon: AppColorsDark.tileAmberIcon,
  );

  @override
  AppColorScheme copyWith() => this;

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorScheme(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      divider: mix(divider, other.divider),
      border: mix(border, other.border),
      primary: mix(primary, other.primary),
      primaryHover: mix(primaryHover, other.primaryHover),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onGradientSecondary: mix(onGradientSecondary, other.onGradientSecondary),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      successDot: mix(successDot, other.successDot),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      pyro: mix(pyro, other.pyro),
      hydro: mix(hydro, other.hydro),
      electro: mix(electro, other.electro),
      pyroAvatarBackground: mix(pyroAvatarBackground, other.pyroAvatarBackground),
      pyroAvatarText: mix(pyroAvatarText, other.pyroAvatarText),
      hydroAvatarBackground: mix(hydroAvatarBackground, other.hydroAvatarBackground),
      hydroAvatarText: mix(hydroAvatarText, other.hydroAvatarText),
      electroAvatarBackground: mix(electroAvatarBackground, other.electroAvatarBackground),
      electroAvatarText: mix(electroAvatarText, other.electroAvatarText),
      weaponTileBackground: mix(weaponTileBackground, other.weaponTileBackground),
      rarity5Background: mix(rarity5Background, other.rarity5Background),
      rarity5Text: mix(rarity5Text, other.rarity5Text),
      rarity4Background: mix(rarity4Background, other.rarity4Background),
      rarity4Text: mix(rarity4Text, other.rarity4Text),
      tileGreenBackground: mix(tileGreenBackground, other.tileGreenBackground),
      tileGreenIcon: mix(tileGreenIcon, other.tileGreenIcon),
      tileBlueBackground: mix(tileBlueBackground, other.tileBlueBackground),
      tileBlueIcon: mix(tileBlueIcon, other.tileBlueIcon),
      tilePurpleBackground: mix(tilePurpleBackground, other.tilePurpleBackground),
      tilePurpleIcon: mix(tilePurpleIcon, other.tilePurpleIcon),
      tileAmberBackground: mix(tileAmberBackground, other.tileAmberBackground),
      tileAmberIcon: mix(tileAmberIcon, other.tileAmberIcon),
    );
  }
}

/// `context.colors.<token>` — the only way widgets should read colors.
extension AppColorSchemeContext on BuildContext {
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>()!;
}
