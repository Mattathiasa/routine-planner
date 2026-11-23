import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../planner/presentation/entity_avatar.dart';
import '../application/wish_view_models.dart';
import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';

/// What the history adds up to, and every 5★ with the pity it came at.
class WishStatsSection extends StatelessWidget {
  const WishStatsSection({super.key, required this.stats});

  final WishStatsData stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your luck', style: textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Stat(label: 'Wishes', value: '${stats.totalPulls}'),
                  _Stat(label: '5★', value: '${stats.fiveStarCount}'),
                  _Stat(label: '4★', value: '${stats.fourStarCount}'),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  _Stat(
                    label: 'Average 5★ pity',
                    value: stats.averageFivePity == null
                        ? '—'
                        : stats.averageFivePity!.toStringAsFixed(1),
                  ),
                  _Stat(
                    label: 'Primogems spent',
                    value: _grouped(stats.primogemsSpent),
                  ),
                ],
              ),
              if (stats.averageFivePity == null && stats.fiveStarCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    // Being explicit beats quoting a number that is wrong:
                    // the earliest 5★'s pity is cut off by the import window.
                    'An average needs a second 5★ — the first one in an '
                    "import has no known starting point.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (stats.fiveStars.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Every 5★', style: textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < stats.fiveStars.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.divider),
                  _FiveStarRow(entry: stats.fiveStars[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: textTheme.headlineMedium),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiveStarRow extends StatelessWidget {
  const _FiveStarRow({required this.entry});

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
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.itemName, style: textTheme.titleMedium),
                Text(
                  entry.banner.shortLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (entry.pity != null)
            Text(
              'pity ${entry.pity}',
              style: textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 12480 reads as 12,480. Dart has no built-in grouping without intl, and
/// pulling intl in for one number isn't worth it.
String _grouped(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
