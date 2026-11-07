import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/resin_controller.dart';
import '../data/resin_providers.dart';
import '../domain/resin_engine.dart';
import 'add_alert_dialog.dart';
import 'resin_formatting.dart';

typedef _AlertRowData = ({String id, int threshold, bool enabled, DateTime time});

/// "Today's forecast": a static "Now" row, then one row per live resin
/// alert that hasn't been reached yet (an open set, not fixed 160/200 —
/// "Add an alert" lets the player add any threshold). The mock's
/// decorative connecting rail line between rows is skipped — purely
/// visual, not information-bearing.
class ResinForecastSection extends ConsumerWidget {
  const ResinForecastSection({super.key});

  static const _engine = ResinEngine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resinAsync = ref.watch(resinControllerProvider);
    final alertsAsync = ref.watch(resinAlertsProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.smd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's forecast", style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            resinAsync.when(
              data: (state) {
                final v = _engine.v(state, now);
                final alerts = alertsAsync.value ?? const <ResinAlertEntry>[];
                final rows = <_AlertRowData>[];
                for (final alert in alerts) {
                  if (alert.threshold <= v) continue;
                  final time = _engine.timeToThreshold(state, alert.threshold);
                  if (time == null) continue;
                  rows.add((
                    id: alert.id,
                    threshold: alert.threshold,
                    enabled: alert.enabled,
                    time: time,
                  ));
                }
                rows.sort((a, b) => a.time.compareTo(b.time));

                return Column(
                  children: [
                    _NowRow(value: v),
                    for (final row in rows)
                      _AlertRow(row: row, now: now, cap: state.cap),
                  ],
                );
              },
              loading: () => const SizedBox(height: 52),
              error: (error, stack) => Text('Error: $error'),
            ),
            TextButton.icon(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => const AddAlertDialog()),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add an alert'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowRow extends StatelessWidget {
  const _NowRow({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primaryContainer, spreadRadius: 4)],
            ),
          ),
          const SizedBox(width: AppSpacing.mlg),
          SizedBox(
            width: 44,
            child: Text(
              'Now',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value resin', style: textTheme.titleMedium),
                Text(
                  '+1 every ${const ResinEngine().regenInterval.inMinutes} minutes',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.row, required this.now, required this.cap});

  final _AlertRowData row;
  final DateTime now;
  final int cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final label = row.threshold == cap ? 'Full at ${row.threshold}' : 'Reaches ${row.threshold}';

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.fromBorderSide(BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(width: AppSpacing.mlg),
          SizedBox(
            width: 44,
            child: Text(
              formatTime(row.time),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: textTheme.titleMedium),
                Text(
                  'Alert · in ${formatCountdown(row.time.difference(now))}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: row.enabled,
            onChanged: (value) async {
              await ref.read(settingsRepositoryProvider).setAlertEnabled(row.id, value);
              ref.invalidate(resinAlertsProvider);
            },
          ),
        ],
      ),
    );
  }
}
