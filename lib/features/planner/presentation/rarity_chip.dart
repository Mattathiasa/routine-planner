import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.rarity});

  final int rarity;

  @override
  Widget build(BuildContext context) {
    final isFiveStar = rarity >= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isFiveStar ? AppColors.rarity5Background : AppColors.rarity4Background,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(
        '$rarity★',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isFiveStar ? AppColors.rarity5Text : AppColors.rarity4Text,
        ),
      ),
    );
  }
}
