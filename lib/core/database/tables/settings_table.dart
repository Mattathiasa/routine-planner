import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// Per-profile app preferences. One wide typed row per profile — the field
/// set is small and fixed, unlike the catalog's open-ended `game_rules`.
@TableIndex(name: 'settings_profile_unique', columns: {#profileId}, unique: true)
class Settings extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Used for run estimates in v2; stored now even though unused until then.
  IntColumn get worldLevel => integer().withDefault(const Constant(0))();

  /// Skip inventory and show full material totals.
  BoolColumn get totalsOnlyMode => boolean().withDefault(const Constant(false))();

  BoolColumn get transientExpiryAlertEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
