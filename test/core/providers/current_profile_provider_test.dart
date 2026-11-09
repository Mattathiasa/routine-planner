import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';

void main() {
  test('currentProfile creates the default profile once and is stable across reads', () async {
    final container = ProviderContainer(
      overrides: [userDatabaseProvider.overrideWithValue(UserDatabase(NativeDatabase.memory()))],
    );
    addTearDown(container.dispose);

    final first = await container.read(currentProfileProvider.future);
    expect(first.server, 'asia');

    final second = await container.read(currentProfileProvider.future);
    expect(second.id, first.id);
  });

  test('switching the selected profile and invalidating reflects the switch', () async {
    final container = ProviderContainer(
      overrides: [userDatabaseProvider.overrideWithValue(UserDatabase(NativeDatabase.memory()))],
    );
    addTearDown(container.dispose);

    final first = await container.read(currentProfileProvider.future);
    final repository = container.read(profileRepositoryProvider);
    final second = await repository.createProfile(server: 'europe');

    await repository.selectProfile(second.id);
    container.invalidate(currentProfileProvider);

    final active = await container.read(currentProfileProvider.future);
    expect(active.id, second.id);
    expect(active.id, isNot(first.id));
  });

  test('deleting the currently-selected profile then re-reading falls back correctly', () async {
    final container = ProviderContainer(
      overrides: [userDatabaseProvider.overrideWithValue(UserDatabase(NativeDatabase.memory()))],
    );
    addTearDown(container.dispose);

    final first = await container.read(currentProfileProvider.future);
    final repository = container.read(profileRepositoryProvider);
    final second = await repository.createProfile(server: 'europe');
    await repository.selectProfile(second.id);
    container.invalidate(currentProfileProvider);
    await container.read(currentProfileProvider.future);

    await repository.deleteProfile(second.id);
    container.invalidate(currentProfileProvider);

    final active = await container.read(currentProfileProvider.future);
    expect(active.id, first.id);
  });
}
