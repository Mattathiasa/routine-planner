import 'package:drift/drift.dart';

import '../../../core/database/ids.dart';
import '../../../core/database/user_database.dart';

/// Reads and writes one account's primogem anchor, diary income and manual
/// adjustments. Pure persistence — the balance arithmetic lives in
/// `primogem_ledger.dart`, and the diary call in the refresh service.
class PrimogemRepository {
  PrimogemRepository(this._db);

  final UserDatabase _db;

  Future<PrimogemAnchor?> anchorFor(String profileId) {
    return (_db.select(_db.primogemAnchors)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Replaces this account's anchor in place — one per account, so entering a
  /// balance again re-anchors rather than stacking.
  ///
  /// [monthIncomeAtAnchor] is the diary's month-to-date reading at this
  /// moment, or null when the diary wasn't reachable. Without it the ledger
  /// can't tell which part of the anchor month's income the player had
  /// already counted, so it conservatively credits none of it.
  Future<void> setAnchor(
    String profileId, {
    required int balance,
    required int fates,
    required DateTime anchoredAt,
    required String anchorMonth,
    required int? monthIncomeAtAnchor,
  }) async {
    final existing = await anchorFor(profileId);
    await _db
        .into(_db.primogemAnchors)
        .insertOnConflictUpdate(
          PrimogemAnchorsCompanion.insert(
            id: existing?.id ?? newId(),
            profileId: profileId,
            balance: balance,
            fates: Value(fates),
            anchoredAt: anchoredAt,
            anchorMonth: anchorMonth,
            anchorMonthIncomeAtAnchor: Value(monthIncomeAtAnchor),
            updatedAt: anchoredAt,
          ),
        );
  }

  /// Stores the diary's month-to-date income for one month, overwriting that
  /// month's row as it grows.
  Future<void> saveMonthlyIncome(
    String profileId, {
    required String month,
    required int primogems,
    required DateTime fetchedAt,
  }) async {
    final existing = await _monthRow(profileId, month);
    await _db
        .into(_db.primogemMonthlyIncome)
        .insertOnConflictUpdate(
          PrimogemMonthlyIncomeCompanion.insert(
            id: existing?.id ?? newId(),
            profileId: profileId,
            month: month,
            primogems: primogems,
            fetchedAt: fetchedAt,
            updatedAt: fetchedAt,
          ),
        );
  }

  /// Month key (`YYYY-MM`) to primogems earned, for the ledger to sum.
  Future<Map<String, int>> monthlyIncomeFor(String profileId) async {
    final rows =
        await (_db.select(_db.primogemMonthlyIncome)..where(
              (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
            ))
            .get();
    return {for (final row in rows) row.month: row.primogems};
  }

  /// When this account's income was last fetched, across every month row.
  Future<DateTime?> incomeLastFetchedAt(String profileId) async {
    final rows =
        await (_db.select(_db.primogemMonthlyIncome)
              ..where(
                (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.fetchedAt),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.single.fetchedAt;
  }

  /// Appends a manual correction. Append-only like `ResinEvents`, so the
  /// history of corrections survives and an undo is a compensating row.
  Future<void> addAdjustment(
    String profileId, {
    required int delta,
    String? note,
    required DateTime occurredAt,
  }) async {
    await _db
        .into(_db.primogemAdjustments)
        .insert(
          PrimogemAdjustmentsCompanion.insert(
            id: newId(),
            profileId: profileId,
            delta: delta,
            note: Value(note),
            occurredAt: occurredAt,
            updatedAt: occurredAt,
          ),
        );
  }

  /// This account's adjustments, newest first.
  Future<List<PrimogemAdjustment>> adjustmentsFor(String profileId) {
    return (_db.select(_db.primogemAdjustments)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .get();
  }

  /// Soft-deletes one adjustment — the undo path for a mistyped correction.
  Future<void> removeAdjustment(String id, {required DateTime now}) async {
    await (_db.update(
      _db.primogemAdjustments,
    )..where((t) => t.id.equals(id))).write(
      PrimogemAdjustmentsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Drops the whole ledger for one account, used when a backup is imported
  /// over it.
  Future<void> clearLedger(String profileId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.primogemAnchors,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.primogemMonthlyIncome,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.primogemAdjustments,
      )..where((t) => t.profileId.equals(profileId))).go();
    });
  }

  Future<PrimogemMonthlyIncomeData?> _monthRow(
    String profileId,
    String month,
  ) {
    return (_db.select(_db.primogemMonthlyIncome)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.month.equals(month) &
              t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }
}
