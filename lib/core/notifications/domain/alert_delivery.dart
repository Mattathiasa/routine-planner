/// How the system will actually deliver scheduled alerts, so Settings can
/// state the truth instead of promising precision it cannot keep.
///
/// Pure Dart, no Flutter/plugin imports — mirrors [PlannedNotification]'s
/// purity in `notification_plan.dart`.
///
/// This replaced a plain `canScheduleExactAlarms()` bool, which could not
/// express "the user denied notifications outright". That was an Android bug
/// as well as an iOS one: `POST_NOTIFICATIONS` can be denied on Android 13+,
/// and the bool still reported exact alarms as allowed, so the banner said
/// "Alerts fire on time" while nothing would ever arrive.
enum AlertDelivery {
  /// Delivered at the scheduled instant. Android: notifications are enabled
  /// *and* exact alarms are allowed. iOS: notification permission granted.
  onTime,

  /// Delivered, but the OS may defer it. Android only — exact alarms were
  /// denied, so the plugin falls back to an inexact alarm. iOS has no
  /// inexact mode, so this is never reported there.
  approximate,

  /// Not delivered at all: notification permission is denied.
  blocked;

  /// Whether to ask Android for an exact alarm. Only [onTime] has both the
  /// permission and the exactness to justify it.
  bool get useExactAlarms => this == AlertDelivery.onTime;
}
