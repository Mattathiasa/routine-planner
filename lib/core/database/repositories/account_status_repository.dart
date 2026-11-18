import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Reads and writes the per-account live snapshot and the manual
/// commission counter. Pure persistence — staleness decisions and HoYoLab
/// calls live in the refresh service.
class AccountStatusRepository {
  AccountStatusRepository(this._db);

  final UserDatabase _db;

  Future<AccountSnapshot?> snapshotFor(String profileId) {
    return (_db.select(_db.accountSnapshots)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<AccountSnapshot>> allSnapshots() {
    return (_db.select(
      _db.accountSnapshots,
    )..where((t) => t.deletedAt.isNull())).get();
  }

  /// Replaces this account's snapshot in place — one row per account, so a
  /// fetch overwrites rather than accumulating history.
  Future<void> saveSnapshot(
    String profileId, {
    required DateTime fetchedAt,
    int? finishedTaskNum,
    int? totalTaskNum,
    bool? extraTaskRewardReceived,
    int? remainResinDiscountNum,
    int? resinDiscountNumLimit,
    int? currentExpeditionNum,
    int? maxExpeditionNum,
    int? finishedExpeditionNum,
    int? currentHomeCoin,
    int? maxHomeCoin,
    int? homeCoinRecoverySeconds,
  }) async {
    final existing = await snapshotFor(profileId);
    final companion = AccountSnapshotsCompanion.insert(
      id: existing?.id ?? newId(),
      profileId: profileId,
      fetchedAt: fetchedAt,
      finishedTaskNum: Value(finishedTaskNum),
      totalTaskNum: Value(totalTaskNum),
      extraTaskRewardReceived: Value(extraTaskRewardReceived),
      remainResinDiscountNum: Value(remainResinDiscountNum),
      resinDiscountNumLimit: Value(resinDiscountNumLimit),
      currentExpeditionNum: Value(currentExpeditionNum),
      maxExpeditionNum: Value(maxExpeditionNum),
      finishedExpeditionNum: Value(finishedExpeditionNum),
      currentHomeCoin: Value(currentHomeCoin),
      maxHomeCoin: Value(maxHomeCoin),
      homeCoinRecoverySeconds: Value(homeCoinRecoverySeconds),
      updatedAt: fetchedAt,
    );
    await _db.into(_db.accountSnapshots).insertOnConflictUpdate(companion);
  }

  /// Forgets an account's cached status — used when its HoYoLab login is
  /// disconnected, so stale live numbers can't outlive the connection.
  Future<void> clearSnapshot(String profileId) {
    return (_db.delete(
      _db.accountSnapshots,
    )..where((t) => t.profileId.equals(profileId))).go();
  }

  /// The manual commission row for one account and server day, created on
  /// first use — same lazy get-or-insert as `PlannerRepository.ensureTask`.
  Future<DailyCommission> ensureCommissionRow(
    String profileId, {
    required DateTime periodAnchor,
    required DateTime now,
  }) async {
    final existing = await _commissionRow(profileId, periodAnchor);
    if (existing != null) return existing;

    await _db
        .into(_db.dailyCommissions)
        .insert(
          DailyCommissionsCompanion.insert(
            id: newId(),
            profileId: profileId,
            periodAnchor: periodAnchor,
            updatedAt: now,
          ),
        );
    return (await _commissionRow(profileId, periodAnchor))!;
  }

  Future<void> setCommissionProgress(
    String id, {
    required int completed,
    required bool bonusClaimed,
    required DateTime now,
  }) {
    return (_db.update(_db.dailyCommissions)..where((t) => t.id.equals(id))).write(
      DailyCommissionsCompanion(
        completed: Value(completed),
        bonusClaimed: Value(bonusClaimed),
        updatedAt: Value(now),
      ),
    );
  }

  Future<DailyCommission?> _commissionRow(String profileId, DateTime periodAnchor) {
    return (_db.select(_db.dailyCommissions)..where(
      (t) =>
          t.profileId.equals(profileId) &
          t.periodAnchor.equals(periodAnchor) &
          t.deletedAt.isNull(),
    )).getSingleOrNull();
  }
}
