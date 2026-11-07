import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// An arbitrary per-profile resin-value alert (the mockup's "Add an alert"
/// implies an open set, not fixed 160/200 flags).
@TableIndex.sql(
  'CREATE UNIQUE INDEX resin_alert_unique ON resin_alert_thresholds(profile_id, threshold) '
  'WHERE deleted_at IS NULL',
)
class ResinAlertThresholds extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  IntColumn get threshold => integer()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
