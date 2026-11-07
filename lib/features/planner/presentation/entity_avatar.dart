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

  static const _elementStyles = {
    'Pyro': (
      background: AppColors.pyroAvatarBackground,
      text: AppColors.pyroAvatarText,
      badge: AppColors.pyro,
      icon: Icons.local_fire_department,
    ),
    'Hydro': (
      background: AppColors.hydroAvatarBackground,
      text: AppColors.hydroAvatarText,
      badge: AppColors.hydro,
      icon: Icons.water_drop,
    ),
    'Electro': (
      background: AppColors.electroAvatarBackground,
      text: AppColors.electroAvatarText,
      badge: AppColors.electro,
      icon: Icons.bolt,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (isWeapon) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.weaponTileBackground,
          borderRadius: AppRadius.tileRadius,
        ),
        child: const Icon(Icons.auto_fix_high_outlined, color: AppColors.textPrimary, size: 26),
      );
    }

    final style = _elementStyles[element];
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
              color: style?.background ?? AppColors.background,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: style?.text ?? AppColors.textPrimary,
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
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Icon(style.icon, color: AppColors.surface, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}
