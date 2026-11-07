import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';
import 'package:routine_planner/features/today/application/today_controller.dart';

void main() {
  // 2026-11-03 is a Tuesday. Noon UTC is well inside Asia's Tuesday server
  // day (which runs 2026-11-02T20:00Z .. 2026-11-03T20:00Z).
  final tuesdayNoon = DateTime.utc(2026, 11, 3, 12);

  test('build() lists domains open on a known Tuesday', () async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    final fakeClock = FakeClock(tuesdayNoon);

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(fakeClock),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final data = await container.read(todayControllerProvider.future);

    expect(data.farmCards.map((c) => c.domainId).toSet(), {
      'dawn',
      'tidal',
      'ember_core_boss',
      'weekly_boss',
    });

    final dawnCard = data.farmCards.firstWhere((c) => c.domainId == 'dawn');
    expect(dawnCard.rows.map((r) => r.label).toSet(), {'Dawn Tier 2 Book', 'Dawn Tier 3 Book'});
    expect(dawnCard.scheduleLabel, 'Tue, Fri, Sun');
    expect(dawnCard.alwaysOpen, isFalse);

    final bossCard = data.farmCards.firstWhere((c) => c.domainId == 'ember_core_boss');
    expect(bossCard.alwaysOpen, isTrue);
    expect(bossCard.scheduleLabel, 'Open every day');
  });

  test('toggleTask and logRun mutate the right tables in the right order', () async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    final fakeClock = FakeClock(tuesdayNoon);

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(fakeClock),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final initial = await container.read(todayControllerProvider.future);
    final dawnCard = initial.farmCards.firstWhere((c) => c.domainId == 'dawn');
    final row = dawnCard.rows.first;

    final controller = container.read(todayControllerProvider.notifier);
    await controller.toggleTask(row.taskId, true);

    var updated = await container.read(todayControllerProvider.future);
    var updatedRow = updated.farmCards
        .firstWhere((c) => c.domainId == 'dawn')
        .rows
        .firstWhere((r) => r.taskId == row.taskId);
    expect(updatedRow.checked, isTrue);
    expect(updatedRow.runsDone, 0);

    final initialResin = await container.read(resinControllerProvider.future);
    await controller.logRun(taskId: row.taskId, costResin: 20);

    final resinAfter = await container.read(resinControllerProvider.future);
    expect(resinAfter.v, initialResin.v - 20);

    updated = await container.read(todayControllerProvider.future);
    updatedRow = updated.farmCards
        .firstWhere((c) => c.domainId == 'dawn')
        .rows
        .firstWhere((r) => r.taskId == row.taskId);
    expect(updatedRow.runsDone, 1);
  });
}
