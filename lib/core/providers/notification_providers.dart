import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/accounts/application/accounts_overview_controller.dart';
import '../../features/resin/data/resin_providers.dart';
import '../../features/resin/domain/resin_engine.dart';
import '../clock/game_server.dart';
import '../clock/server_clock.dart';
import '../notifications/data/fake_notification_scheduler.dart';
import '../notifications/data/notification_scheduler.dart';
import '../notifications/domain/alert_delivery.dart';
import '../notifications/domain/notification_plan.dart';
import 'clock_providers.dart';
import 'profile_providers.dart';
import 'repository_providers.dart';

part 'notification_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationScheduler notificationScheduler(Ref ref) {
  if (kIsWeb) {
    // Web schedules nothing — the scheduler is a no-op. `approximate`
    // keeps the banner exactly as it renders today rather than inventing
    // unapproved web copy; `blocked` would be the literal truth but reads
    // as an iOS/Android permission problem the user can't act on.
    // See docs/ASSUMPTIONS.md.
    return FakeNotificationScheduler(delivery: AlertDelivery.approximate);
  }
  return FlutterLocalNotificationsScheduler();
}

@riverpod
Future<AlertDelivery> alertDelivery(Ref ref) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  await scheduler.initialize();
  return scheduler.alertDelivery();
}

/// Reactive, idempotent reconcile: watching resin state, alerts, settings
/// and account status means this automatically re-runs after every
/// mutation — no manual call-sites needed anywhere else in the app.
/// `AppShell` watches this once, which also covers "app start" since it's
/// always mounted past initial routing. "Reboot" is handled entirely
/// natively by the plugin's own boot receiver once the manifest is wired;
/// there's no live local time-zone dependency to reconcile on change,
/// since every scheduled instant here is an absolute UTC moment.
///
/// Plans for **every** account, not just the selected one: each account's
/// resin thresholds and commission reminder are scheduled together, with
/// the account name in the title once more than one exists.
/// `stableNotificationId` already namespaces ids by profile, so the plans
/// can't collide, and `apply()` still cancels everything before
/// rescheduling, keeping the whole thing idempotent.
@riverpod
Future<void> notificationReconcile(Ref ref) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  await scheduler.initialize();

  final profiles = await ref.watch(profileListProvider.future);
  final now = ref.watch(clockProvider).nowUtc();
  final clock = ref.watch(clockProvider);
  final resinRepository = ref.watch(resinRepositoryProvider);
  final settingsRepository = ref.watch(settingsRepositoryProvider);

  // Commission progress is per account and already assembled here,
  // including the live-or-manual decision.
  final accounts = await ref.watch(accountsOverviewControllerProvider.future);

  // Only label notifications when there's more than one account to tell
  // apart.
  final labelAccounts = profiles.length > 1;

  const engine = ResinEngine();
  final planned = <PlannedNotification>[];

  for (final profile in profiles) {
    final label = labelAccounts ? profile.displayName : null;
    final resinState = await resinRepository.loadResinState(profile.id);
    final alerts = await settingsRepository.alertsForProfile(profile.id);
    final settings = await settingsRepository.getOrCreateSettings(profile.id);

    planned.addAll(
      planResinThresholdNotifications(
        profileId: profile.id,
        engine: engine,
        state: resinState,
        now: now,
        accountLabel: label,
        alerts: [
          for (final alert in alerts)
            (id: alert.id, threshold: alert.threshold, enabled: alert.enabled),
        ],
      ),
    );

    planned.addAll(
      planTransientExpiryNotifications(
        profileId: profile.id,
        transient: resinState.transient,
        now: now,
        accountLabel: label,
        enabled: settings.transientExpiryAlertEnabled,
      ),
    );

    // Each account resets on its own server clock, so the reminder time
    // is computed per account rather than from the selected profile.
    final serverClock = ServerClock(
      clock,
      GameServer.values.byName(profile.server),
    );
    final commissions = accounts
        .where((a) => a.profileId == profile.id)
        .map((a) => a.commissions)
        .firstOrNull;
    if (commissions != null) {
      planned.addAll(
        planCommissionReminder(
          profileId: profile.id,
          nextResetUtc: serverClock
              .dayStartUtc(now)
              .add(const Duration(days: 1)),
          now: now,
          completed: commissions.completed,
          total: commissions.total,
          enabled: settings.commissionReminderEnabled,
          accountLabel: label,
        ),
      );
    }
  }

  await scheduler.apply(planned);
}
