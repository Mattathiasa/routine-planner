import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';
import 'package:routine_planner/features/resin/data/resin_providers.dart';

void main() {
  test('spend() mutates state, matches ResinEngine, and persists', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fakeClock = FakeClock(DateTime.utc(2026, 1, 1, 12));

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(fakeClock),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(resinControllerProvider.future);
    expect(initial.v, 200); // default: full, at cap

    await container.read(resinControllerProvider.notifier).spend(30);

    final updated = container.read(resinControllerProvider).value;
    expect(updated?.v, 170);

    final profileId = (await container.read(currentProfileProvider.future)).id;
    final reloaded = await container.read(resinRepositoryProvider).loadResinState(profileId);
    expect(reloaded.v, 170);
  });
}
