@Tags(['golden'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/ids.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/planner/presentation/planner_screen.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';
import 'package:routine_planner/features/resin/presentation/resin_screen.dart';
import 'package:routine_planner/features/settings/presentation/settings_screen.dart';
import 'package:routine_planner/features/today/presentation/today_screen.dart';

/// Golden coverage: each of the four screens in light and dark, with
/// deterministic fixture data (seed catalog, fixed clock, one planner
/// target, a synced resin value). Text renders in the FlutterTest font
/// (google_fonts fetching is disabled in flutter_test_config.dart), so
/// the images are stable across platforms. Regenerate after intentional
/// UI changes with: flutter test --tags golden --update-goldens
void main() {
  final fixedNow = DateTime.utc(2026, 11, 3, 12); // a Tuesday

  // Seeds deterministic fixture rows (one planner target, a synced resin
  // value) through a throwaway container bound to the same databases.
  Future<void> seedFixtureData(ProviderContainer container) async {
    final profileId = (await container.read(currentProfileProvider.future)).id;
    await container.read(plannerRepositoryProvider).upsertTarget(
          PlannerTargetsCompanion.insert(
            id: newId(),
            profileId: profileId,
            entityKind: 'character',
            entityId: 'aster',
            currentLevel: 70,
            goalLevel: 90,
            currentAscension: 4,
            goalAscension: 6,
            talent1Current: const Value(6),
            talent1Goal: const Value(9),
            talent2Current: const Value(6),
            talent2Goal: const Value(9),
            talent3Current: const Value(6),
            talent3Goal: const Value(9),
            updatedAt: fixedNow,
          ),
        );
    await container.read(resinControllerProvider.future);
    await container
        .read(resinControllerProvider.notifier)
        .sync(132, fullIn: const Duration(hours: 9, minutes: 4));
  }

  for (final (mode, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
    for (final (name, screen) in <(String, Widget)>[
      ('today', const TodayScreen()),
      ('resin', const ResinScreen()),
      ('planner', const PlannerScreen()),
      ('settings', const SettingsScreen()),
    ]) {
      testWidgets('$name screen · $mode', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final catalogDb = await openSeedCatalogDatabaseInMemory();
        final userDb = UserDatabase(NativeDatabase.memory());
        addTearDown(catalogDb.close);
        addTearDown(userDb.close);

        final overrides = [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(fixedNow)),
          notificationSchedulerProvider.overrideWithValue(FakeNotificationScheduler()),
        ];
        final seedContainer = ProviderContainer(overrides: overrides);
        await seedFixtureData(seedContainer);
        seedContainer.dispose();

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(theme: theme, home: screen),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/${name}_$mode.png'),
        );
      });
    }
  }
}
