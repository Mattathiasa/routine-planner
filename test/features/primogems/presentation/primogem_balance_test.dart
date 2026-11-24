import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/primogems/data/primogem_repository.dart';
import 'package:routine_planner/features/primogems/presentation/primogem_balance_section.dart';
import 'package:routine_planner/features/primogems/presentation/primogem_forecast_section.dart';
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';

final now = DateTime.utc(2026, 11, 3, 12);

WishPull pull(int n) => WishPull(
  id: (1700000000000000000 + n).toString(),
  banner: WishBanner.character,
  itemName: 'Cool Steel',
  kind: WishItemKind.weapon,
  rarity: 3,
  pulledAtUtc: now.add(Duration(minutes: n)),
);

void main() {
  late UserDatabase userDb;
  late CatalogDatabase catalogDb;
  late FakeHoyolabCredentialsStore credentials;

  setUp(() async {
    catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    credentials = FakeHoyolabCredentialsStore();
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);
  });

  Future<String> seedProfile() async {
    final profile = await ProfileRepository(userDb).getActiveProfile();
    return profile.id;
  }

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          hoyolabCredentialsStoreProvider.overrideWithValue(credentials),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          clockProvider.overrideWithValue(FakeClock(now)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PrimogemBalanceSection(),
                  PrimogemForecastSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no anchor it asks for the balance once', (tester) async {
    await seedProfile();
    await pumpCard(tester);

    expect(find.text('Not set yet'), findsOneWidget);
    expect(find.text('Set balance'), findsOneWidget);
    expect(find.textContaining('tell the app once'), findsOneWidget);
  });

  testWidgets('setting a balance shows it and the wishes it buys', (tester) async {
    await seedProfile();
    await pumpCard(tester);

    await tester.tap(find.text('Set balance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12480');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('12480'), findsOneWidget);
    // 12480 / 160.
    expect(find.text('78 wishes'), findsOneWidget);
  });

  testWidgets('fates count toward the wishes affordable', (tester) async {
    await seedProfile();
    await pumpCard(tester);

    await tester.tap(find.text('Set balance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '320');
    await tester.enterText(find.byType(TextField).last, '7');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('9 wishes'), findsOneWidget);
    expect(find.text('+ 7 fates'), findsOneWidget);
  });

  testWidgets('a non-numeric balance is rejected', (tester) async {
    await seedProfile();
    await pumpCard(tester);

    await tester.tap(find.text('Set balance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'lots');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('whole number'), findsOneWidget);
  });

  testWidgets('an unconnected account says it is tracked by hand', (tester) async {
    final profileId = await seedProfile();
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: null,
    );
    await pumpCard(tester);

    expect(find.textContaining('Tracked by hand'), findsOneWidget);
  });

  testWidgets('a connected account whose diary never answered says so', (tester) async {
    final profileId = await seedProfile();
    await credentials.save(
      profileId: profileId,
      cookie: 'ltoken_v2=x',
      uid: '800000001',
    );
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: null,
    );
    await pumpCard(tester);

    expect(find.textContaining("Income isn't syncing"), findsOneWidget);
  });

  testWidgets('diary income is reported once it has answered', (tester) async {
    final profileId = await seedProfile();
    await credentials.save(
      profileId: profileId,
      cookie: 'ltoken_v2=x',
      uid: '800000001',
    );
    final repository = PrimogemRepository(userDb);
    await repository.setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 500,
    );
    await repository.saveMonthlyIncome(
      profileId,
      month: '2026-11',
      primogems: 800,
      fetchedAt: now,
    );
    await pumpCard(tester);

    expect(find.textContaining('800 earned this month'), findsOneWidget);
    // 1000 anchored + (800 - 500) earned since.
    expect(find.text('1300'), findsOneWidget);
  });

  testWidgets('wishes made since the anchor are charged against it', (tester) async {
    final profileId = await seedProfile();
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 0,
    );
    await WishRepository(userDb).insertPulls(profileId, [
      pull(1),
      pull(2),
    ], now: now);
    await pumpCard(tester);

    // 1000 - 2 x 160.
    expect(find.text('680'), findsOneWidget);
    expect(find.textContaining('320 spent on wishes'), findsOneWidget);
  });

  testWidgets('an adjustment moves the balance', (tester) async {
    final profileId = await seedProfile();
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now.subtract(const Duration(days: 1)),
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 0,
    );
    await pumpCard(tester);

    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('1500'), findsOneWidget);
  });

  testWidgets('a spent adjustment subtracts', (tester) async {
    final profileId = await seedProfile();
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now.subtract(const Duration(days: 1)),
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 0,
    );
    await pumpCard(tester);

    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spent'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '600');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('400'), findsOneWidget);
  });

  testWidgets('re-anchoring replaces the balance', (tester) async {
    final profileId = await seedProfile();
    await PrimogemRepository(userDb).setAnchor(
      profileId,
      balance: 1000,
      fates: 0,
      anchoredAt: now,
      anchorMonth: '2026-11',
      monthIncomeAtAnchor: 0,
    );
    await pumpCard(tester);

    await tester.tap(find.text('Re-anchor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);
    expect(find.text('0 wishes'), findsOneWidget);
  });

  group('forecast', () {
    testWidgets('is hidden until a balance is anchored', (tester) async {
      await seedProfile();
      await pumpCard(tester);

      expect(find.text('Saving up'), findsNothing);
    });

    testWidgets('projects a date for a guaranteed 5-star', (tester) async {
      final profileId = await seedProfile();
      await PrimogemRepository(userDb).setAnchor(
        profileId,
        balance: 14000,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await pumpCard(tester);

      // 90 wishes is 14400; 400 short at 60 a day is 7 days.
      expect(find.text('Saving up'), findsOneWidget);
      expect(find.textContaining('A guaranteed 5★ by'), findsOneWidget);
      expect(find.textContaining('400 primogems to go'), findsOneWidget);
    });

    testWidgets('says so outright when a guaranteed 5-star is affordable', (tester) async {
      final profileId = await seedProfile();
      await PrimogemRepository(userDb).setAnchor(
        profileId,
        balance: 20000,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await pumpCard(tester);

      expect(
        find.text('You can afford a guaranteed 5★ now'),
        findsOneWidget,
      );
    });

    testWidgets('turning on the Welkin brings the date closer', (tester) async {
      final profileId = await seedProfile();
      await PrimogemRepository(userDb).setAnchor(
        profileId,
        balance: 0,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await pumpCard(tester);

      expect(find.textContaining('at 60 a day'), findsOneWidget);

      // Only the switch toggles, matching the settings screen's rows. The
      // card renders Welkin first, battle pass second.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('at 150 a day'), findsOneWidget);
    });

    testWidgets('the battle pass adds its per-day share', (tester) async {
      final profileId = await seedProfile();
      await PrimogemRepository(userDb).setAnchor(
        profileId,
        balance: 0,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await pumpCard(tester);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      // 60 + 680 / 42.
      expect(find.textContaining('at 76 a day'), findsOneWidget);
    });

    testWidgets('says what the projection leaves out', (tester) async {
      final profileId = await seedProfile();
      await PrimogemRepository(userDb).setAnchor(
        profileId,
        balance: 0,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await pumpCard(tester);

      expect(
        find.textContaining('Spiral Abyss and quests are not counted'),
        findsOneWidget,
      );
    });
  });
}
