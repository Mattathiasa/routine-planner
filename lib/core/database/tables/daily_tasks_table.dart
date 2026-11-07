import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// A daily (or weekly-capped) checklist row. `taskKey` follows the
/// architecture doc's literal format `serverDate:domain:tierGroup`, with
/// `periodAnchor` holding that date — today's server date for daily
/// domains, or this week's Monday server date for weekly-capped ones (e.g.
/// "Weekly bosses") so the same key format covers both reset cadences.
@TableIndex.sql(
  'CREATE UNIQUE INDEX daily_tasks_unique ON daily_tasks(profile_id, task_key) '
  'WHERE deleted_at IS NULL',
)
class DailyTasks extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// `'$periodAnchorIso:$domainId:$tierGroup'`.
  TextColumn get taskKey => text()();

  DateTimeColumn get periodAnchor => dateTime()();

  /// Catalog `domains.id`. Decomposed (not parsed back out of [taskKey])
  /// for querying.
  TextColumn get domainId => text()();
  TextColumn get tierGroup => text()();

  /// Manual checkbox, independent of [runsDone].
  BoolColumn get checked => boolean().withDefault(const Constant(false))();

  /// Incremented only by "+1 run" (which also calls `ResinEngine.spend`),
  /// so the checklist and the resin tracker never disagree.
  IntColumn get runsDone => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
