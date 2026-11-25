import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/notifications/data/notification_scheduler.dart';
import 'package:routine_planner/core/notifications/domain/alert_delivery.dart';
import 'package:routine_planner/core/notifications/domain/notification_plan.dart';

/// The iOS half of [FlutterLocalNotificationsScheduler], driven through a
/// mocked plugin channel.
///
/// Two globals are mutated here: `debugDefaultTargetPlatformOverride` and
/// `FlutterLocalNotificationsPlatform.instance` (which
/// `resolvePlatformSpecificImplementation` reads to decide which platform
/// implementation to hand back). `flutter test` runs each test *file* in its
/// own isolate, so neither can be observed by another test file — and that
/// isolation is the only containment available for the plugin instance,
/// because the platform interface declares it as an uninitialized
/// `static late` field with no getter that is safe to read before a
/// `registerWith()` call. So: keep iOS-branch tests in this file, Android
/// ones in their own, and never assert on these globals from elsewhere.
///
/// Plain `test` rather than `testWidgets`: the widget-test harness asserts
/// every foundation debug variable is unset *before* `tearDown` runs, so a
/// platform override set in `setUp` fails the invariant check. Nothing here
/// pumps a widget anyway.
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Map<String, Object?> responses;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
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

  group('initialize', () {
    // Regression test for the bug that made notifications dead on iOS: with
    // no `iOS:` member the plugin raises ArgumentError before sending
    // anything, so the channel never sees an `initialize` call at all.
    test('sends Darwin initialization settings', () async {
      await FlutterLocalNotificationsScheduler().initialize();

      expect(methodNames(), contains('initialize'));
      final args =
          calls.firstWhere((c) => c.method == 'initialize').arguments
              as Map<Object?, Object?>;
      expect(args['requestAlertPermission'], isTrue);
      expect(args['requestSoundPermission'], isTrue);
    });

    // The app shows no badge count, so asking for the badge permission would
    // let iOS leave a dot the user cannot clear from inside the app.
    test('does not request the badge permission', () async {
      await FlutterLocalNotificationsScheduler().initialize();

      final args =
          calls.firstWhere((c) => c.method == 'initialize').arguments
              as Map<Object?, Object?>;
      expect(args['requestBadgePermission'], isFalse);
    });

    test('does not take the Android permission path', () async {
      await FlutterLocalNotificationsScheduler().initialize();

      expect(methodNames(), isNot(contains('requestNotificationsPermission')));
    });

    test('initializes once across repeated calls', () async {
      final scheduler = FlutterLocalNotificationsScheduler();
      await scheduler.initialize();
      await scheduler.initialize();

      expect(methodNames().where((m) => m == 'initialize'), hasLength(1));
    });
  });

  group('alertDelivery', () {
    test('is onTime when notifications are permitted', () async {
      responses['checkPermissions'] = <String, Object?>{'isEnabled': true};

      expect(
        await FlutterLocalNotificationsScheduler().alertDelivery(),
        AlertDelivery.onTime,
      );
      // iOS has no inexact mode, so exact-alarm status is never consulted.
      expect(methodNames(), isNot(contains('canScheduleExactNotifications')));
    });

    test('is blocked when notifications are denied', () async {
      responses['checkPermissions'] = <String, Object?>{'isEnabled': false};

      expect(
        await FlutterLocalNotificationsScheduler().alertDelivery(),
        AlertDelivery.blocked,
      );
    });

    test('is blocked when the permission state is unknown', () async {
      responses['checkPermissions'] = null;

      expect(
        await FlutterLocalNotificationsScheduler().alertDelivery(),
        AlertDelivery.blocked,
      );
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
    // The one place in this repo that legitimately reads the real clock: the
    // plugin itself rejects a `scheduledDate` in the past, and it validates
    // against real wall-clock time, not an injected one. `apply` takes
    // absolute instants, so there is no Clock seam to inject here.
    final now = DateTime.now().toUtc();
    final planned = <PlannedNotification>[
      (
        id: 1,
        kind: 'resin_threshold',
        title: 'Resin at 160',
        body: 'Five hours to cap',
        scheduledAt: now.add(const Duration(hours: 5)),
      ),
      (
        id: 2,
        kind: 'resin_threshold',
        title: 'Resin capped',
        body: 'Regeneration stopped',
        scheduledAt: now.add(const Duration(hours: 10)),
      ),
    ];

    test('cancels then schedules every planned alert', () async {
      responses['checkPermissions'] = <String, Object?>{'isEnabled': true};

      await FlutterLocalNotificationsScheduler().apply(planned);

      expect(
        methodNames(),
        containsAllInOrder(['cancelAll', 'zonedSchedule', 'zonedSchedule']),
      );
    });

    // Regression test for the missing `iOS:` half of NotificationDetails:
    // without it the scheduled notification carries no presentation options.
    test('carries the Darwin presentation details', () async {
      responses['checkPermissions'] = <String, Object?>{'isEnabled': true};

      await FlutterLocalNotificationsScheduler().apply(planned);

      final args =
          calls.firstWhere((c) => c.method == 'zonedSchedule').arguments
              as Map<Object?, Object?>;
      final specifics = args['platformSpecifics'] as Map<Object?, Object?>?;
      expect(specifics, isNotNull);
      expect(specifics!['presentAlert'], isTrue);
      expect(specifics['threadIdentifier'], 'resin_alerts');
    });

    test('cancels but schedules nothing when delivery is blocked', () async {
      responses['checkPermissions'] = <String, Object?>{'isEnabled': false};

      await FlutterLocalNotificationsScheduler().apply(planned);

      expect(methodNames(), contains('cancelAll'));
      expect(methodNames(), isNot(contains('zonedSchedule')));
    });
  });
}
