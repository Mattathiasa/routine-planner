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
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/planner/presentation/planner_screen.dart';
import 'package:routine_planner/features/wishes/data/wish_providers.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';
import 'package:routine_planner/features/primogems/data/primogem_providers.dart';
import 'package:routine_planner/features/resin/presentation/resin_screen.dart';
import 'package:routine_planner/features/settings/presentation/settings_screen.dart';
import 'package:routine_planner/features/today/presentation/today_screen.dart';
import 'package:routine_planner/features/wishes/presentation/wishes_screen.dart';

/// Golden coverage: each of the five screens in light and dark, with
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
    await container
        .read(plannerRepositoryProvider)
        .upsertTarget(
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

    // Wishes: enough history for pity, a 5★ row and real statistics. Names
    // are the seed catalog's own sample characters.
    await container.read(wishRepositoryProvider).insertPulls(profileId, [
      for (var i = 1; i <= 34; i++)
        WishPull(
          id: (1700000000000000000 + i).toString(),
          banner: WishBanner.character,
          itemName: switch (i) {
            6 => 'Aster',
            18 => 'Wren',
            _ => 'Larkspur Spear',
          },
          kind: i == 6 || i == 18 ? WishItemKind.character : WishItemKind.weapon,
          rarity: switch (i) {
            6 => 5,
            18 => 4,
            _ => 3,
          },
          pulledAtUtc: fixedNow.subtract(Duration(hours: (34 - i) * 3)),
        ),
    ], now: fixedNow);

    final primogems = container.read(primogemRepositoryProvider);
    await primogems.setAnchor(
      profileId,
      balance: 12480,
      fates: 6,
      anchoredAt: fixedNow.subtract(const Duration(days: 9)),
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 2140,
    );
    await primogems.saveMonthlyIncome(
      profileId,
      month: '2026-11',
      primogems: 3860,
      fetchedAt: fixedNow,
    );
  }

  for (final (mode, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    for (final (name, screen) in <(String, Widget)>[
      ('today', const TodayScreen()),
      ('resin', const ResinScreen()),
      ('planner', const PlannerScreen()),
      ('wishes', const WishesScreen()),
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
          hoyolabCredentialsStoreProvider.overrideWithValue(
            FakeHoyolabCredentialsStore(),
          ),
          clockProvider.overrideWithValue(FakeClock(fixedNow)),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
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
