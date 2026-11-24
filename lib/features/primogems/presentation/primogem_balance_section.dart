import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_status_views.dart';
import '../../../core/widgets/rolling_number.dart';
import '../application/primogem_view_models.dart';
import '../application/primogems_controller.dart';
import 'add_adjustment_dialog.dart';
import 'set_balance_dialog.dart';

/// The Wishes screen's one gradient hero card: what's in the bank, and how
/// many wishes that is.
class PrimogemBalanceSection extends ConsumerWidget {
  const PrimogemBalanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primogems = ref.watch(primogemsControllerProvider);

    return primogems.when(
      loading: () => const AppLoadingView(height: 160),
      error: (error, _) => AppErrorView(error: error),
      data: (data) => _HeroCard(data: data),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.data});

  final PrimogemViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        // The same hero gradient as Today's resin card — one per screen.
        gradient: const LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFF3B4FE0), Color(0xFF4F5FEA), Color(0xFF6A77F2)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x593B4FE0),
            offset: Offset(0, 12),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primogems',
            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!data.hasAnchor)
            _NoAnchor(data: data)
          else
            _Balance(data: data),
        ],
      ),
    );
  }
}

class _NoAnchor extends ConsumerWidget {
  const _NoAnchor({required this.data});

  final PrimogemViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Not set yet',
          style: AppDisplayNumbers.heroNumber().copyWith(fontSize: 32),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          "Nothing reports your balance, so tell the app once and it'll keep "
          'up from there.',
          style: textTheme.bodyLarge?.copyWith(
            color: context.colors.onGradientSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => SetBalanceDialog(data: data),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: context.colors.primary,
          ),
          child: const Text('Set balance'),
        ),
      ],
    );
  }
}

class _Balance extends ConsumerWidget {
  const _Balance({required this.data});

  final PrimogemViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The hero number gets the row to itself: at 412dp a six-figure
        // balance plus a trailing label overflows, and fates read better
        // next to the wish count anyway.
        RollingNumber(data.balance, style: AppDisplayNumbers.heroNumber()),
        Text(
          _wishesLine(data),
          style: textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _incomeLine(data),
          style: textTheme.bodyLarge?.copyWith(
            color: context.colors.onGradientSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _GhostButton(
              label: 'Adjust',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AddAdjustmentDialog(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _GhostButton(
              label: 'Re-anchor',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SetBalanceDialog(data: data),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// How many wishes that buys, counting any Fates already held.
String _wishesLine(PrimogemViewData data) {
  final wishes = data.wishesAffordable == 1
      ? '1 wish'
      : '${data.wishesAffordable} wishes';
  if (data.fates == 0) return wishes;
  return '$wishes · including ${data.fates} fates';
}

/// Says where the number comes from, so a stale balance is never presented as
/// a live one.
String _incomeLine(PrimogemViewData data) {
  final spent = data.wishesSinceAnchor > 0
      ? ' · ${data.spentOnWishes} spent on wishes'
      : '';
  return switch (data.incomeState) {
    PrimogemIncomeState.live =>
      '${data.monthIncome ?? 0} earned this month$spent',
    PrimogemIncomeState.diaryUnavailable =>
      "Income isn't syncing — adjust by hand$spent",
    PrimogemIncomeState.notConnected => 'Tracked by hand$spent',
  };
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white24,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      child: Text(label),
    );
  }
}
