import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Reads and writes planner targets, owned-material counts, and the daily
/// checklist. Pure persistence — the material-need aggregation algorithm
/// itself is a future Planner-screen feature, not built here.
class PlannerRepository {
  PlannerRepository(this._db);

  final UserDatabase _db;

  Future<List<PlannerTarget>> targetsForProfile(String profileId) {
    return (_db.select(_db.plannerTargets)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Inserts a new target, or updates an existing one if [target.id] already
  /// names a live row (callers generate a fresh id via [newId] for new
  /// targets).
  Future<void> upsertTarget(PlannerTargetsCompanion target) {
    final withTimestamp = target.copyWith(updatedAt: Value(DateTime.now().toUtc()));
    return _db.into(_db.plannerTargets).insertOnConflictUpdate(withTimestamp);
  }

  Future<void> softDeleteTarget(String id) {
    return (_db.update(_db.plannerTargets)..where((t) => t.id.equals(id))).write(
      PlannerTargetsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<Map<String, int>> inventoryForProfile(String profileId) async {
    final rows = await (_db.select(
      _db.materialInventory,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();
    return {for (final row in rows) row.materialId: row.count};
  }

  Future<void> setInventoryCount(String profileId, String materialId, int count) async {
    final now = DateTime.now().toUtc();
    final existing = await (_db.select(_db.materialInventory)..where(
      (t) => t.profileId.equals(profileId) & t.materialId.equals(materialId) & t.deletedAt.isNull(),
    )).getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.materialInventory).insert(
        MaterialInventoryCompanion.insert(
          id: newId(),
          profileId: profileId,
          materialId: materialId,
          count: Value(count),
          updatedAt: now,
        ),
      );
    } else {
      await (_db.update(
        _db.materialInventory,
      )..where((t) => t.id.equals(existing.id))).write(
        MaterialInventoryCompanion(count: Value(count), updatedAt: Value(now)),
      );
    }
  }

  Future<DailyTask?> taskForKey(String profileId, String taskKey) {
    return (_db.select(_db.dailyTasks)..where(
      (t) => t.profileId.equals(profileId) & t.taskKey.equals(taskKey) & t.deletedAt.isNull(),
    )).getSingleOrNull();
  }

  /// Gets the live checklist row for `$periodAnchor:$domainId:$tierGroup`,
  /// creating it if this is the first time it's been touched.
  Future<DailyTask> ensureTask(
    String profileId, {
    required DateTime periodAnchor,
    required String domainId,
    required String tierGroup,
  }) async {
    final taskKey = '${periodAnchor.toIso8601String()}:$domainId:$tierGroup';
    final existing = await taskForKey(profileId, taskKey);
    if (existing != null) return existing;

    await _db.into(_db.dailyTasks).insert(
      DailyTasksCompanion.insert(
        id: newId(),
        profileId: profileId,
        taskKey: taskKey,
        periodAnchor: periodAnchor,
        domainId: domainId,
        tierGroup: tierGroup,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return (await taskForKey(profileId, taskKey))!;
  }

  Future<void> setChecked(String id, bool checked) {
    return (_db.update(_db.dailyTasks)..where((t) => t.id.equals(id))).write(
      DailyTasksCompanion(checked: Value(checked), updatedAt: Value(DateTime.now().toUtc())),
    );
  }

  Future<void> incrementRunsDone(String id, {int by = 1}) async {
    final task = await (_db.select(
      _db.dailyTasks,
    )..where((t) => t.id.equals(id))).getSingle();
    await (_db.update(_db.dailyTasks)..where((t) => t.id.equals(id))).write(
      DailyTasksCompanion(
        runsDone: Value(task.runsDone + by),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
