import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../wishes/domain/pity_calculator.dart';
import '../application/primogem_view_models.dart';
import '../application/primogems_controller.dart';
import '../domain/primogem_ledger.dart';
import 'primogem_date_format.dart';

/// When a guaranteed 5★ becomes affordable, and what the projection assumes.
///
/// The assumptions are editable right here rather than buried in Settings:
/// the forecast is only as good as them, so the place to question the number
/// is the place to fix it.
class PrimogemForecastSection extends ConsumerWidget {
  const PrimogemForecastSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primogems = ref.watch(primogemsControllerProvider);

    return primogems.maybeWhen(
      data: (data) => data.hasAnchor ? _Forecast(data: data) : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Forecast extends ConsumerWidget {
  const _Forecast({required this.data});

  final PrimogemViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).nowUtc();

    // A guaranteed 5★ is the goal worth naming: it's the one number that
    // doesn't depend on luck.
    const goal = hardPityFiveStarCharacter;
    final shortfall = shortfallFor(
      balance: data.balance,
      fates: data.fates,
      wishes: goal,
    );
    final date = dateForWishes(
      balance: data.balance,
      fates: data.fates,
      wishes: goal,
      dailyIncome: data.dailyIncome,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The section owns its leading gap because it hides itself entirely
        // when there's no anchor; a gap in the screen's list would leave a
        // double space behind when that happens.
        const SizedBox(height: AppSpacing.xl),
        Text('Saving up', style: textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shortfall == 0
                    ? 'You can afford a guaranteed 5★ now'
                    : date == null
                    ? 'A guaranteed 5★ needs $shortfall more primogems'
                    : 'A guaranteed 5★ by ${formatForecastDate(date, relativeTo: now)}',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                shortfall == 0
                    ? '$goal wishes, whatever the 50/50 does'
                    : date == null
                    ? 'Turn on an income source below to see a date'
                    : '$shortfall primogems to go, at ${data.dailyIncome} a day',
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Text(
                'Counting $commissionPrimogems a day from commissions. '
                'Add what you actually have:',
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              _IncomeSwitch(
                title: 'Welkin Moon',
                subtitle: '+$welkinPrimogems a day',
                value: data.welkinActive,
                onChanged: (value) => ref
                    .read(primogemsControllerProvider.notifier)
                    .setWelkinActive(value),
              ),
              _IncomeSwitch(
                title: 'Battle pass',
                subtitle:
                    '+${battlePassPrimogems ~/ battlePassCycleDays} a day '
                    '($battlePassPrimogems per cycle)',
                value: data.battlePassActive,
                onChanged: (value) => ref
                    .read(primogemsControllerProvider.notifier)
                    .setBattlePassActive(value),
              ),
              Text(
                // Said plainly, because a forecast that looks precise is
                // worse than one that admits what it leaves out.
                'Events, Spiral Abyss and quests are not counted, so the real '
                'date usually arrives sooner.',
                style: textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain Row rather than a SwitchListTile: a ListTile inside AppCard's
/// DecoratedBox can't paint its own background or ink, which Flutter asserts
/// on in debug. The settings screen's switches are built the same way.
class _IncomeSwitch extends StatelessWidget {
  const _IncomeSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
