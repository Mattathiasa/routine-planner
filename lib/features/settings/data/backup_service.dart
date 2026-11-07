import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/user_database.dart';

/// Exports/imports a JSON snapshot of one profile's core mutable state.
/// Deliberately excludes `ResinEvents` (an append-only history log, not
/// needed to reconstruct current state) and `DailyTasks` (day-scoped,
/// regenerates naturally) — a stated scope cut, not an oversight.
///
/// Kept free of any `path_provider`/file IO so it's testable under plain
/// `flutter test` — the presentation layer resolves the file path and
/// passes a plain JSON string in and out.
class BackupService {
  BackupService(this._db);

  final UserDatabase _db;

  static const formatVersion = 1;

  Future<String> exportBackupJson(String profileId) async {
    final profile = await (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(profileId) & t.deletedAt.isNull())).getSingle();

    final settings = await (_db.select(
      _db.settings,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();

    final alerts = await (_db.select(
      _db.resinAlertThresholds,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();

    final resinState = await (_db.select(
      _db.resinStateTable,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();

    final resinStateIds = resinState.map((row) => row.id).toSet();
    final transientBatches = resinStateIds.isEmpty
        ? <TransientResinBatchRow>[]
        : await (_db.select(_db.transientResinBatches)..where(
            (t) => t.resinStateId.isIn(resinStateIds) & t.deletedAt.isNull(),
          )).get();

    final targets = await (_db.select(
      _db.plannerTargets,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();

    final inventory = await (_db.select(
      _db.materialInventory,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).get();

    final payload = {
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': {
        'profiles': [profile.toJson()],
        'settings': [for (final row in settings) row.toJson()],
        'resinAlertThresholds': [for (final row in alerts) row.toJson()],
        'resinState': [for (final row in resinState) row.toJson()],
        'transientResinBatches': [for (final row in transientBatches) row.toJson()],
        'plannerTargets': [for (final row in targets) row.toJson()],
        'materialInventory': [for (final row in inventory) row.toJson()],
      },
    };
    return jsonEncode(payload);
  }

  /// Full replace, not a merge: every live row in the 7 exported tables is
  /// deleted first, then the backup's rows are inserted. A merge would
  /// risk two live `Profiles` rows if the backup's profile id differs from
  /// the current install's — `ProfileRepository.getOrCreateDefaultProfile`
  /// assumes exactly one live profile and throws otherwise. Full replace
  /// is also simply the right behavior for a v1 single-profile app.
  Future<void> importBackupJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['formatVersion'];
    if (version != formatVersion) {
      throw FormatException('Unsupported backup format version: $version');
    }
    final tables = data['tables'] as Map<String, dynamic>;

    List<Map<String, dynamic>> rowsOf(String key) {
      return (tables[key] as List).cast<Map<String, dynamic>>();
    }

    await _db.transaction(() async {
      await _db.delete(_db.transientResinBatches).go();
      await _db.delete(_db.resinStateTable).go();
      await _db.delete(_db.resinAlertThresholds).go();
      await _db.delete(_db.materialInventory).go();
      await _db.delete(_db.plannerTargets).go();
      await _db.delete(_db.settings).go();
      await _db.delete(_db.profiles).go();

      for (final json in rowsOf('profiles')) {
        await _db
            .into(_db.profiles)
            .insertOnConflictUpdate(Profile.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('settings')) {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(Setting.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('resinAlertThresholds')) {
        await _db
            .into(_db.resinAlertThresholds)
            .insertOnConflictUpdate(ResinAlertThreshold.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('resinState')) {
        await _db
            .into(_db.resinStateTable)
            .insertOnConflictUpdate(ResinStateTableData.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('transientResinBatches')) {
        await _db
            .into(_db.transientResinBatches)
            .insertOnConflictUpdate(TransientResinBatchRow.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('plannerTargets')) {
        await _db
            .into(_db.plannerTargets)
            .insertOnConflictUpdate(PlannerTarget.fromJson(json).toCompanion(false));
      }
      for (final json in rowsOf('materialInventory')) {
        await _db
            .into(_db.materialInventory)
            .insertOnConflictUpdate(MaterialInventoryData.fromJson(json).toCompanion(false));
      }
    });
  }
}
