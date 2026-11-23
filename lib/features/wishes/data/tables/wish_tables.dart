import 'package:drift/drift.dart';

import '../../../../core/database/tables/profiles_table.dart';

/// One imported wish, scoped to the account that pulled it.
///
/// **The primary key is the upstream snowflake id, not a generated uuid** —
/// the one deliberate break from the user-table convention. That id is
/// monotonic and stable, so `insertOnConflictUpdate` makes re-importing an
/// overlapping window idempotent for free. A uuid key would need a separate
/// uniqueness check on every row of every re-import.
///
/// Rows are append-only in practice: the game never edits a past wish.
///
/// Named `WishPullRow` so the generated data class doesn't collide with the
/// domain's `WishPull`, the same way `ResinEvents` yields `ResinEventRow`.
@DataClassName('WishPullRow')
@TableIndex(name: 'wish_pulls_profile_banner', columns: {#profileId, #bannerType})
@TableIndex(name: 'wish_pulls_profile_pulled_at', columns: {#profileId, #pulledAt})
class WishPulls extends Table {
  /// The upstream snowflake id. See the class doc.
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// `WishBanner.gachaType` — the canonical code, so the character banner's
  /// second code (400) is already folded into 301 by the time it lands here.
  IntColumn get bannerType => integer()();

  TextColumn get itemName => text()();

  /// `WishItemKind.name`.
  TextColumn get itemKind => text()();

  IntColumn get rarity => integer()();

  /// When the wish was made, in UTC (converted from the account's server
  /// time on parse).
  DateTimeColumn get pulledAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-account, per-banner import bookkeeping — and the manual fallback for
/// accounts that can't produce a wish-history link.
///
/// [lastImportedPullId] is the high-water mark: the newest id already stored,
/// so the next import can stop paging as soon as it reaches it instead of
/// walking six months of history again.
///
/// The manual fields are the alternative, not a supplement. An account with
/// imported history reads its pity from the history; an account without one
/// reads it from whatever the player typed here. The split mirrors the
/// live-or-manual commission tracker.
@TableIndex.sql(
  'CREATE UNIQUE INDEX wish_import_state_unique ON wish_import_state(profile_id, banner_type) '
  'WHERE deleted_at IS NULL',
)
class WishImportState extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// `WishBanner.gachaType`.
  IntColumn get bannerType => integer()();

  /// Newest pull id already stored for this banner, or null before the first
  /// successful import.
  TextColumn get lastImportedPullId => text().nullable()();
  DateTimeColumn get lastImportedAt => dateTime().nullable()();

  /// Manually entered pity, for accounts with no imported history.
  IntColumn get manualPityFive => integer().nullable()();
  IntColumn get manualPityFour => integer().nullable()();
  BoolColumn get manualGuaranteed => boolean().nullable()();
  DateTimeColumn get manualUpdatedAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
