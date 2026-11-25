import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/notifications/data/notification_scheduler.dart';
import 'package:routine_planner/core/notifications/domain/alert_delivery.dart';
import 'package:routine_planner/core/notifications/domain/notification_plan.dart';

/// The Android half of [FlutterLocalNotificationsScheduler].
///
/// Deliberately a separate file from the iOS tests: both mutate the global
/// `FlutterLocalNotificationsPlatform.instance`, and per-file isolate
/// separation is the only containment available for it (see the note in
/// `notification_scheduler_ios_test.dart`). Plain `test` for the same
/// reason as there — the widget-test harness rejects a platform override
/// that outlives the test body.
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object?> responses;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = <MethodCall>[];
    responses = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return responses[call.method];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  List<String> methodNames() => calls.map((c) => c.method).toList();

  group('alertDelivery', () {
    // The bug this enum was introduced to fix. POST_NOTIFICATIONS can be
    // denied on Android 13+, and the old `canScheduleExactAlarms()` bool
    // reported exact alarms as allowed regardless — so Settings promised
    // "Alerts fire on time" while nothing would ever arrive.
    test(
      'is blocked when notifications are denied, whatever exact alarms say',
      () async {
        responses['areNotificationsEnabled'] = false;
        responses['canScheduleExactNotifications'] = true;

        expect(
          await FlutterLocalNotificationsScheduler().alertDelivery(),
          AlertDelivery.blocked,
        );
        // No point asking: denied notifications make exactness irrelevant.
        expect(methodNames(), isNot(contains('canScheduleExactNotifications')));
      },
    );

    test(
      'is onTime when notifications are enabled and alarms are exact',
      () async {
        responses['areNotificationsEnabled'] = true;
        responses['canScheduleExactNotifications'] = true;

        expect(
          await FlutterLocalNotificationsScheduler().alertDelivery(),
          AlertDelivery.onTime,
        );
      },
    );

    test('is approximate when exact alarms are denied', () async {
      responses['areNotificationsEnabled'] = true;
      responses['canScheduleExactNotifications'] = false;

      expect(
        await FlutterLocalNotificationsScheduler().alertDelivery(),
        AlertDelivery.approximate,
      );
    });

    test('does not consult the iOS permission API', () async {
      responses['areNotificationsEnabled'] = true;
      responses['canScheduleExactNotifications'] = true;

      await FlutterLocalNotificationsScheduler().alertDelivery();

      expect(methodNames(), isNot(contains('checkPermissions')));
    });

    test('is blocked when the platform channel throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      expect(
        await FlutterLocalNotificationsScheduler().alertDelivery(),
        AlertDelivery.blocked,
      );
    });
  });

  group('apply', () {
    // See the note in the iOS test: the plugin validates `scheduledDate`
    // against real wall-clock time, so this reads the real clock.
    final now = DateTime.now().toUtc();
    final planned = <PlannedNotification>[
      (
        id: 1,
        kind: 'resin_threshold',
        title: 'Resin at 160',
        body: 'Five hours to cap',
        scheduledAt: now.add(const Duration(hours: 5)),
      ),
    ];

    test('asks for an exact alarm when delivery is on time', () async {
      responses['areNotificationsEnabled'] = true;
      responses['canScheduleExactNotifications'] = true;

      await FlutterLocalNotificationsScheduler().apply(planned);

      final args =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments
              as Map<Object?, Object?>;
      // The plugin nests scheduleMode inside platformSpecifics.
      final specifics = args['platformSpecifics'] as Map<Object?, Object?>;
      expect(
        specifics['scheduleMode'],
        AndroidScheduleMode.exactAllowWhileIdle.name,
      );
    });

    test('falls back to an inexact alarm when exactness is denied', () async {
      responses['areNotificationsEnabled'] = true;
      responses['canScheduleExactNotifications'] = false;

      await FlutterLocalNotificationsScheduler().apply(planned);

      final args =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments
              as Map<Object?, Object?>;
      // The plugin nests scheduleMode inside platformSpecifics.
      final specifics = args['platformSpecifics'] as Map<Object?, Object?>;
      expect(
        specifics['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
      );
    });

    test('still carries the Android channel details', () async {
      responses['areNotificationsEnabled'] = true;
      responses['canScheduleExactNotifications'] = true;

      await FlutterLocalNotificationsScheduler().apply(planned);

      final args =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments
              as Map<Object?, Object?>;
      final specifics = args['platformSpecifics'] as Map<Object?, Object?>?;
      expect(specifics, isNotNull);
      expect(specifics!['channelId'], 'resin_alerts');
    });
  });
}
