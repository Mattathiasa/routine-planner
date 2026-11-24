import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/user_database.dart';

/// Exports/imports a JSON snapshot of one profile's core mutable state.
/// Deliberately excludes `ResinEvents` (an append-only history log, not
/// needed to reconstruct current state) and `DailyTasks` (day-scoped,
/// regenerates naturally) — a stated scope cut, not an oversight.
///
/// Wish history is included, and is the one part of this that can't be
/// recovered any other way: upstream keeps about six months, so a wish from
/// last year exists only in this file. `ProfileOrder` is excluded for the
/// opposite reason — a position in a list of accounts means nothing in a
/// single-account export.
///
/// Export is always scoped to one profile at a time — whichever one the
/// caller passes — with no UI to export every profile at once. A
/// deliberate v1 limitation, same as the HoYoLab credential being global
/// rather than per-profile.
///
/// Kept free of any `path_provider`/file IO so it's testable under plain
/// `flutter test` — the presentation layer resolves the file path and
/// passes a plain JSON string in and out.
class BackupService {
  BackupService(this._db);

  final UserDatabase _db;

  static const formatVersion = 2;

  /// Versions this app can read. A v1 file predates wish and primogem
  /// tracking; its missing tables simply import as empty.
  static const supportedFormatVersions = {1, 2};

  Future<String> exportBackupJson(String profileId) async {
    final profile = await (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(profileId) & t.deletedAt.isNull())).getSingle();

    final settings =
        await (_db.select(_db.settings)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final alerts =
        await (_db.select(_db.resinAlertThresholds)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final resinState =
        await (_db.select(_db.resinStateTable)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final resinStateIds = resinState.map((row) => row.id).toSet();
    final transientBatches = resinStateIds.isEmpty
        ? <TransientResinBatchRow>[]
        : await (_db.select(_db.transientResinBatches)..where(
                (t) =>
                    t.resinStateId.isIn(resinStateIds) & t.deletedAt.isNull(),
              ))
              .get();

    final targets =
        await (_db.select(_db.plannerTargets)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final inventory =
        await (_db.select(_db.materialInventory)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final wishPulls =
        await (_db.select(_db.wishPulls)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final wishImportState =
        await (_db.select(_db.wishImportState)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final primogemAnchors =
        await (_db.select(_db.primogemAnchors)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final primogemIncome =
        await (_db.select(_db.primogemMonthlyIncome)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final primogemAdjustments =
        await (_db.select(_db.primogemAdjustments)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();

    final payload = {
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': {
        'profiles': [profile.toJson()],
        'settings': [for (final row in settings) row.toJson()],
        'resinAlertThresholds': [for (final row in alerts) row.toJson()],
        'resinState': [for (final row in resinState) row.toJson()],
        'transientResinBatches': [
          for (final row in transientBatches) row.toJson(),
        ],
        'plannerTargets': [for (final row in targets) row.toJson()],
        'materialInventory': [for (final row in inventory) row.toJson()],
        'wishPulls': [for (final row in wishPulls) row.toJson()],
        'wishImportState': [for (final row in wishImportState) row.toJson()],
        'primogemAnchors': [for (final row in primogemAnchors) row.toJson()],
        'primogemMonthlyIncome': [
          for (final row in primogemIncome) row.toJson(),
        ],
        'primogemAdjustments': [
          for (final row in primogemAdjustments) row.toJson(),
        ],
      },
    };
    return jsonEncode(payload);
  }

  /// Full replace, not a merge, but scoped to the imported profile's own
  /// `profileId` — every live row belonging to that profile across the 7
  /// exported tables is deleted first, then the backup's rows are
  /// inserted. Other profiles are untouched. Returns the imported
  /// profile's id so the caller can select it.
  Future<String> importBackupJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['formatVersion'];
    if (!supportedFormatVersions.contains(version)) {
      throw FormatException('Unsupported backup format version: $version');
    }
    final tables = data['tables'] as Map<String, dynamic>;

    /// A table absent from the file imports as empty, which is what lets a
    /// v1 backup — written before wishes and primogems existed — still
    /// restore cleanly.
    List<Map<String, dynamic>> rowsOf(String key) {
      final rows = tables[key];
      if (rows is! List) return const [];
      return rows.cast<Map<String, dynamic>>();
    }

    final profileId = rowsOf('profiles').single['id'] as String;

    await _db.transaction(() async {
      final resinStateIds =
          await (_db.selectOnly(_db.resinStateTable)
                ..addColumns([_db.resinStateTable.id])
                ..where(_db.resinStateTable.profileId.equals(profileId)))
              .map((row) => row.read(_db.resinStateTable.id)!)
              .get();

      if (resinStateIds.isNotEmpty) {
        await (_db.delete(
          _db.transientResinBatches,
        )..where((t) => t.resinStateId.isIn(resinStateIds))).go();
      }
      await (_db.delete(
        _db.resinStateTable,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.resinAlertThresholds,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.materialInventory,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.plannerTargets,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.wishPulls,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.wishImportState,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.primogemAnchors,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.primogemMonthlyIncome,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.primogemAdjustments,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.settings,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.profiles,
      )..where((t) => t.id.equals(profileId))).go();

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
            .insertOnConflictUpdate(
              ResinAlertThreshold.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('resinState')) {
        await _db
            .into(_db.resinStateTable)
            .insertOnConflictUpdate(
              ResinStateTableData.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('transientResinBatches')) {
        await _db
            .into(_db.transientResinBatches)
            .insertOnConflictUpdate(
              TransientResinBatchRow.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('plannerTargets')) {
        await _db
            .into(_db.plannerTargets)
            .insertOnConflictUpdate(
              PlannerTarget.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('materialInventory')) {
        await _db
            .into(_db.materialInventory)
            .insertOnConflictUpdate(
              MaterialInventoryData.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('wishPulls')) {
        await _db
            .into(_db.wishPulls)
            .insertOnConflictUpdate(
              WishPullRow.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('wishImportState')) {
        await _db
            .into(_db.wishImportState)
            .insertOnConflictUpdate(
              WishImportStateData.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('primogemAnchors')) {
        await _db
            .into(_db.primogemAnchors)
            .insertOnConflictUpdate(
              PrimogemAnchor.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('primogemMonthlyIncome')) {
        await _db
            .into(_db.primogemMonthlyIncome)
            .insertOnConflictUpdate(
              PrimogemMonthlyIncomeData.fromJson(json).toCompanion(false),
            );
      }
      for (final json in rowsOf('primogemAdjustments')) {
        await _db
            .into(_db.primogemAdjustments)
            .insertOnConflictUpdate(
              PrimogemAdjustment.fromJson(json).toCompanion(false),
            );
      }
    });

    return profileId;
  }
}
