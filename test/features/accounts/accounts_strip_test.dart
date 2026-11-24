import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/account_status_repository.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/core/widgets/percent_ring_gauge.dart';
import 'package:routine_planner/features/accounts/data/accounts_refresh_providers.dart';
import 'package:routine_planner/features/accounts/presentation/account_card.dart';
import 'package:routine_planner/features/accounts/presentation/accounts_strip.dart';
import 'package:routine_planner/features/accounts/presentation/all_accounts_screen.dart';
import 'package:routine_planner/features/primogems/data/primogem_repository.dart';
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';

void main() {
  late UserDatabase userDb;
  late ProfileRepository profiles;
  late AccountStatusRepository statusRepository;
  late FakeHoyolabCredentialsStore credentials;

  final now = DateTime.utc(2026, 11, 3, 12);

  setUp(() {
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    profiles = ProfileRepository(userDb);
    statusRepository = AccountStatusRepository(userDb);
    credentials = FakeHoyolabCredentialsStore();
  });

  Future<ProviderContainer> pumpStrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    addTearDown(catalogDb.close);

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(FakeClock(now)),
        hoyolabCredentialsStoreProvider.overrideWithValue(credentials),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsStrip())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders a card per account with pooled commission totals', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpStrip(tester);

    expect(find.byType(AccountCard), findsNWidgets(2));
    expect(find.text('All accounts'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
    // Two unconnected accounts, nothing done yet: 0 of 4+4.
    expect(find.text('0/8 commissions'), findsOneWidget);
  });

  testWidgets('a single account reads as "Your account"', (tester) async {
    await profiles.getActiveProfile();

    await pumpStrip(tester);

    expect(find.text('Your account'), findsOneWidget);
    // The pooled header total is suppressed for a single account, so the
    // only occurrence is the card's own label.
    expect(find.text('0/4 commissions'), findsOneWidget);
    expect(find.byType(AccountCard), findsOneWidget);
  });

  testWidgets('tapping an unselected card switches to that account', (tester) async {
    final main = (await profiles.getActiveProfile()).id;
    final alt = (await profiles.createProfile(displayName: 'Alt', server: 'europe')).id;

    final container = await pumpStrip(tester);
    expect((await container.read(currentProfileProvider.future)).id, main);

    await tester.tap(find.text('Alt'));
    await tester.pumpAndSettle();

    expect((await container.read(currentProfileProvider.future)).id, alt);
  });

  testWidgets('tapping the gauge logs a manual commission', (tester) async {
    await profiles.getActiveProfile();

    await pumpStrip(tester);
    expect(find.text('0/4 commissions'), findsOneWidget);
    expect(find.text('4 to go'), findsOneWidget);
    // The control carries its own semantics node for screen readers.
    expect(find.bySemanticsLabel(RegExp('Log a commission')), findsOneWidget);

    await tester.tap(find.byType(PercentRingGauge).first);
    await tester.pumpAndSettle();

    final rows = await userDb.select(userDb.dailyCommissions).get();
    expect(rows.map((r) => r.completed).toList(), [1], reason: 'DB state after tap');

    expect(find.text('1/4 commissions'), findsOneWidget);
    expect(find.text('3 to go'), findsOneWidget);
  });

  testWidgets('a connected account shows live numbers and its sync time', (tester) async {
    final profileId = (await profiles.getActiveProfile()).id;
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');
    await statusRepository.saveSnapshot(
      profileId,
      fetchedAt: now,
      finishedTaskNum: 4,
      totalTaskNum: 4,
      extraTaskRewardReceived: true,
      remainResinDiscountNum: 2,
      resinDiscountNumLimit: 3,
      finishedExpeditionNum: 1,
      currentExpeditionNum: 2,
      currentHomeCoin: 1800,
      maxHomeCoin: 2400,
    );

    await pumpStrip(tester);

    expect(find.text('4/4 commissions'), findsOneWidget);
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('Expeditions 1/2 back'), findsOneWidget);
    expect(find.text('Boss discounts 2/3 left'), findsOneWidget);
    expect(find.text('Realm 1800/2400'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    // Live progress is reported, not editable.
    expect(find.bySemanticsLabel(RegExp('Log a commission')), findsNothing);
  });

  testWidgets('a failed refresh is shown on that account only', (tester) async {
    final profileId = (await profiles.getActiveProfile()).id;
    await profiles.createProfile(displayName: 'Alt', server: 'europe');
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

    final container = await pumpStrip(tester);
    container
        .read(accountRefreshErrorsProvider.notifier)
        .record([(profileId: profileId, refreshed: false, error: 'Not logged in')]);
    await tester.pumpAndSettle();

    expect(find.text('Not logged in'), findsOneWidget);
  });

  group('wishes and primogems per account', () {
    testWidgets('a card shows that account own pity and balance', (tester) async {
      final mainId = (await profiles.getActiveProfile()).id;
      await profiles.createProfile(displayName: 'Alt', server: 'europe');

      // The main account has imported history; the alt has neither.
      await WishRepository(userDb).insertPulls(mainId, [
        for (var i = 1; i <= 12; i++)
          WishPull(
            id: (1700000000000000000 + i).toString(),
            banner: WishBanner.character,
            itemName: 'Cool Steel',
            kind: WishItemKind.weapon,
            rarity: 3,
            pulledAtUtc: now.add(Duration(minutes: i)),
          ),
      ], now: now);
      await PrimogemRepository(userDb).setAnchor(
        mainId,
        balance: 4000,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );

      await pumpStrip(tester);

      expect(find.text('Pity 12/90'), findsOneWidget);
      // 4000 anchored, less the 12 seeded wishes at 160 each: the card runs
      // the same ledger as the Wishes screen, per account.
      expect(find.text('2080 primogems · 13 wishes'), findsOneWidget);
      // The alt account shows neither line rather than a zero.
      expect(find.textContaining('Pity 0/'), findsNothing);
    });

    testWidgets('a manually tracked pity is labelled as such', (tester) async {
      final mainId = (await profiles.getActiveProfile()).id;
      await WishRepository(userDb).saveManualPity(
        mainId,
        WishBanner.character,
        pityFive: 62,
        pityFour: 3,
        guaranteed: true,
        now: now,
      );

      await pumpStrip(tester);

      expect(find.text('Pity 62/90 (by hand)'), findsOneWidget);
    });

    testWidgets('imported history wins over a manual number on the card', (tester) async {
      final mainId = (await profiles.getActiveProfile()).id;
      await WishRepository(userDb).saveManualPity(
        mainId,
        WishBanner.character,
        pityFive: 62,
        pityFour: 3,
        guaranteed: true,
        now: now,
      );
      await WishRepository(userDb).insertPulls(mainId, [
        WishPull(
          id: '1700000000000000001',
          banner: WishBanner.character,
          itemName: 'Cool Steel',
          kind: WishItemKind.weapon,
          rarity: 3,
          pulledAtUtc: now,
        ),
      ], now: now);

      await pumpStrip(tester);

      expect(find.text('Pity 1/90'), findsOneWidget);
      expect(find.textContaining('by hand'), findsNothing);
    });

    testWidgets('an account with no anchor shows no balance line', (tester) async {
      await profiles.getActiveProfile();

      await pumpStrip(tester);

      expect(find.textContaining('primogems'), findsNothing);
    });
  });

  testWidgets('the header reaches the all-accounts screen', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpStrip(tester);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(AllAccountsScreen), findsOneWidget);
  });
}
