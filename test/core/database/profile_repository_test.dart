import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';

void main() {
  late UserDatabase db;
  late ProfileRepository repository;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    repository = ProfileRepository(db);
  });

  tearDown(() => db.close());

  test('getOrCreateDefaultProfile creates exactly one profile on first call', () async {
    final created = await repository.getOrCreateDefaultProfile();
    expect(created.server, 'asia');

    final again = await repository.getOrCreateDefaultProfile();
    expect(again.id, created.id);

    final all = await db.select(db.profiles).get();
    expect(all, hasLength(1));
  });

  test('updateServer changes the stored server', () async {
    final profile = await repository.getOrCreateDefaultProfile();
    await repository.updateServer(profile.id, 'europe');

    final updated = await repository.getProfile(profile.id);
    expect(updated!.server, 'europe');
  });

  test('getProfile returns null for a soft-deleted profile', () async {
    final profile = await repository.getOrCreateDefaultProfile();
    await (db.update(db.profiles)..where((t) => t.id.equals(profile.id))).write(
      ProfilesCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );

    expect(await repository.getProfile(profile.id), isNull);
  });
}
