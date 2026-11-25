import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/alert_delivery.dart';
import '../domain/notification_plan.dart';

/// The side-effecting half of notification reconcile — [apply] turns a
/// pure [PlannedNotification] list into real scheduled (or cancelled)
/// system notifications. No `requestExactAlarmsPermission` here: the
/// approved design shows the delivery banner as read-only status with no
/// action button, so nothing ever needs to call it. The iOS permission
/// prompt is a system modal raised by [initialize], not an in-app
/// affordance, so that design holds on both platforms.
abstract class NotificationScheduler {
  Future<void> initialize();

  /// What the system will actually do with a scheduled alert. Drives the
  /// Settings banner and the Android exact/inexact choice in [apply].
  Future<AlertDelivery> alertDelivery();

  Future<void> apply(List<PlannedNotification> planned);
}

/// Real implementation on top of `flutter_local_notifications`. Every
/// scheduled instant is an absolute UTC moment (a resin-threshold time or
/// a transient-batch expiry minus 24h) rather than a recurring local-time
/// reminder, so `tz.UTC` — a built-in constant, no `initializeTimeZones()`
/// needed — is the only time zone this ever touches.
///
/// Platform is detected by which `resolvePlatformSpecificImplementation`
/// returns non-null rather than by `Platform.isIOS`, keeping this the only
/// file that knows a platform split exists at all.
class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  static const _channelId = 'resin_alerts';
  static const _channelName = 'Resin alerts';
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
    ),
    // iOS has no channel concept; `threadIdentifier` is the closest thing,
    // grouping these alerts together in Notification Center. No badge: the
    // app never shows a count, so setting one would leave a dot the user
    // can't clear from inside the app. Deliberately not
    // `InterruptionLevel.timeSensitive` — that needs the time-sensitive
    // entitlement, which needs a paid Apple Developer Program membership.
    iOS: DarwinNotificationDetails(
      threadIdentifier: _channelId,
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      presentBadge: false,
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Required on iOS: the plugin throws ArgumentError when targeting
          // iOS with a null `iOS` member, so omitting this didn't merely
          // skip the permission request, it failed initialization outright.
          // The defaults (`requestAlertPermission`, `requestSoundPermission`,
          // `requestBadgePermission` all true) raise the system permission
          // prompt here, which is what makes notifications work at all.
          iOS: DarwinInitializationSettings(requestBadgePermission: false),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      // Only latch success. Set before the try, a transient registration
      // hiccup would permanently disable notifications for the process.
      _initialized = true;
    } catch (error) {
      // Unsupported platform, or a registration hiccup — never let
      // notification setup crash app start.
      debugPrint('NotificationScheduler.initialize failed: $error');
    }
  }

  @override
  Future<AlertDelivery> alertDelivery() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        // POST_NOTIFICATIONS can be denied on Android 13+, in which case
        // exact-alarm status is irrelevant — nothing arrives either way.
        if (await android.areNotificationsEnabled() != true) {
          return AlertDelivery.blocked;
        }
        return await android.canScheduleExactNotifications() == true
            ? AlertDelivery.onTime
            : AlertDelivery.approximate;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        // iOS delivers local notifications at the scheduled instant and has
        // no inexact mode, so the permission is the only failure mode and
        // AlertDelivery.approximate is unreachable here.
        final permissions = await ios.checkPermissions();
        return permissions?.isEnabled == true
            ? AlertDelivery.onTime
            : AlertDelivery.blocked;
      }

      // No platform implementation registered — nothing will be delivered.
      return AlertDelivery.blocked;
    } catch (error) {
      debugPrint('NotificationScheduler.alertDelivery failed: $error');
      return AlertDelivery.blocked;
    }
  }

  @override
  Future<void> apply(List<PlannedNotification> planned) async {
    try {
      await _plugin.cancelAll();
      final delivery = await alertDelivery();
      // Nothing would arrive, so scheduling would only mislead the logs.
      // cancelAll above still ran, keeping this idempotent.
      if (delivery == AlertDelivery.blocked) return;
      for (final notification in planned) {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          scheduledDate: tz.TZDateTime.from(
            notification.scheduledAt.toUtc(),
            tz.UTC,
          ),
          notificationDetails: _notificationDetails,
          androidScheduleMode: delivery.useExactAlarms
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      debugPrint('NotificationScheduler.apply failed: $error');
    }
  }
}
