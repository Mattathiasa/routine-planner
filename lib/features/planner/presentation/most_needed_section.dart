import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../application/planner_view_models.dart';

/// The pooled, domain-farmable-only "Most needed" list. Tile tint + icon
/// rotate through a fixed 4-color set purely for visual variety (not a
/// per-material-category mapping) — same convention as `AppColors`'s
/// existing tile-tint tokens.
class MostNeededSection extends StatelessWidget {
  const MostNeededSection({super.key, required this.rows});

  final List<MostNeededRowData> rows;

  static List<({Color background, Color icon, IconData glyph})> _tileTints(
    AppColorScheme colors,
  ) {
    return [
      (
        background: colors.tileGreenBackground,
        icon: colors.tileGreenIcon,
        glyph: Icons.auto_stories_outlined,
      ),
      (
        background: colors.tilePurpleBackground,
        icon: colors.tilePurpleIcon,
        glyph: Icons.circle_outlined,
      ),
      (
        background: colors.tileBlueBackground,
        icon: colors.tileBlueIcon,
        glyph: Icons.diamond_outlined,
      ),
      (
        background: colors.tileAmberBackground,
        icon: colors.tileAmberIcon,
        glyph: Icons.auto_awesome_outlined,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Most needed', style: textTheme.headlineLarge),
            Text('Missing', style: textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (rows.isEmpty)
          AppCard(child: Text('Nothing missing — fully stocked.', style: textTheme.bodyLarge))
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardRadius,
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Builder(builder: (context) {
                final tints = _tileTints(context.colors);
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: context.colors.divider),
                      _MostNeededRow(data: rows[i], tint: tints[i % tints.length]),
                    ],
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _MostNeededRow extends StatelessWidget {
  const _MostNeededRow({required this.data, required this.tint});

  final MostNeededRowData data;
  final ({Color background, Color icon, IconData glyph}) tint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tint.background, borderRadius: AppRadius.tileRadius),
            child: Icon(tint.glyph, color: tint.icon, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.label, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: '${data.have} of ${data.need} · ',
                    style: textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: data.availabilityLabel,
                        style: TextStyle(
                          color: data.highlightAvailability
                              ? context.colors.success
                              : context.colors.textSecondary,
                          fontWeight: data.highlightAvailability
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text('${data.missing}', style: textTheme.headlineLarge),
        ],
      ),
    );
  }
}
