import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/ids.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/features/planner/application/planner_controller.dart';

void main() {
  // Same fixture as today_controller_test.dart: 2026-11-03 is a Tuesday,
  // and noon UTC sits inside Asia's Tuesday server day.
  final tuesdayNoon = DateTime.utc(2026, 11, 3, 12);

  Future<ProviderContainer> buildContainer() async {
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
    return container;
  }

  /// Seeds 3 targets against the real seed catalog:
  /// - Aster (A4→A6, level held at 70 so EXP/Mora stay 0, talents 6→9
  ///   uniform ×3) — exercises the dawn_books tier-group carry, the
  ///   ember_core singleton, and the "every category, including the
  ///   talent-direct Mora cost, counts toward Σneed" design (its own
  ///   percent rounds to 0 because the 300,000-gleam talent cost dwarfs
  ///   the handful of items it also needs — a faithful, if extreme,
  ///   consequence of pooling every category additively, not a bug).
  /// - Larkspur Spear (A3→A6, level held at 90 so EXP/Mora stay 0, linked
  ///   to Aster) — exercises the weapon subtitle, null talents, and pools
  ///   silt_shards need together with Aster's.
  /// - Wren (no level/ascension/talent movement at all) — exercises the
  ///   percent=100 guard for a target with zero need.
  Future<void> seedTargets(ProviderContainer container) async {
    final planner = container.read(plannerRepositoryProvider);
    final profileId = (await container.read(currentProfileProvider.future)).id;

    await planner.upsertTarget(
      PlannerTargetsCompanion.insert(
        id: newId(),
        profileId: profileId,
        entityKind: 'character',
        entityId: 'aster',
        currentLevel: 70,
        goalLevel: 70,
        currentAscension: 4,
        goalAscension: 6,
        talent1Current: const Value(6),
        talent1Goal: const Value(9),
        talent2Current: const Value(6),
        talent2Goal: const Value(9),
        talent3Current: const Value(6),
        talent3Goal: const Value(9),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await planner.upsertTarget(
      PlannerTargetsCompanion.insert(
        id: newId(),
        profileId: profileId,
        entityKind: 'weapon',
        entityId: 'larkspur_spear',
        linkedCharacterId: const Value('aster'),
        currentLevel: 90,
        goalLevel: 90,
        currentAscension: 3,
        goalAscension: 6,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await planner.upsertTarget(
      PlannerTargetsCompanion.insert(
        id: newId(),
        profileId: profileId,
        entityKind: 'character',
        entityId: 'wren',
        currentLevel: 1,
        goalLevel: 1,
        currentAscension: 0,
        goalAscension: 0,
        talent1Current: const Value(1),
        talent1Goal: const Value(1),
        talent2Current: const Value(1),
        talent2Goal: const Value(1),
        talent3Current: const Value(1),
        talent3Goal: const Value(1),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    await planner.setInventoryCount(profileId, 'dawn_books_t2', 9);
    await planner.setInventoryCount(profileId, 'silt_shards', 2);
    await planner.setInventoryCount(profileId, 'tidal_relics_t3', 1);
  }

  test('build() produces correct per-target cards, pooled most-needed, and header count', () async {
    final container = await buildContainer();
    await seedTargets(container);

    final data = await container.read(plannerControllerProvider.future);

    expect(data.targets.length, 3);
    final aster = data.targets.firstWhere((t) => t.name == 'Aster');
    final larkspur = data.targets.firstWhere((t) => t.name == 'Larkspur Spear');
    final wren = data.targets.firstWhere((t) => t.name == 'Wren');

    expect(aster.isWeapon, isFalse);
    expect(aster.rarity, 5);
    expect(aster.element, 'Pyro');
    expect(aster.subtitle, 'Pyro · character');
    expect(aster.talents, [(current: 6, goal: 9), (current: 6, goal: 9), (current: 6, goal: 9)]);
    expect(aster.percentInHand, 0);

    expect(larkspur.isWeapon, isTrue);
    expect(larkspur.element, isNull);
    expect(larkspur.subtitle, 'Polearm · for Aster');
    expect(larkspur.talents, isNull);
    expect(larkspur.percentInHand, 60);

    expect(wren.subtitle, 'Hydro · character');
    expect(wren.talents, [(current: 1, goal: 1), (current: 1, goal: 1), (current: 1, goal: 1)]);
    expect(wren.percentInHand, 100);

    expect(data.mostNeeded.map((r) => r.materialId).toList(), [
      'dawn_books_t3',
      'ember_core',
      'tidal_relics_t3',
      'silt_shards',
    ]);
    final byId = {for (final row in data.mostNeeded) row.materialId: row};

    expect(byId['dawn_books_t3']!.need, 12);
    expect(byId['dawn_books_t3']!.have, 1);
    expect(byId['dawn_books_t3']!.missing, 11);
    expect(byId['dawn_books_t3']!.label, 'Dawn books · tier 3');
    expect(byId['dawn_books_t3']!.highlightAvailability, isTrue);
    expect(byId['dawn_books_t3']!.availabilityLabel, 'open today');

    expect(byId['ember_core']!.missing, 2);
    expect(byId['ember_core']!.label, 'Ember core');
    expect(byId['ember_core']!.highlightAvailability, isTrue);
    expect(byId['ember_core']!.availabilityLabel, 'any day');

    expect(byId['tidal_relics_t3']!.missing, 2);
    expect(byId['tidal_relics_t3']!.availabilityLabel, 'open today');

    expect(byId['silt_shards']!.need, 3);
    expect(byId['silt_shards']!.have, 2);
    expect(byId['silt_shards']!.missing, 1);
    expect(byId['silt_shards']!.highlightAvailability, isFalse);
    expect(byId['silt_shards']!.availabilityLabel, 'Wed, Sat, Sun');

    // dawn_books_t2 fully donated its surplus upward via the tier-group
    // carry and is fully satisfied — filtered out of "Most needed".
    expect(byId.containsKey('dawn_books_t2'), isFalse);

    // 4 short farmable materials + insight_tome + gleam (both untouched by
    // inventory) = 6, even though only 4 rows are domain-farmable enough
    // to appear in `mostNeeded`.
    expect(data.materialsShortCount, 6);
  });

  test('addTarget persists a new target and invalidates the controller', () async {
    final container = await buildContainer();
    final data = await container.read(plannerControllerProvider.future);
    expect(data.targets, isEmpty);

    await container
        .read(plannerControllerProvider.notifier)
        .addTarget(
          entityKind: 'character',
          entityId: 'corvin',
          currentLevel: 1,
          goalLevel: 1,
          currentAscension: 0,
          goalAscension: 0,
          talents: const [(current: 1, goal: 1), (current: 1, goal: 1), (current: 1, goal: 1)],
        );

    final updated = await container.read(plannerControllerProvider.future);
    expect(updated.targets.length, 1);
    expect(updated.targets.single.name, 'Corvin');
  });
}
