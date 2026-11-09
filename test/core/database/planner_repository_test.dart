import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/planner_repository.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';

void main() {
  late UserDatabase db;
  late PlannerRepository repository;
  late String profileId;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = PlannerRepository(db);
    profileId = (await ProfileRepository(db).getActiveProfile()).id;
  });

  tearDown(() => db.close());

  group('planner targets', () {
    test('upsertTarget inserts, then updates the same row by id', () async {
      const targetId = 'target-1';
      await repository.upsertTarget(
        PlannerTargetsCompanion.insert(
          id: targetId,
          profileId: profileId,
          entityKind: 'character',
          entityId: 'aster',
          currentLevel: 70,
          goalLevel: 90,
          currentAscension: 4,
          goalAscension: 6,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await repository.upsertTarget(
        PlannerTargetsCompanion.insert(
          id: targetId,
          profileId: profileId,
          entityKind: 'character',
          entityId: 'aster',
          currentLevel: 80,
          goalLevel: 90,
          currentAscension: 5,
          goalAscension: 6,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final targets = await repository.targetsForProfile(profileId);
      expect(targets, hasLength(1));
      expect(targets.single.currentLevel, 80);
    });

    test('targetsForProfile orders by sortOrder and excludes soft-deleted rows', () async {
      await repository.upsertTarget(
        PlannerTargetsCompanion.insert(
          id: 'b',
          profileId: profileId,
          entityKind: 'character',
          entityId: 'wren',
          currentLevel: 1,
          goalLevel: 90,
          currentAscension: 0,
          goalAscension: 6,
          sortOrder: const Value(1),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await repository.upsertTarget(
        PlannerTargetsCompanion.insert(
          id: 'a',
          profileId: profileId,
          entityKind: 'character',
          entityId: 'aster',
          currentLevel: 1,
          goalLevel: 90,
          currentAscension: 0,
          goalAscension: 6,
          sortOrder: const Value(0),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      expect((await repository.targetsForProfile(profileId)).map((t) => t.id), ['a', 'b']);

      await repository.softDeleteTarget('a');
      expect((await repository.targetsForProfile(profileId)).map((t) => t.id), ['b']);
    });
  });

  group('material inventory', () {
    test('setInventoryCount inserts then overwrites the same (profile, material) row', () async {
      await repository.setInventoryCount(profileId, 'ember_core', 3);
      await repository.setInventoryCount(profileId, 'ember_core', 9);

      final inventory = await repository.inventoryForProfile(profileId);
      expect(inventory, {'ember_core': 9});

      final rows = await db.select(db.materialInventory).get();
      expect(rows, hasLength(1));
    });
  });

  group('daily tasks', () {
    final periodAnchor = DateTime.utc(2026, 11, 6);

    test('ensureTask builds the serverDate:domain:tierGroup key and is idempotent', () async {
      final first = await repository.ensureTask(
        profileId,
        periodAnchor: periodAnchor,
        domainId: 'dawn',
        tierGroup: 'dawn_books_t2',
      );
      expect(first.taskKey, '${periodAnchor.toIso8601String()}:dawn:dawn_books_t2');

      final second = await repository.ensureTask(
        profileId,
        periodAnchor: periodAnchor,
        domainId: 'dawn',
        tierGroup: 'dawn_books_t2',
      );
      expect(second.id, first.id);

      final rows = await db.select(db.dailyTasks).get();
      expect(rows, hasLength(1));
    });

    test('checked and runsDone are independent', () async {
      final task = await repository.ensureTask(
        profileId,
        periodAnchor: periodAnchor,
        domainId: 'dawn',
        tierGroup: 'dawn_books_t2',
      );

      await repository.setChecked(task.id, true);
      await repository.incrementRunsDone(task.id);
      await repository.incrementRunsDone(task.id);

      final reloaded = await repository.taskForKey(profileId, task.taskKey);
      expect(reloaded!.checked, isTrue);
      expect(reloaded.runsDone, 2);
    });
  });
}
