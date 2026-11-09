import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/profile_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';

void main() {
  test('profileList orders by creation and excludes soft-deleted profiles', () async {
    final container = ProviderContainer(
      overrides: [userDatabaseProvider.overrideWithValue(UserDatabase(NativeDatabase.memory()))],
    );
    addTearDown(container.dispose);

    final repository = container.read(profileRepositoryProvider);
    final a = await repository.createProfile(displayName: 'A', server: 'asia');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await repository.createProfile(displayName: 'B', server: 'asia');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final c = await repository.createProfile(displayName: 'C', server: 'asia');
    await repository.deleteProfile(b.id);

    final list = await container.read(profileListProvider.future);
    expect(list.map((p) => p.id), [a.id, c.id]);
    expect(list.map((p) => p.displayName), ['A', 'C']);
  });
}
