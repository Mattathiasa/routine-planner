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

  test('getActiveProfile creates exactly one profile on first call', () async {
    final created = await repository.getActiveProfile();
    expect(created.server, 'asia');

    final again = await repository.getActiveProfile();
    expect(again.id, created.id);

    final all = await db.select(db.profiles).get();
    expect(all, hasLength(1));
  });

  test('getActiveProfile does not crash once a second profile exists', () async {
    final first = await repository.getActiveProfile();
    await repository.createProfile(server: 'europe');

    final active = await repository.getActiveProfile();
    expect(active.id, first.id);
  });

  test('updateServer changes the stored server', () async {
    final profile = await repository.getActiveProfile();
    await repository.updateServer(profile.id, 'europe');

    final updated = await repository.getProfile(profile.id);
    expect(updated!.server, 'europe');
  });

  test('getProfile returns null for a soft-deleted profile', () async {
    final profile = await repository.getActiveProfile();
    await (db.update(db.profiles)..where((t) => t.id.equals(profile.id))).write(
      ProfilesCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );

    expect(await repository.getProfile(profile.id), isNull);
  });

  test('createProfile sets displayName default and respects an explicit one', () async {
    final defaulted = await repository.createProfile(server: 'asia');
    expect(defaulted.displayName, 'Player');

    final named = await repository.createProfile(displayName: 'Alt', server: 'europe');
    expect(named.displayName, 'Alt');
  });

  test('renameProfile updates displayName', () async {
    final profile = await repository.createProfile(server: 'asia');
    await repository.renameProfile(profile.id, 'New name');

    final updated = await repository.getProfile(profile.id);
    expect(updated!.displayName, 'New name');
  });

  test('listProfiles excludes soft-deleted and orders by createdAt', () async {
    final a = await repository.createProfile(displayName: 'A', server: 'asia');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await repository.createProfile(displayName: 'B', server: 'asia');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final c = await repository.createProfile(displayName: 'C', server: 'asia');
    await repository.deleteProfile(b.id);

    final listed = await repository.listProfiles();
    expect(listed.map((p) => p.id), [a.id, c.id]);
  });

  test('deleteProfile soft-deletes without touching AppState', () async {
    final profile = await repository.createProfile(server: 'asia');
    await repository.selectProfile(profile.id);
    await repository.deleteProfile(profile.id);

    final state = await (db.select(
      db.appState,
    )..where((t) => t.id.equals('app_state'))).getSingle();
    expect(state.selectedProfileId, profile.id);
  });

  test('getActiveProfile falls back to the oldest remaining profile when the '
      'selected one is deleted, and persists that fallback', () async {
    final a = await repository.createProfile(displayName: 'A', server: 'asia');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await repository.createProfile(displayName: 'B', server: 'asia');
    await repository.selectProfile(b.id);
    await repository.deleteProfile(b.id);

    final active = await repository.getActiveProfile();
    expect(active.id, a.id);

    final state = await (db.select(
      db.appState,
    )..where((t) => t.id.equals('app_state'))).getSingle();
    expect(state.selectedProfileId, a.id);
  });

  test('getActiveProfile bootstraps a fresh default when every profile is deleted', () async {
    final only = await repository.createProfile(server: 'asia');
    await repository.selectProfile(only.id);
    await repository.deleteProfile(only.id);

    final active = await repository.getActiveProfile();
    expect(active.id, isNot(only.id));
    expect(active.server, 'asia');
  });
}
