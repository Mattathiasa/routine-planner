import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/ids.dart';
import 'package:routine_planner/core/database/user_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;
import '../../generated_migrations/schema_v2.dart' as v2;
import '../../generated_migrations/schema_v3.dart' as v3;

void main() {
  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrating 1 -> 2 produces exactly the schema a fresh v2 database has', () async {
    final connection = await verifier.startAt(1);
    final db = UserDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('migrating 1 -> 2 preserves an existing profile and selects it', () async {
    final schema = await verifier.schemaAt(1);

    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.profiles)
        .insert(
          v1.ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: const Value('Player'),
            server: 'asia',
            updatedAt: DateTime.utc(2026, 1, 1).toIso8601String(),
          ),
        );
    await oldDb.close();

    final dbForMigration = UserDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 2);
    await dbForMigration.close();

    final checkDb = v2.DatabaseAtV2(schema.newConnection());
    final profile = await checkDb.select(checkDb.profiles).getSingle();
    expect(profile.id, 'profile-1');
    expect(profile.displayName, 'Player');
    expect(profile.server, 'asia');
    // ProfilesData here is the generated v2 snapshot class, which
    // represents dates as the raw stored TEXT (store_date_time_values_as_text
    // is on), not a parsed DateTime — a non-empty value is enough to prove
    // the backfill ran.
    expect(profile.createdAt, isNotEmpty);

    final appState = await checkDb.select(checkDb.appState).getSingle();
    expect(appState.id, appStateSingletonId);
    expect(appState.selectedProfileId, 'profile-1');
    await checkDb.close();
  });

  test('migrating 1 -> 2 with no existing profile creates AppState with no selection', () async {
    final schema = await verifier.schemaAt(1);

    final dbForMigration = UserDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 2);
    await dbForMigration.close();

    final checkDb = v2.DatabaseAtV2(schema.newConnection());
    final appState = await checkDb.select(checkDb.appState).getSingle();
    expect(appState.id, appStateSingletonId);
    expect(appState.selectedProfileId, null);
    await checkDb.close();
  });

  test('migrating 2 -> 3 produces exactly the schema a fresh v3 database has', () async {
    final connection = await verifier.startAt(2);
    final db = UserDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  // The long jump matters: a user who skipped the v2 release upgrades
  // straight from v1, running both branches of onUpgrade back to back.
  test('migrating 1 -> 3 in one step produces the fresh v3 schema', () async {
    final connection = await verifier.startAt(1);
    final db = UserDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('migrating 2 -> 3 preserves existing rows and defaults the new settings flag', () async {
    final schema = await verifier.schemaAt(2);

    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb
        .into(oldDb.profiles)
        .insert(
          v2.ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: const Value('Main'),
            server: 'europe',
            createdAt: Value(DateTime.utc(2026, 1, 1).toIso8601String()),
            updatedAt: DateTime.utc(2026, 1, 1).toIso8601String(),
          ),
        );
    await oldDb
        .into(oldDb.settings)
        .insert(
          v2.SettingsCompanion.insert(
            id: 'settings-1',
            profileId: 'profile-1',
            updatedAt: DateTime.utc(2026, 1, 1).toIso8601String(),
          ),
        );
    await oldDb.close();

    final dbForMigration = UserDatabase(schema.newConnection());
    await verifier.migrateAndValidate(dbForMigration, 3);
    await dbForMigration.close();

    final checkDb = v3.DatabaseAtV3(schema.newConnection());
    final profile = await checkDb.select(checkDb.profiles).getSingle();
    expect(profile.displayName, 'Main');
    expect(profile.server, 'europe');

    final settings = await checkDb.select(checkDb.settings).getSingle();
    expect(settings.profileId, 'profile-1');
    // Like the v2 createdAt check above, the generated snapshot class
    // exposes the raw stored value — SQLite has no boolean type, so the
    // column's `true` default reads back as 1.
    expect(settings.commissionReminderEnabled, 1);

    // Both new tables exist and start empty.
    expect(await checkDb.select(checkDb.accountSnapshots).get(), isEmpty);
    expect(await checkDb.select(checkDb.dailyCommissions).get(), isEmpty);
    await checkDb.close();
  });
}
