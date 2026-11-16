import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

/// A character's circular avatar (initial letter on an element-tinted
/// background, plus a small element badge) or a weapon's square tile
/// (generic placeholder icon — no game art/icons are bundled here).
class EntityAvatar extends StatelessWidget {
  const EntityAvatar({
    super.key,
    required this.isWeapon,
    required this.name,
    this.element,
    this.size = 52,
  });

  final bool isWeapon;
  final String name;
  final String? element;
  final double size;

  static ({Color background, Color text, Color badge, IconData icon})?
  _elementStyle(AppColorScheme colors, String? element) {
    return switch (element) {
      'Pyro' => (
        background: colors.pyroAvatarBackground,
        text: colors.pyroAvatarText,
        badge: colors.pyro,
        icon: Icons.local_fire_department,
      ),
      'Hydro' => (
        background: colors.hydroAvatarBackground,
        text: colors.hydroAvatarText,
        badge: colors.hydro,
        icon: Icons.water_drop,
      ),
      'Electro' => (
        background: colors.electroAvatarBackground,
        text: colors.electroAvatarText,
        badge: colors.electro,
        icon: Icons.bolt,
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isWeapon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.weaponTileBackground,
          borderRadius: AppRadius.tileRadius,
        ),
        child: Icon(
          Icons.auto_fix_high_outlined,
          color: context.colors.textPrimary,
          size: 26,
        ),
      );
    }

    final style = _elementStyle(context.colors, element);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: style?.background ?? context.colors.background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: style?.text ?? context.colors.textPrimary,
              ),
            ),
          ),
          if (style != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: style.badge,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
                child: Icon(
                  style.icon,
                  color: context.colors.surface,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
