import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/resin/data/tables/resin_tables.dart';
import 'ids.dart';
import 'tables/account_status_tables.dart';
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
    AccountSnapshots,
    DailyCommissions,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'user',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Each branch is bounded by `to` as well as `from`. In production `to`
    // is always schemaVersion, so it changes nothing — but the migration
    // verifier validates intermediate targets (1 -> 2 on a database whose
    // Dart schema is already v3), and an unbounded `from < 3` would run
    // the v3 step during that check and fail it.
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        // Not m.addColumn: SQLite's ALTER TABLE ADD COLUMN rejects a
        // non-constant default like CURRENT_TIMESTAMP outright, even though
        // the same expression is fine as a CREATE TABLE column default.
        // alterTable sidesteps that by rebuilding the table (SQLite's own
        // recommended 12-step procedure) — existing rows get createdAt via
        // the table's own default during the copy, no transformer needed.
        await m.alterTable(
          TableMigration(profiles, newColumns: [profiles.createdAt]),
        );
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
      if (from < 3 && to >= 3) {
        // Per-account live status. Both tables are new and empty, and the
        // settings column has a constant default, so plain addColumn is
        // fine here — unlike the v2 createdAt backfill above.
        await m.createTable(accountSnapshots);
        await m.createTable(dailyCommissions);
        // createTable does not bring a table's declared indexes with it.
        await m.create(accountSnapshotProfileUnique);
        await m.create(dailyCommissionsUnique);
        await m.addColumn(settings, settings.commissionReminderEnabled);
      }
    },
  );
}
