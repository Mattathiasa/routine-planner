import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../resin/application/resin_controller.dart';
import '../../resin/domain/resin_engine.dart';

String _formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  return '${clamped.inMinutes}:${(clamped.inSeconds % 60).toString().padLeft(2, '0')}';
}

String _formatTime(DateTime utc) {
  return '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}

/// Tapping opens the Resin tab — the same [ResinController] state the Resin
/// screen itself will read, so the two never disagree.
class ResinHeroCard extends ConsumerWidget {
  const ResinHeroCard({super.key});

  static const _engine = ResinEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resinAsync = ref.watch(resinControllerProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final textTheme = Theme.of(context).textTheme;

    return resinAsync.when(
      data: (state) {
        final v = _engine.v(state, now);
        final nextTick = state.n;
        final fullAt = _engine.timeToThreshold(state, state.cap);

        return InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => context.go('/resin'),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              gradient: const LinearGradient(
                begin: Alignment(-0.6, -1),
                end: Alignment(0.6, 1),
                colors: [Color(0xFF3B4FE0), Color(0xFF4F5FEA), Color(0xFF6A77F2)],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x593B4FE0), offset: Offset(0, 12), blurRadius: 30),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original Resin',
                  style: textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$v', style: AppDisplayNumbers.heroNumber()),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        '/ ${state.cap}',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.onGradientSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (nextTick != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '+1 in ${_formatCountdown(nextTick.difference(now))}',
                    style: textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (fullAt != null)
                  Text(
                    'Full at ${_formatTime(fullAt)}',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.onGradientSecondary),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatColumn(label: 'Condensed', value: '${state.condensed}'),
                    _StatColumn(label: 'Fragile', value: '${state.fragile}'),
                    _StatColumn(label: 'Transient', value: '${state.transient.length}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const AppCard(
        child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => AppCard(child: Text('Error: $error')),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: textTheme.titleSmall?.copyWith(color: Colors.white)),
        Text(label, style: textTheme.labelSmall?.copyWith(color: AppColors.onGradientSecondary)),
      ],
    );
  }
}
