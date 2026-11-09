import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/resin/data/tables/resin_tables.dart';
import 'ids.dart';
import 'tables/app_state_table.dart';
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
    ResinStateTable,
    TransientResinBatches,
    ResinEvents,
    AppState,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'user'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(profiles, profiles.createdAt);
        await m.createTable(appState);
        // Whichever profile already exists becomes the implicitly selected
        // one, so upgrading users see no change at all. Safe to assume at
        // most one live profile here specifically — no pre-v2 code path
        // could ever have created a second one.
        final existing = await (select(
          profiles,
        )..where((t) => t.deletedAt.isNull())).getSingleOrNull();
        await into(appState).insert(
          AppStateCompanion.insert(
            id: appStateSingletonId,
            selectedProfileId: Value(existing?.id),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
    },
  );
}
