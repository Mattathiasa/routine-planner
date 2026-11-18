import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/account_status_repository.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/features/accounts/application/account_view_models.dart';
import 'package:routine_planner/features/accounts/application/accounts_overview_controller.dart';

void main() {
  late UserDatabase userDb;
  late ProfileRepository profiles;
  late AccountStatusRepository statusRepository;
  late FakeHoyolabCredentialsStore credentials;
  late FakeClock clock;

  // A Tuesday, mid Asia server day.
  final now = DateTime.utc(2026, 11, 3, 12);

  Future<ProviderContainer> containerWith() async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    addTearDown(catalogDb.close);
    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(clock),
        hoyolabCredentialsStoreProvider.overrideWithValue(credentials),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    profiles = ProfileRepository(userDb);
    statusRepository = AccountStatusRepository(userDb);
    credentials = FakeHoyolabCredentialsStore();
    clock = FakeClock(now);
  });

  test('lists one card per account, marking the selected one', () async {
    final main = (await profiles.getActiveProfile()).id;
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    final container = await containerWith();
    final cards = await container.read(accountsOverviewControllerProvider.future);

    expect(cards, hasLength(2));
    expect(cards.firstWhere((c) => c.profileId == main).isSelected, isTrue);
    final alt = cards.firstWhere((c) => c.profileId != main);
    expect(alt.isSelected, isFalse);
    expect(alt.displayName, 'Alt');
    expect(alt.serverLabel, 'Europe');
  });

  test('a connected account shows live commissions from its snapshot', () async {
    final profileId = (await profiles.getActiveProfile()).id;
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');
    await statusRepository.saveSnapshot(
      profileId,
      fetchedAt: now,
      finishedTaskNum: 3,
      totalTaskNum: 4,
      extraTaskRewardReceived: false,
      remainResinDiscountNum: 2,
      resinDiscountNumLimit: 3,
      finishedExpeditionNum: 1,
      currentExpeditionNum: 2,
      currentHomeCoin: 1800,
      maxHomeCoin: 2400,
    );

    final container = await containerWith();
    final card = (await container.read(accountsOverviewControllerProvider.future)).single;

    expect(card.connected, isTrue);
    expect(card.commissions.source, CommissionSource.live);
    expect(card.commissions.completed, 3);
    expect(card.commissions.total, 4);
    expect(card.commissions.percent, 75);
    expect(card.commissions.isComplete, isFalse);
    expect(card.lastUpdated, now);
    expect(card.remainBossDiscounts, 2);
    expect(card.finishedExpeditions, 1);
    expect(card.realmCurrency, 1800);
  });

  test('an unconnected account falls back to the manual tracker', () async {
    await profiles.getActiveProfile();

    final container = await containerWith();
    final card = (await container.read(accountsOverviewControllerProvider.future)).single;

    expect(card.connected, isFalse);
    expect(card.commissions.source, CommissionSource.manual);
    expect(card.commissions.completed, 0);
    expect(card.commissions.total, defaultDailyCommissionCount);
    expect(card.lastUpdated, isNull);
    // Live-only extras stay unknown rather than reading as zero.
    expect(card.remainBossDiscounts, isNull);
    expect(card.realmCurrency, isNull);
  });

  test('manual commissions advance, then wrap back to zero', () async {
    final profileId = (await profiles.getActiveProfile()).id;
    final container = await containerWith();
    final controller = container.read(accountsOverviewControllerProvider.notifier);
    await container.read(accountsOverviewControllerProvider.future);

    for (var expected = 1; expected <= 4; expected++) {
      await controller.bumpManualCommissions(profileId);
      final card = (await container.read(accountsOverviewControllerProvider.future)).single;
      expect(card.commissions.completed, expected);
    }

    final full = (await container.read(accountsOverviewControllerProvider.future)).single;
    expect(full.commissions.isComplete, isTrue);

    await controller.bumpManualCommissions(profileId);
    final wrapped = (await container.read(accountsOverviewControllerProvider.future)).single;
    expect(wrapped.commissions.completed, 0);
  });

  test('the manual bonus can be claimed, and clears when progress drops', () async {
    final profileId = (await profiles.getActiveProfile()).id;
    final container = await containerWith();
    final controller = container.read(accountsOverviewControllerProvider.notifier);
    await container.read(accountsOverviewControllerProvider.future);

    for (var i = 0; i < 4; i++) {
      await controller.bumpManualCommissions(profileId);
    }
    await controller.toggleManualBonus(profileId);
    expect(
      (await container.read(accountsOverviewControllerProvider.future)).single.commissions.bonusClaimed,
      isTrue,
    );

    // Wrapping past the last commission can't leave a claimed bonus behind.
    await controller.bumpManualCommissions(profileId);
    final wrapped = (await container.read(accountsOverviewControllerProvider.future)).single;
    expect(wrapped.commissions.completed, 0);
    expect(wrapped.commissions.bonusClaimed, isFalse);
  });

  test('manual progress is per account and per server day', () async {
    final main = (await profiles.getActiveProfile()).id;
    final alt = (await profiles.createProfile(displayName: 'Alt', server: 'europe')).id;

    final container = await containerWith();
    final controller = container.read(accountsOverviewControllerProvider.notifier);
    await container.read(accountsOverviewControllerProvider.future);

    await controller.bumpManualCommissions(main);
    await controller.bumpManualCommissions(main);
    await controller.bumpManualCommissions(alt);

    var cards = await container.read(accountsOverviewControllerProvider.future);
    expect(cards.firstWhere((c) => c.profileId == main).commissions.completed, 2);
    expect(cards.firstWhere((c) => c.profileId == alt).commissions.completed, 1);

    // Past the Asia reset (20:00 UTC) the main account starts a fresh day;
    // Europe's day (03:00 UTC) has not rolled yet, so its count stands.
    clock.set(DateTime.utc(2026, 11, 3, 21));
    container.invalidate(accountsOverviewControllerProvider);

    cards = await container.read(accountsOverviewControllerProvider.future);
    expect(cards.firstWhere((c) => c.profileId == main).commissions.completed, 0);
    expect(cards.firstWhere((c) => c.profileId == alt).commissions.completed, 1);
  });
}
