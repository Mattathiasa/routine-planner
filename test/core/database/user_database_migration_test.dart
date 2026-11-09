import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/ids.dart';
import 'package:routine_planner/core/database/user_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;
import '../../generated_migrations/schema_v2.dart' as v2;

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
}
