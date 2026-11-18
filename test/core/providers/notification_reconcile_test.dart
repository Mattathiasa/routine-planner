import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/providers/repository_providers.dart';
import 'package:routine_planner/core/providers/profile_providers.dart';
import 'package:routine_planner/features/accounts/application/accounts_overview_controller.dart';
import 'package:routine_planner/features/resin/application/resin_controller.dart';

void main() {
  test('notificationReconcile schedules a resin-threshold notification, and re-runs after a mutation', () async {
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
        hoyolabCredentialsStoreProvider.overrideWithValue(
          FakeHoyolabCredentialsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final profileId = (await container.read(currentProfileProvider.future)).id;
    await container
        .read(settingsRepositoryProvider)
        .addAlertThreshold(profileId, 160);

    // A fresh profile starts full (v=200, n=null) — every threshold is
    // already "met" there and nothing would be scheduled. Spend some
    // resin so v < 160 and a regen timer is running.
    await container.read(resinControllerProvider.notifier).spend(50);
    await container.read(notificationReconcileProvider.future);

    // Filtered by kind: a commission reminder is planned alongside the
    // resin alert now, so the resin plan is no longer the only entry.
    var resinPlans = fakeScheduler.lastApplied
        .where((n) => n.kind == 'resinThreshold')
        .toList();
    expect(resinPlans, hasLength(1));
    final firstScheduledAt = resinPlans.single.scheduledAt;

    // Spending again moves the anchor — reconcile re-runs reactively
    // (via the provider graph, no manual call-site) and reflects it.
    await container.read(resinControllerProvider.notifier).spend(20);
    await container.read(notificationReconcileProvider.future);

    resinPlans = fakeScheduler.lastApplied
        .where((n) => n.kind == 'resinThreshold')
        .toList();
    expect(resinPlans, hasLength(1));
    expect(resinPlans.single.scheduledAt, isNot(firstScheduledAt));
  });

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
        hoyolabCredentialsStoreProvider.overrideWithValue(
          FakeHoyolabCredentialsStore(),
        ),
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

    expect(
      fakeScheduler.lastApplied.where((n) => n.kind == 'resinThreshold'),
      isEmpty,
    );
  });

  test('every account is scheduled, not just the selected one', () async {
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
        hoyolabCredentialsStoreProvider.overrideWithValue(
          FakeHoyolabCredentialsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final profileA = (await container.read(currentProfileProvider.future)).id;
    await container
        .read(settingsRepositoryProvider)
        .addAlertThreshold(profileA, 160);
    await container.read(resinControllerProvider.notifier).spend(50);
    await container.read(notificationReconcileProvider.future);
    expect(
      fakeScheduler.lastApplied.where((n) => n.kind == 'resinThreshold'),
      hasLength(1),
    );

    // Give a second account its own alert, then switch away from A.
    final profileRepo = container.read(profileRepositoryProvider);
    final profileB = await profileRepo.createProfile(
      displayName: 'Alt',
      server: 'asia',
    );
    await profileRepo.selectProfile(profileB.id);
    container.invalidate(currentProfileProvider);
    container.invalidate(profileListProvider);
    await container
        .read(settingsRepositoryProvider)
        .addAlertThreshold(profileB.id, 160);
    await container.read(resinControllerProvider.notifier).spend(50);
    await container.read(notificationReconcileProvider.future);

    // Both accounts now hold alarms: A's survived the switch instead of
    // being dropped, which was the old single-profile limitation.
    final resinPlans = fakeScheduler.lastApplied
        .where((n) => n.kind == 'resinThreshold')
        .toList();
    expect(resinPlans, hasLength(2));
    // With more than one account the titles say which is which.
    expect(resinPlans.where((n) => n.title.startsWith('Alt: ')), hasLength(1));
  });

  test(
    'an unfinished account gets a commission reminder before its reset',
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
          hoyolabCredentialsStoreProvider.overrideWithValue(
            FakeHoyolabCredentialsStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(catalogDb.close);
      addTearDown(userDb.close);

      await container.read(currentProfileProvider.future);
      await container.read(notificationReconcileProvider.future);

      final reminders = fakeScheduler.lastApplied
          .where((n) => n.kind == 'commissionReminder')
          .toList();
      expect(reminders, hasLength(1));
      // Asia resets at 20:00 UTC; the reminder leads it by two hours.
      expect(reminders.single.scheduledAt, DateTime.utc(2026, 1, 1, 18));
      expect(reminders.single.body, contains('4 commissions left'));
    },
  );

  test('a finished account gets no commission reminder', () async {
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
        hoyolabCredentialsStoreProvider.overrideWithValue(
          FakeHoyolabCredentialsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final profileId = (await container.read(currentProfileProvider.future)).id;
    final overview = container.read(
      accountsOverviewControllerProvider.notifier,
    );
    await container.read(accountsOverviewControllerProvider.future);
    for (var i = 0; i < 4; i++) {
      await overview.bumpManualCommissions(profileId);
    }
    await container.read(notificationReconcileProvider.future);

    expect(
      fakeScheduler.lastApplied.where((n) => n.kind == 'commissionReminder'),
      isEmpty,
    );
  });
}
