import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/percent_ring_gauge.dart';
import '../../../core/widgets/rolling_number.dart';
import '../application/wish_view_models.dart';
import 'manual_pity_dialog.dart';

/// A card per banner: how deep the pity is, how far to the guarantee, and
/// whether the next 5★ is already locked in.
class BannerPitySection extends ConsumerWidget {
  const BannerPitySection({super.key, required this.banners});

  final List<BannerPityCard> banners;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    // Banners nobody has touched sit below the ones in play, so the card the
    // player cares about is never buried under four empty ones.
    final tracked = [
      for (final card in banners)
        if (card.source != PitySource.unknown) card,
    ];
    final untouched = [
      for (final card in banners)
        if (card.source == PitySource.unknown) card,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pity', style: textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.md),
        for (final card in [...tracked, ...untouched]) ...[
          _BannerCard(
            card: card,
            onSetPity: () => showDialog<void>(
              context: context,
              builder: (_) => ManualPityDialog(card: card),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.card, required this.onSetPity});

  final BannerPityCard card;
  final VoidCallback onSetPity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final untouched = card.source == PitySource.unknown;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.label, style: textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleFor(card),
                      style: textTheme.bodyLarge?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (untouched)
                TextButton(
                  onPressed: onSetPity,
                  child: const Text('Set pity'),
                )
              else
                PercentRingGauge(
                  percent: card.percentToHardPity,
                  semanticLabel:
                      '${card.label}: pity ${card.pity} of ${card.hardPity}',
                ),
            ],
          ),
          if (!untouched) ...[
            const SizedBox(height: AppSpacing.md),
            _PityLine(card: card),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (card.guaranteedNextFive) const _GuaranteedPill(),
                if (card.reachedSoftPity) const _SoftPityPill(),
                if (card.source == PitySource.manual)
                  _ManualPill(onEdit: onSetPity),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _subtitleFor(BannerPityCard card) {
    if (card.source == PitySource.unknown) {
      return 'Not tracked yet';
    }
    if (card.source == PitySource.manual) {
      return 'Guarantee at ${card.hardPity}';
    }
    final last = card.lastFiveName;
    if (last == null) {
      return '${card.totalPulls} wishes · no 5★ yet';
    }
    return '${card.totalPulls} wishes · last 5★ $last';
  }
}

class _PityLine extends StatelessWidget {
  const _PityLine({required this.card});

  final BannerPityCard card;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RollingNumber(
          card.pity,
          style: textTheme.displaySmall?.copyWith(
            color: card.reachedSoftPity
                ? context.colors.primary
                : context.colors.textPrimary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 2, left: 2),
          child: Text(
            '/ ${card.hardPity}',
            style: textTheme.titleMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        Text(
          card.pullsToHardPity == 0
              ? 'Guaranteed next wish'
              : '${card.pullsToHardPity} to guarantee',
          style: textTheme.labelMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GuaranteedPill extends StatelessWidget {
  const _GuaranteedPill();

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: 'Next 5★ guaranteed',
      background: context.colors.primaryContainer,
      foreground: context.colors.primaryHover,
    );
  }
}

class _SoftPityPill extends StatelessWidget {
  const _SoftPityPill();

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: 'Soft pity',
      background: context.colors.successContainer,
      foreground: context.colors.success,
    );
  }
}

class _ManualPill extends StatelessWidget {
  const _ManualPill({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: AppRadius.pillRadius,
      child: _Pill(
        label: 'Tracked manually · edit',
        background: context.colors.warningContainer,
        foreground: context.colors.warning,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: foreground),
      ),
    );
  }
}
