import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/navigation/app_router.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';

/// Layout holds at the required widths (320 / 360 / 412 logical px) and at
/// large font scale with no overflow. RenderFlex overflows surface as test
/// failures automatically; these tests walk every tab at each size.
void main() {
  for (final width in const [320.0, 360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('all tabs render at ${width.toInt()}dp, text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final catalogDb = await openSeedCatalogDatabaseInMemory();
        final userDb = UserDatabase(NativeDatabase.memory());
        addTearDown(catalogDb.close);
        addTearDown(userDb.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              catalogDatabaseProvider.overrideWithValue(catalogDb),
              userDatabaseProvider.overrideWithValue(userDb),
              hoyolabCredentialsStoreProvider.overrideWithValue(
                FakeHoyolabCredentialsStore(),
              ),
              notificationSchedulerProvider.overrideWithValue(
                FakeNotificationScheduler(),
              ),
              clockProvider.overrideWithValue(
                FakeClock(DateTime.utc(2026, 11, 3, 12)),
              ),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 780),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: appRouter,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final tab in const ['Resin', 'Planner', 'Today']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
        }
      });
    }
  }
}
