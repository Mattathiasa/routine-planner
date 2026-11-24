import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/accounts/presentation/account_card.dart';
import 'package:routine_planner/features/accounts/presentation/all_accounts_screen.dart';
import 'package:routine_planner/features/primogems/data/primogem_repository.dart';
import 'package:routine_planner/features/resin/data/resin_repository.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';

void main() {
  late UserDatabase userDb;
  late ProfileRepository profiles;

  final now = DateTime.utc(2026, 11, 3, 12);

  setUp(() {
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    profiles = ProfileRepository(userDb);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    addTearDown(catalogDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(now)),
          hoyolabCredentialsStoreProvider.overrideWithValue(
            FakeHoyolabCredentialsStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AllAccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every account in full', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');
    await profiles.createProfile(displayName: 'Third', server: 'america');

    await pumpScreen(tester);

    expect(find.text('All accounts'), findsOneWidget);
    expect(find.byType(AccountCard), findsNWidgets(3));
    expect(find.text('Alt'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });

  testWidgets('pools commissions across accounts', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpScreen(tester);

    expect(find.text('Across 2 accounts'), findsOneWidget);
    expect(find.text('0/8 done'), findsOneWidget);
  });

  /// A fresh profile starts at full resin, so both accounts have to be
  /// synced for a near-cap count to mean anything.
  Future<void> syncResin(Map<String, int> byProfileId) async {
    final resin = ResinRepository(userDb);
    const engine = ResinEngine();
    for (final entry in byProfileId.entries) {
      final state = await resin.loadResinState(entry.key);
      final (newState, event) = engine.sync(state, now, x: entry.value);
      await resin.saveResinMutation(entry.key, newState, event);
    }
  }

  testWidgets('flags accounts near the resin cap', (tester) async {
    final mainId = (await profiles.getActiveProfile()).id;
    final alt = await profiles.createProfile(
      displayName: 'Alt',
      server: 'europe',
    );

    await syncResin({mainId: 190, alt.id: 20});

    await pumpScreen(tester);

    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('says none when no account is near the cap', (tester) async {
    final mainId = (await profiles.getActiveProfile()).id;
    final alt = await profiles.createProfile(
      displayName: 'Alt',
      server: 'europe',
    );

    await syncResin({mainId: 20, alt.id: 30});

    await pumpScreen(tester);

    expect(find.text('none'), findsOneWidget);
  });

  testWidgets('totals primogems across the accounts that track them', (tester) async {
    final mainId = (await profiles.getActiveProfile()).id;
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await PrimogemRepository(userDb).setAnchor(
      mainId,
      balance: 3200,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 0,
    );

    await pumpScreen(tester);

    // Says how many accounts the total covers, so a partial total is never
    // read as the full picture.
    expect(find.text('3200 · 20 wishes (of 1 tracked)'), findsOneWidget);
  });

  testWidgets('drops the qualifier when every account is tracked', (tester) async {
    final mainId = (await profiles.getActiveProfile()).id;
    final alt = await profiles.createProfile(
      displayName: 'Alt',
      server: 'europe',
    );

    final primogems = PrimogemRepository(userDb);
    for (final (id, balance) in [(mainId, 3200), (alt.id, 800)]) {
      await primogems.setAnchor(
        id,
        balance: balance,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
    }

    await pumpScreen(tester);

    expect(find.text('4000 · 25 wishes'), findsOneWidget);
  });

  testWidgets('a single account gets no totals card', (tester) async {
    await profiles.getActiveProfile();

    await pumpScreen(tester);

    expect(find.byType(AccountCard), findsOneWidget);
    expect(find.textContaining('Across'), findsNothing);
  });

  testWidgets('omits the primogem total when nothing is tracked', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpScreen(tester);

    expect(find.text('Primogems'), findsNothing);
  });
}
