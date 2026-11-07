import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/percent_ring_gauge.dart';
import '../application/planner_view_models.dart';
import 'entity_avatar.dart';
import 'rarity_chip.dart';

/// Assembles one target card. The level+ascension "done" chip-collapse
/// (one merged green chip when both are simultaneously done, instead of
/// two separate chips) and the talent uniform/non-uniform formatting are
/// decided here from [data]'s plain fields, not pre-baked into the view
/// model.
class TargetCard extends StatelessWidget {
  const TargetCard({super.key, required this.data});

  final TargetCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EntityAvatar(isWeapon: data.isWeapon, name: data.name, element: data.element),
              const SizedBox(width: AppSpacing.mlg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.name,
                            style: textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        RarityChip(rarity: data.rarity),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(data.subtitle, style: textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.mlg),
              PercentRingGauge(
                percent: data.percentInHand,
                semanticLabel: '${data.percentInHand}% of materials in hand',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.mlg),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: _buildChips()),
        ],
      ),
    );
  }

  List<Widget> _buildChips() {
    final levelAscensionDone =
        data.currentLevel == data.goalLevel && data.currentAscension == data.goalAscension;

    final chips = <Widget>[];
    if (levelAscensionDone) {
      chips.add(_PlannerChip(label: 'Lv ${data.goalLevel} · done', done: true));
    } else {
      chips.add(_PlannerChip(label: 'Lv ${data.currentLevel} → ${data.goalLevel}'));
      chips.add(_PlannerChip(label: 'A${data.currentAscension} → A${data.goalAscension}'));
    }

    final talents = data.talents;
    if (talents != null) {
      final first = talents.first;
      final uniform = talents.every((t) => t.current == first.current && t.goal == first.goal);
      final label = uniform
          ? 'Talents all ${first.current} → ${first.goal}'
          : 'Talents ${talents.map((t) => t.current).join('·')} → '
                '${talents.map((t) => t.goal).join('·')}';
      chips.add(_PlannerChip(label: label));
    }

    return chips;
  }
}

class _PlannerChip extends StatelessWidget {
  const _PlannerChip({required this.label, this.done = false});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AppColors.successContainer : AppColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: done ? AppColors.success : AppColors.textPrimary,
        ),
      ),
    );
  }
}
