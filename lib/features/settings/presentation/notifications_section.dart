import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../resin/data/resin_providers.dart';
import '../data/settings_providers.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(resinAlertsProvider);
    final settingsAsync = ref.watch(settingsSnapshotProvider);
    final exactAllowedAsync = ref.watch(exactAlarmsAllowedProvider);
    final textTheme = Theme.of(context).textTheme;

    final alerts = alertsAsync.value ?? const [];
    final has160 = alerts.any((a) => a.threshold == 160 && a.enabled);
    final has200 = alerts.any((a) => a.threshold == 200 && a.enabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifications', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.card),
            child: Column(
              children: [
                _AlertSwitch(
                  title: 'Resin reaches 160',
                  subtitle: '5 h 20 min before it caps',
                  value: has160,
                  onChanged: (value) => _setResinAlert(ref, threshold: 160, enabled: value),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _AlertSwitch(
                  title: 'Resin reaches 200',
                  subtitle: 'At cap, regeneration stops',
                  value: has200,
                  onChanged: (value) => _setResinAlert(ref, threshold: 200, enabled: value),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _AlertSwitch(
                  title: 'Transient Resin expiring',
                  subtitle: '24 h before a stack expires',
                  value: settingsAsync.value?.transientExpiryAlertEnabled ?? false,
                  onChanged: (value) async {
                    final profileId = (await ref.read(currentProfileProvider.future)).id;
                    await ref
                        .read(settingsRepositoryProvider)
                        .updateTransientExpiryAlertEnabled(profileId, value);
                    ref.invalidate(settingsSnapshotProvider);
                  },
                ),
                const Divider(height: 1, color: AppColors.divider),
                _ExactAlarmsBanner(allowed: exactAllowedAsync.value ?? false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setResinAlert(WidgetRef ref, {required int threshold, required bool enabled}) async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final alerts = await ref.read(resinAlertsProvider.future);

    ResinAlertEntry? existing;
    for (final alert in alerts) {
      if (alert.threshold == threshold) {
        existing = alert;
        break;
      }
    }

    if (existing == null) {
      if (enabled) await settingsRepo.addAlertThreshold(profileId, threshold);
    } else {
      await settingsRepo.setAlertEnabled(existing.id, enabled);
    }
    ref.invalidate(resinAlertsProvider);
  }
}

class _AlertSwitch extends StatelessWidget {
  const _AlertSwitch({
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
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}

class _ExactAlarmsBanner extends StatelessWidget {
  const _ExactAlarmsBanner({required this.allowed});

  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final dotColor = allowed ? AppColors.successDot : AppColors.warning;
    final strongColor = allowed ? AppColors.success : AppColors.warning;
    final background = allowed ? AppColors.successContainer : AppColors.warningContainer;
    final strongText = allowed ? 'Exact alarms allowed. ' : 'Exact alarms not available. ';
    final mutedText = allowed
        ? 'Alerts fire on time.'
        : 'Alerts may arrive late (approximate).';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: strongText,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: strongColor),
                  ),
                  TextSpan(
                    text: mutedText,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
