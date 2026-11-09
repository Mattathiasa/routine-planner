import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('createAll() builds every declared table', () async {
    await db.select(db.profiles).get();
    await db.select(db.settings).get();
    await db.select(db.resinAlertThresholds).get();
    await db.select(db.plannerTargets).get();
    await db.select(db.materialInventory).get();
    await db.select(db.dailyTasks).get();
    await db.select(db.appState).get();
  });

  test('createdAt round-trips on a fresh profile insert', () async {
    final now = DateTime.utc(2026, 1, 1);
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(id: 'p1', server: 'asia', createdAt: Value(now), updatedAt: now),
        );
    final profile = await (db.select(db.profiles)..where((t) => t.id.equals('p1'))).getSingle();
    expect(profile.createdAt, now);
  });
}
