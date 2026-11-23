import 'package:drift/drift.dart';

import '../../../../core/database/tables/profiles_table.dart';

/// One account's primogem balance anchor.
///
/// Nothing exposes a live primogem balance — not HoYoLab, not the game — so
/// the balance is stored the same way resin is: an anchor plus everything that
/// has happened since, never a counter that drifts. The player enters the
/// balance once; income from the Traveler's Diary, manual adjustments and wish
/// spending carry it forward from there.
///
/// [anchorMonthIncomeAtAnchor] is what makes the anchor month safe to count.
/// The diary reports income as a month-to-date total, so without knowing what
/// that total read *at* anchor time, the income already baked into the entered
/// balance would be added a second time.
@TableIndex(name: 'primogem_anchor_profile_unique', columns: {#profileId}, unique: true)
class PrimogemAnchors extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// The balance the player entered, in primogems.
  IntColumn get balance => integer()();

  /// Intertwined and Acquaint Fates held at anchor time. Counted alongside the
  /// balance when working out how many wishes are affordable.
  IntColumn get fates => integer().withDefault(const Constant(0))();

  /// When the balance was entered (UTC).
  DateTimeColumn get anchoredAt => dateTime()();

  /// The anchor's server month, `YYYY-MM`.
  TextColumn get anchorMonth => text()();

  /// The diary's month-to-date income reading at anchor time, or null when the
  /// diary wasn't reachable. See the class doc.
  IntColumn get anchorMonthIncomeAtAnchor => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Primogems *earned* in one month, per account, as the Traveler's Diary
/// reports it.
///
/// Month-to-date totals are deliberate: the diary gives one cheap number per
/// month, whereas per-day history needs a second paginated endpoint. One row
/// per month is overwritten in place as the month progresses.
@TableIndex.sql(
  'CREATE UNIQUE INDEX primogem_monthly_income_unique ON primogem_monthly_income(profile_id, month) '
  'WHERE deleted_at IS NULL',
)
class PrimogemMonthlyIncome extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// `YYYY-MM`, the diary's own month key.
  TextColumn get month => text()();

  /// Primogems earned in that month so far.
  IntColumn get primogems => integer()();

  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A manual correction to the balance — append-only, like `ResinEvents`.
///
/// This is the escape hatch that keeps the feature honest: top-ups, spending
/// on anything other than wishes, and every account whose diary can't be
/// reached all land here rather than forcing the player to re-anchor.
class PrimogemAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Signed: positive for primogems gained, negative for spent.
  IntColumn get delta => integer()();

  /// Optional free-text note ("bought Welkin", "spent on resin").
  TextColumn get note => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
