import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/resin/application/resin_controller.dart';
import '../../features/resin/data/resin_providers.dart';
import '../../features/resin/domain/resin_engine.dart';
import '../../features/settings/data/settings_providers.dart';
import '../notifications/data/notification_scheduler.dart';
import '../notifications/domain/notification_plan.dart';
import 'clock_providers.dart';
import 'current_profile_provider.dart';

part 'notification_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationScheduler notificationScheduler(Ref ref) {
  return FlutterLocalNotificationsScheduler();
}

@riverpod
Future<bool> exactAlarmsAllowed(Ref ref) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  await scheduler.initialize();
  return scheduler.canScheduleExactAlarms();
}

/// Reactive, idempotent reconcile: watching resin state, alerts, and
/// settings means this automatically re-runs after every resin mutation or
/// alert/settings change — no manual call-sites needed anywhere else in
/// the app. `AppShell` watches this once, which also covers "app start"
/// since it's always mounted past initial routing. "Reboot" is handled
/// entirely natively by the plugin's own boot receiver once the manifest
/// is wired; there's no live local time-zone dependency to reconcile on
/// change, since every scheduled instant here is an absolute UTC moment.
///
/// Scoped to whichever profile is currently selected, not every profile —
/// a deliberate v1 limitation, not an oversight. Switching profiles
/// correctly drops the old profile's alarms too: `apply()` cancels every
/// pending notification before rescheduling, so there's no leakage, but a
/// profile that isn't currently selected will never fire a reminder in the
/// background, even if it has alerts configured. Scheduling across every
/// profile simultaneously is a real feature, just not this one.
@riverpod
Future<void> notificationReconcile(Ref ref) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  await scheduler.initialize();

  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  final resinState = await ref.watch(resinControllerProvider.future);
  final alerts = await ref.watch(resinAlertsProvider.future);
  final settings = await ref.watch(settingsSnapshotProvider.future);
  final now = ref.watch(clockProvider).nowUtc();

  const engine = ResinEngine();
  final planned = [
    ...planResinThresholdNotifications(
      profileId: profileId,
      engine: engine,
      state: resinState,
      now: now,
      alerts: [
        for (final alert in alerts) (id: alert.id, threshold: alert.threshold, enabled: alert.enabled),
      ],
    ),
    ...planTransientExpiryNotifications(
      profileId: profileId,
      transient: resinState.transient,
      now: now,
      enabled: settings.transientExpiryAlertEnabled,
    ),
  ];

  await scheduler.apply(planned);
}
