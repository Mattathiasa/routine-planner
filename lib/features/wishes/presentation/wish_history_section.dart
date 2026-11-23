import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../planner/presentation/entity_avatar.dart';
import '../../planner/presentation/rarity_chip.dart';
import '../application/wish_view_models.dart';
import '../application/wishes_controller.dart';
import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';

/// The most recent wishes, newest first.
///
/// Capped at [wishHistoryPreviewLength]: a full six-month history runs to
/// hundreds of rows, and a scroll that long inside the screen's own scroll
/// view is worse than useless.
class WishHistorySection extends StatelessWidget {
  const WishHistorySection({super.key, required this.entries});

  final List<WishHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Recent wishes', style: textTheme.headlineLarge),
            const SizedBox(width: AppSpacing.sm),
            if (entries.length >= wishHistoryPreviewLength)
              Text(
                'last ${entries.length}',
                style: textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.colors.divider),
                _HistoryRow(entry: entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final WishHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          EntityAvatar(
            isWeapon: entry.kind == WishItemKind.weapon,
            name: entry.itemName,
            element: entry.element,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.itemName,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.rarity >= 4) ...[
                      const SizedBox(width: AppSpacing.xs),
                      RarityChip(rarity: entry.rarity),
                    ],
                  ],
                ),
                Text(
                  entry.pity == null
                      ? entry.banner.shortLabel
                      : '${entry.banner.shortLabel} · pity ${entry.pity}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
