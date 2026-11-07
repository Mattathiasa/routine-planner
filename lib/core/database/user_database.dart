import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/daily_tasks_table.dart';
import 'tables/planner_tables.dart';
import 'tables/profiles_table.dart';
import 'tables/resin_alert_tables.dart';
import 'tables/settings_table.dart';

part 'user_database.g.dart';

/// The user's own mutable data — never overwritten, migrated in place.
@DriftDatabase(
  tables: [
    Profiles,
    Settings,
    ResinAlertThresholds,
    PlannerTargets,
    MaterialInventory,
    DailyTasks,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'user'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());
}
