import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/notifications/domain/alert_delivery.dart';
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
    final deliveryAsync = ref.watch(alertDeliveryProvider);
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
            decoration: BoxDecoration(
              color: context.colors.surface,
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _AlertSwitch(
                  title: 'Resin reaches 160',
                  subtitle: '5 h 20 min before it caps',
                  value: has160,
                  onChanged: (value) =>
                      _setResinAlert(ref, threshold: 160, enabled: value),
                ),
                Divider(height: 1, color: context.colors.divider),
                _AlertSwitch(
                  title: 'Resin reaches 200',
                  subtitle: 'At cap, regeneration stops',
                  value: has200,
                  onChanged: (value) =>
                      _setResinAlert(ref, threshold: 200, enabled: value),
                ),
                Divider(height: 1, color: context.colors.divider),
                _AlertSwitch(
                  title: 'Transient Resin expiring',
                  subtitle: '24 h before a stack expires',
                  value:
                      settingsAsync.value?.transientExpiryAlertEnabled ?? false,
                  onChanged: (value) async {
                    final profileId = (await ref.read(
                      currentProfileProvider.future,
                    )).id;
                    await ref
                        .read(settingsRepositoryProvider)
                        .updateTransientExpiryAlertEnabled(profileId, value);
                    ref.invalidate(settingsSnapshotProvider);
                  },
                ),
                Divider(height: 1, color: context.colors.divider),
                _AlertSwitch(
                  title: 'Commissions unfinished',
                  subtitle: '2 h before this account\'s daily reset',
                  value:
                      settingsAsync.value?.commissionReminderEnabled ?? false,
                  onChanged: (value) async {
                    final profileId = (await ref.read(
                      currentProfileProvider.future,
                    )).id;
                    await ref
                        .read(settingsRepositoryProvider)
                        .updateCommissionReminderEnabled(profileId, value);
                    ref.invalidate(settingsSnapshotProvider);
                  },
                ),
                Divider(height: 1, color: context.colors.divider),
                _AlertDeliveryBanner(
                  delivery: deliveryAsync.value ?? AlertDelivery.onTime,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setResinAlert(
    WidgetRef ref, {
    required int threshold,
    required bool enabled,
  }) async {
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
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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

/// Read-only status, no action button — the approved design
/// (`design/v3/SettingsV3.dc.html`) has no affordance here, and on iOS the
/// permission prompt is a system modal raised at initialize time anyway.
///
/// Says "Settings" rather than naming an OS: the blocked state is reachable
/// on both platforms and the destination is the OS settings app on each.
class _AlertDeliveryBanner extends StatelessWidget {
  const _AlertDeliveryBanner({required this.delivery});

  final AlertDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final onTime = delivery == AlertDelivery.onTime;
    final dotColor = onTime
        ? context.colors.successDot
        : context.colors.warning;
    final strongColor = onTime
        ? context.colors.success
        : context.colors.warning;
    final background = onTime
        ? context.colors.successContainer
        : context.colors.warningContainer;
    final (strongText, mutedText) = switch (delivery) {
      AlertDelivery.onTime => (
        'Exact alarms allowed. ',
        'Alerts fire on time.',
      ),
      AlertDelivery.approximate => (
        'Exact alarms not available. ',
        'Alerts may arrive late (approximate).',
      ),
      AlertDelivery.blocked => (
        'Notifications are off. ',
        'Turn them on in Settings to get alerts.',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: strongText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: strongColor,
                    ),
                  ),
                  TextSpan(
                    text: mutedText,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
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
