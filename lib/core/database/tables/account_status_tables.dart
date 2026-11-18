import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// The last live `dailyNote` fetch for one account — a cache, so the
/// all-accounts strip renders instantly and still shows something useful
/// offline, with [fetchedAt] driving the "last updated" stamp and the
/// staleness check that throttles refreshes.
///
/// Resin is deliberately absent: live resin keeps flowing through
/// `ResinEngine.sync` into `ResinStateTable`, so manual and synced resin
/// stay one source of truth with working undo and alerts. Only the fields
/// that have no other home live here.
///
/// Every column but [fetchedAt] is nullable, mirroring `HoyolabNotes` —
/// the field names are community-sourced, and a missing one must read as
/// "unknown", not zero.
@TableIndex(name: 'account_snapshot_profile_unique', columns: {#profileId}, unique: true)
class AccountSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// When this snapshot was fetched (UTC).
  DateTimeColumn get fetchedAt => dateTime()();

  IntColumn get finishedTaskNum => integer().nullable()();
  IntColumn get totalTaskNum => integer().nullable()();
  BoolColumn get extraTaskRewardReceived => boolean().nullable()();

  IntColumn get remainResinDiscountNum => integer().nullable()();
  IntColumn get resinDiscountNumLimit => integer().nullable()();

  IntColumn get currentExpeditionNum => integer().nullable()();
  IntColumn get maxExpeditionNum => integer().nullable()();

  /// How many dispatched expeditions have already finished — derived from
  /// the expeditions array rather than storing the whole array, since the
  /// card only ever shows the count.
  IntColumn get finishedExpeditionNum => integer().nullable()();

  IntColumn get currentHomeCoin => integer().nullable()();
  IntColumn get maxHomeCoin => integer().nullable()();
  IntColumn get homeCoinRecoverySeconds => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Manual daily-commission tracking for an account with no HoYoLab login
/// — one row per account per server day, so the feature works offline and
/// every account shows progress.
///
/// Keyed by [periodAnchor] exactly like `DailyTasks`: a new server date
/// means a new row, yesterday's simply stops being read, and no cleanup
/// job is needed. A connected account prefers its live snapshot over this
/// row rather than writing back into it, so a manual count is never
/// silently overwritten by a sync.
@TableIndex.sql(
  'CREATE UNIQUE INDEX daily_commissions_unique ON daily_commissions(profile_id, period_anchor) '
  'WHERE deleted_at IS NULL',
)
class DailyCommissions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The server date this count belongs to (UTC midnight of the server
  /// day, from `ServerClock.serverDateFor`).
  DateTimeColumn get periodAnchor => dateTime()();

  IntColumn get completed => integer().withDefault(const Constant(0))();
  BoolColumn get bonusClaimed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
