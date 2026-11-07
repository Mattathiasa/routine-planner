import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock/game_server.dart';
import '../../../core/providers/clock_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circle_icon_button.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  return '${clamped.inHours}h ${clamped.inMinutes.remainder(60)}m';
}

class TodayHeader extends ConsumerWidget {
  const TodayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverClockAsync = ref.watch(serverClockProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final textTheme = Theme.of(context).textTheme;

    return serverClockAsync.when(
      data: (serverClock) {
        final serverDate = serverClock.serverDateFor(now);
        final dayStart = serverClock.dayStartUtc(now);
        final elapsed = now.difference(dayStart);
        final progress = (elapsed.inSeconds / const Duration(hours: 24).inSeconds).clamp(
          0.0,
          1.0,
        );
        final remaining = dayStart.add(const Duration(hours: 24)).difference(now);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${serverDate.day} ${_monthNames[serverDate.month - 1]} · '
                    '${serverClock.server.label} server',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(_weekdayNames[serverDate.weekday - 1], style: textTheme.displayLarge),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Reset in ${_formatCountdown(remaining)}',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            CircleIconButton(
              icon: Icons.settings_outlined,
              semanticLabel: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
