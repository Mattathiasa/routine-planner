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
  });
}
