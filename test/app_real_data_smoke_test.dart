import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/bundled/bundled_catalog.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/navigation/app_router.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';

/// End-to-end smoke over the *production* wiring: the bundled real-data
/// catalog (not the placeholder seed fixture) behind every screen. Guards
/// the Phase-"no sample data" property: what the user sees comes from the
/// generated catalog and live user state.
void main() {
  testWidgets('all four screens run on the bundled real catalog', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openBundledCatalogDatabaseInMemory();
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

    // Today renders from live resin state.
    expect(find.text('Original Resin'), findsOneWidget);

    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.text('0 targets · 0 materials short'), findsOneWidget);

    // Add target lists real catalog characters.
    await tester.tap(find.text('Add target'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Furina'), findsWidgets);
    await tester.tap(find.text('Furina').last);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Add target');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Back on the Planner: the new target is live user state, and its
    // materials come from the real catalog's requirement rows.
    expect(find.text('Furina', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('1 targets', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Sync with game', skipOffstage: false), findsOneWidget);
  });
}
