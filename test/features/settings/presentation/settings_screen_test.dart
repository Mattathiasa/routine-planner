import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/clock/game_server.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/notifications/domain/alert_delivery.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/settings/presentation/game_server_section.dart';
import 'package:routine_planner/features/settings/presentation/planner_settings_section.dart';
import 'package:routine_planner/features/settings/presentation/settings_screen.dart';

void main() {
  late UserDatabase userDb;

  Future<void> pumpSettingsScreen(
    WidgetTester tester, {
    FakeNotificationScheduler? scheduler,
  }) async {
    // Taller than the default test viewport once every section + footer
    // is on screen.
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(
            FakeClock(DateTime.utc(2026, 11, 3, 12)),
          ),
          notificationSchedulerProvider.overrideWithValue(
            scheduler ?? FakeNotificationScheduler(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String labelText) {
    final row = find
        .ancestor(of: find.text(labelText), matching: find.byType(Row))
        .first;
    return find.descendant(of: row, matching: find.byType(Switch));
  }

  testWidgets('all 4 server rows render with their UTC offset label', (
    tester,
  ) async {
    await pumpSettingsScreen(tester);

    final serverSection = find.byType(GameServerSection);
    expect(
      find.descendant(
        of: serverSection,
        matching: find.text('Asia', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: serverSection,
        matching: find.text('Europe', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: serverSection,
        matching: find.text('America', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: serverSection,
        matching: find.text('TW, HK, MO', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: serverSection,
        matching: find.textContaining('UTC+8', skipOffstage: false),
      ),
      findsNWidgets(2),
    ); // Asia + TW,HK,MO
    expect(
      find.descendant(
        of: serverSection,
        matching: find.textContaining('UTC+1', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: serverSection,
        matching: find.textContaining('UTC-5', skipOffstage: false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a different server radio flips selection and persists', (
    tester,
  ) async {
    await pumpSettingsScreen(tester);

    final europeRow = find
        .ancestor(of: find.text('Europe'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: europeRow, matching: find.byType(Radio<GameServer>)),
    );
    await tester.pumpAndSettle();

    final profiles = await userDb.select(userDb.profiles).get();
    expect(profiles.single.server, 'europe');
  });

  testWidgets('World Level stepper clamps at 0 and 9', (tester) async {
    await pumpSettingsScreen(tester);

    final plannerSection = find.byType(PlannerSettingsSection);
    // Starts at 0 (table default) — "-" is a no-op.
    await tester.tap(
      find.descendant(of: plannerSection, matching: find.byIcon(Icons.remove)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0', skipOffstage: false), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(
        find.descendant(of: plannerSection, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('9', skipOffstage: false), findsOneWidget);
  });

  testWidgets('toggling the 160 switch enables that resin alert', (
    tester,
  ) async {
    await pumpSettingsScreen(tester);

    await tester.tap(switchFor('Resin reaches 160'));
    await tester.pumpAndSettle();

    final alerts = await userDb.select(userDb.resinAlertThresholds).get();
    expect(alerts.where((a) => a.threshold == 160 && a.enabled), hasLength(1));
  });

  testWidgets('the delivery banner renders green when alerts fire on time', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      scheduler: FakeNotificationScheduler(delivery: AlertDelivery.onTime),
    );

    expect(
      find.textContaining('Exact alarms allowed.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the delivery banner renders amber when alerts are inexact', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      scheduler: FakeNotificationScheduler(delivery: AlertDelivery.approximate),
    );

    expect(
      find.textContaining('Exact alarms not available.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the delivery banner says notifications are off when blocked', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      scheduler: FakeNotificationScheduler(delivery: AlertDelivery.blocked),
    );

    expect(
      find.textContaining('Notifications are off.', skipOffstage: false),
      findsOneWidget,
    );
    // Never promise precision in the blocked state.
    expect(
      find.textContaining('Alerts fire on time.', skipOffstage: false),
      findsNothing,
    );
  });

  // The approved design shows this banner as read-only status. Pinned so a
  // future contributor doesn't helpfully add an "Open Settings" button.
  testWidgets('the delivery banner offers no action button when blocked', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      scheduler: FakeNotificationScheduler(delivery: AlertDelivery.blocked),
    );

    final banner = find.ancestor(
      of: find.textContaining('Notifications are off.', skipOffstage: false),
      matching: find.byType(Container),
    );
    expect(
      find.descendant(
        of: banner.first,
        matching: find.byType(ButtonStyleButton),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });
}
