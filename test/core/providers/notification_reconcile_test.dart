import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';

void main() {
  test(
    'notificationReconcile schedules a resin-threshold notification, and re-runs after a mutation',
    () async {
      final catalogDb = await openSeedCatalogDatabaseInMemory();
      final userDb = UserDatabase(NativeDatabase.memory());
      final fakeClock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final fakeScheduler = FakeNotificationScheduler();

      final container = ProviderContainer(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(fakeClock),
          notificationSchedulerProvider.overrideWithValue(fakeScheduler),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(catalogDb.close);
      addTearDown(userDb.close);

      final profileId = (await container.read(currentProfileProvider.future)).id;
      await container.read(settingsRepositoryProvider).addAlertThreshold(profileId, 160);

      // A fresh profile starts full (v=200, n=null) — every threshold is
      // already "met" there and nothing would be scheduled. Spend some
      // resin so v < 160 and a regen timer is running.
      await container.read(resinControllerProvider.notifier).spend(50);
      await container.read(notificationReconcileProvider.future);

      expect(fakeScheduler.lastApplied, hasLength(1));
      expect(fakeScheduler.lastApplied.single.kind, 'resinThreshold');
      final firstScheduledAt = fakeScheduler.lastApplied.single.scheduledAt;

      // Spending again moves the anchor — reconcile re-runs reactively
      // (via the provider graph, no manual call-site) and reflects it.
      await container.read(resinControllerProvider.notifier).spend(20);
      await container.read(notificationReconcileProvider.future);

      expect(fakeScheduler.lastApplied, hasLength(1));
      expect(fakeScheduler.lastApplied.single.scheduledAt, isNot(firstScheduledAt));
    },
  );

  test('a disabled alert is never scheduled', () async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    final fakeClock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    final fakeScheduler = FakeNotificationScheduler();

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(fakeClock),
        notificationSchedulerProvider.overrideWithValue(fakeScheduler),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final profileId = (await container.read(currentProfileProvider.future)).id;
    final settingsRepo = container.read(settingsRepositoryProvider);
    await settingsRepo.addAlertThreshold(profileId, 160);
    final alerts = await settingsRepo.alertsForProfile(profileId);
    await settingsRepo.setAlertEnabled(alerts.single.id, false);

    await container.read(resinControllerProvider.notifier).spend(50);
    await container.read(notificationReconcileProvider.future);

    expect(fakeScheduler.lastApplied, isEmpty);
  });
}
