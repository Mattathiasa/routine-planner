import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_plan.dart';

/// The side-effecting half of notification reconcile — [apply] turns a
/// pure [PlannedNotification] list into real scheduled (or cancelled)
/// system notifications. No `requestExactAlarmsPermission` here: the
/// approved design shows the exact-alarms banner as read-only status with
/// no action button, so nothing ever needs to call it.
abstract class NotificationScheduler {
  Future<void> initialize();
  Future<bool> canScheduleExactAlarms();
  Future<void> apply(List<PlannedNotification> planned);
}

/// Real implementation on top of `flutter_local_notifications`. Every
/// scheduled instant is an absolute UTC moment (a resin-threshold time or
/// a transient-batch expiry minus 24h) rather than a recurring local-time
/// reminder, so `tz.UTC` — a built-in constant, no `initializeTimeZones()`
/// needed — is the only time zone this ever touches.
class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  static const _channelId = 'resin_alerts';
  static const _channelName = 'Resin alerts';
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(_channelId, _channelName, importance: Importance.high),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (error) {
      // Unsupported platform, or a registration hiccup — never let
      // notification setup crash app start.
      debugPrint('NotificationScheduler.initialize failed: $error');
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      final allowed = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      return allowed ?? false;
    } catch (error) {
      debugPrint('NotificationScheduler.canScheduleExactAlarms failed: $error');
      return false;
    }
  }

  @override
  Future<void> apply(List<PlannedNotification> planned) async {
    try {
      await _plugin.cancelAll();
      final exact = await canScheduleExactAlarms();
      for (final notification in planned) {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          scheduledDate: tz.TZDateTime.from(notification.scheduledAt.toUtc(), tz.UTC),
          notificationDetails: _notificationDetails,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      debugPrint('NotificationScheduler.apply failed: $error');
    }
  }
}
