import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/navigation/app_router.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';

void main() {
  testWidgets('bottom nav switches tabs; gear reaches Settings; back returns', (tester) async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          notificationSchedulerProvider.overrideWithValue(FakeNotificationScheduler()),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original Resin'), findsOneWidget);

    await tester.tap(find.text('Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Sync with game', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.text('0 targets · 0 materials short'), findsOneWidget);
    expect(find.text('Nothing missing — fully stocked.'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Original Resin'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Game server', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Today')); // the "‹ Today" back-link
    await tester.pumpAndSettle();
    expect(find.text('Original Resin'), findsOneWidget);
  });
}
