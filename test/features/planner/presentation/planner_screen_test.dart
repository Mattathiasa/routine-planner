import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/ids.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/planner/presentation/planner_screen.dart';

/// Seeds planner targets through a throwaway [ProviderContainer] wired to
/// the same (not-yet-pumped) databases, so the widget tree's real
/// `PlannerController` sees them on first build — mirroring
/// `planner_controller_test.dart`'s seeding pattern.
Future<void> _seedTargets(
  UserDatabase userDb,
  CatalogDatabase catalogDb,
  List<PlannerTargetsCompanion> Function(String profileId) buildTargets,
) async {
  final container = ProviderContainer(
    overrides: [
      catalogDatabaseProvider.overrideWithValue(catalogDb),
      userDatabaseProvider.overrideWithValue(userDb),
    ],
  );
  final planner = container.read(plannerRepositoryProvider);
  final profileId = (await container.read(currentProfileProvider.future)).id;
  for (final target in buildTargets(profileId)) {
    await planner.upsertTarget(target);
  }
  container.dispose();
}

void main() {
  Future<void> setViewportTallEnough(WidgetTester tester) async {
    // The Planner screen can be taller than the default test viewport once
    // several target cards and the "Most needed" list are both on screen.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('collapses Lv+ascension into one "done" chip only when both are done', (
    tester,
  ) async {
    await setViewportTallEnough(tester);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await _seedTargets(userDb, catalogDb, (profileId) {
      final now = DateTime.now().toUtc();
      return [
        // Both level and ascension already at goal -> one merged chip.
        // Non-uniform talents -> "4·6·6 -> 8·8·8" formatting.
        PlannerTargetsCompanion.insert(
          id: newId(),
          profileId: profileId,
          entityKind: 'character',
          entityId: 'corvin',
          currentLevel: 90,
          goalLevel: 90,
          currentAscension: 6,
          goalAscension: 6,
          talent1Current: const Value(4),
          talent1Goal: const Value(8),
          talent2Current: const Value(6),
          talent2Goal: const Value(8),
          talent3Current: const Value(6),
          talent3Goal: const Value(8),
          updatedAt: now,
        ),
        // Level not yet at goal -> two separate chips. Uniform talents ->
        // "all 8 -> 10" formatting.
        PlannerTargetsCompanion.insert(
          id: newId(),
          profileId: profileId,
          entityKind: 'character',
          entityId: 'wren',
          currentLevel: 70,
          goalLevel: 90,
          currentAscension: 5,
          goalAscension: 6,
          talent1Current: const Value(8),
          talent1Goal: const Value(10),
          talent2Current: const Value(8),
          talent2Goal: const Value(10),
          talent3Current: const Value(8),
          talent3Goal: const Value(10),
          updatedAt: now,
        ),
      ];
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 3, 12))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv 90 · done', skipOffstage: false), findsOneWidget);
    expect(find.text('Talents 4·6·6 → 8·8·8', skipOffstage: false), findsOneWidget);
    expect(find.text('A6 → A6', skipOffstage: false), findsNothing);

    expect(find.text('Lv 70 → 90', skipOffstage: false), findsOneWidget);
    expect(find.text('A5 → A6', skipOffstage: false), findsOneWidget);
    expect(find.text('Talents all 8 → 10', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Add target form creates a new target card', (tester) async {
    await setViewportTallEnough(tester);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 3, 12))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 targets · 0 materials short'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Character segment + the prefilled defaults (Lv 1 -> 90, A0 -> A6,
    // talents all 1 -> 9) are left untouched; only the entity is picked.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corvin').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // The default Lv 1 -> 90 range pulls in the (entityKind-shared, not
    // per-character) seeded EXP-curve rows at level 70/80, so Corvin also
    // owes derived EXP books + Mora even though it has no catalog
    // ascension/talent rows of its own — 3 short (insight_tome,
    // insight_primer, gleam), none of them farmable, so "Most needed"
    // itself stays empty.
    expect(find.text('1 targets · 3 materials short'), findsOneWidget);
    expect(find.text('Nothing missing — fully stocked.', skipOffstage: false), findsOneWidget);
    expect(find.text('Corvin'), findsOneWidget);
    expect(find.text('Lv 1 → 90', skipOffstage: false), findsOneWidget);
    expect(find.text('A0 → A6', skipOffstage: false), findsOneWidget);
    expect(find.text('Talents all 1 → 9', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Most needed shows at most 5 rows, sorted by missing descending', (tester) async {
    await setViewportTallEnough(tester);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    // 3 extra farmable materials, needed only by Aster's ascension, so the
    // pool has 6 distinct short materials — more than the 5-row display
    // cap.
    for (final extra in [
      (id: 'mist_dust', name: 'Mist dust', quantity: 5),
      (id: 'storm_dust', name: 'Storm dust', quantity: 7),
      (id: 'glow_dust', name: 'Glow dust', quantity: 9),
    ]) {
      await catalogDb
          .into(catalogDb.materials)
          .insert(MaterialsCompanion.insert(id: extra.id, name: extra.name, category: 'bossMaterial'));
      await catalogDb
          .into(catalogDb.ascensionRequirements)
          .insert(
            AscensionRequirementsCompanion.insert(
              entityKind: 'character',
              entityId: 'aster',
              phase: 6,
              materialId: extra.id,
              quantity: extra.quantity,
            ),
          );
    }

    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await _seedTargets(userDb, catalogDb, (profileId) {
      final now = DateTime.now().toUtc();
      return [
        PlannerTargetsCompanion.insert(
          id: newId(),
          profileId: profileId,
          entityKind: 'character',
          entityId: 'aster',
          currentLevel: 70,
          goalLevel: 70,
          currentAscension: 4,
          goalAscension: 6,
          updatedAt: now,
        ),
        PlannerTargetsCompanion.insert(
          id: newId(),
          profileId: profileId,
          entityKind: 'weapon',
          entityId: 'larkspur_spear',
          currentLevel: 90,
          goalLevel: 90,
          currentAscension: 3,
          goalAscension: 6,
          updatedAt: now,
        ),
      ];
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 3, 12))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Missing: glow_dust 9, storm_dust 7, mist_dust 5, silt_shards 3,
    // tidal_relics_t3 3, ember_core 2 — only the lowest (ember_core) is cut.
    expect(find.text('Glow dust'), findsOneWidget);
    expect(find.text('Storm dust'), findsOneWidget);
    expect(find.text('Mist dust'), findsOneWidget);
    expect(find.text('Silt shards · tier 4'), findsOneWidget);
    expect(find.text('Tidal relics · tier 3'), findsOneWidget);
    expect(find.text('Ember core'), findsNothing);

    final glowY = tester.getTopLeft(find.text('Glow dust')).dy;
    final stormY = tester.getTopLeft(find.text('Storm dust')).dy;
    final mistY = tester.getTopLeft(find.text('Mist dust')).dy;
    expect(glowY, lessThan(stormY));
    expect(stormY, lessThan(mistY));
  });
}
