import '../domain/alert_delivery.dart';
import '../domain/notification_plan.dart';
import 'notification_scheduler.dart';

/// A [NotificationScheduler] double for tests and widget previews — same
/// placement convention as `core/clock/fake_clock.dart`. Records the last
/// [apply] call instead of touching any real platform channel.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.delivery = AlertDelivery.onTime});

  AlertDelivery delivery;
  List<PlannedNotification> lastApplied = const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<AlertDelivery> alertDelivery() async => delivery;

  @override
  Future<void> apply(List<PlannedNotification> planned) async {
    lastApplied = planned;
  }
}
