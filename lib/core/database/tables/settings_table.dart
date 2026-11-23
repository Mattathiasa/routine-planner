import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// Per-profile app preferences. One wide typed row per profile — the field
/// set is small and fixed, unlike the catalog's open-ended `game_rules`.
@TableIndex(
  name: 'settings_profile_unique',
  columns: {#profileId},
  unique: true,
)
class Settings extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Used for run estimates in v2; stored now even though unused until then.
  IntColumn get worldLevel => integer().withDefault(const Constant(0))();

  /// Skip inventory and show full material totals.
  BoolColumn get totalsOnlyMode =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get transientExpiryAlertEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Remind this account before server reset when its daily commissions
  /// are unfinished.
  BoolColumn get commissionReminderEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Whether this account has an active Blessing of the Welkin Moon, which
  /// the primogem forecast adds to projected daily income. Off by default —
  /// assuming a purchase nobody made would overstate the forecast.
  BoolColumn get welkinActive => boolean().withDefault(const Constant(false))();

  /// Whether this account buys the battle pass each cycle. Same reasoning as
  /// [welkinActive].
  BoolColumn get battlePassActive =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
