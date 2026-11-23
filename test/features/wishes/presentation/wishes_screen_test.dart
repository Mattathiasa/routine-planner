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
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';
import 'package:routine_planner/features/wishes/presentation/wishes_screen.dart';

final now = DateTime.utc(2026, 11, 3, 12);

String snowflake(int n) => (1700000000000000000 + n).toString();

WishPull pull(
  int n, {
  int rarity = 3,
  String name = 'Cool Steel',
  WishBanner banner = WishBanner.character,
  WishItemKind kind = WishItemKind.weapon,
}) {
  return WishPull(
    id: snowflake(n),
    banner: banner,
    itemName: name,
    kind: kind,
    rarity: rarity,
    pulledAtUtc: now.add(Duration(minutes: n)),
  );
}

void main() {
  late UserDatabase userDb;
  late CatalogDatabase catalogDb;

  setUp(() async {
    catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);
  });

  /// Seeds straight through the repositories. getActiveProfile bootstraps the
  /// profile the screen will resolve, so no provider container is needed here.
  Future<void> seed(List<WishPull> pulls) async {
    final profile = await ProfileRepository(userDb).getActiveProfile();
    await WishRepository(userDb).insertPulls(profile.id, pulls, now: now);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          hoyolabCredentialsStoreProvider.overrideWithValue(
            FakeHoyolabCredentialsStore(),
          ),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          clockProvider.overrideWithValue(FakeClock(now)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WishesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an account with no wishes shows the empty state', (tester) async {
    await pumpScreen(tester);

    expect(find.text('No wishes yet'), findsOneWidget);
    expect(find.text('Pity'), findsNothing);
  });

  testWidgets('imported history shows a pity card per banner', (tester) async {
    await seed([
      for (var i = 1; i <= 20; i++) pull(i),
      pull(21, rarity: 5, name: 'Aster', kind: WishItemKind.character),
      for (var i = 22; i <= 30; i++) pull(i),
    ]);
    await pumpScreen(tester);

    expect(find.text('No wishes yet'), findsNothing);
    expect(find.text('Pity'), findsOneWidget);
    expect(find.text('Character Event'), findsOneWidget);
    // Every banner gets a card, in-play ones first.
    for (final banner in WishBanner.values) {
      expect(
        find.text(banner.label, skipOffstage: false),
        findsOneWidget,
        reason: '${banner.label} should have a card',
      );
    }
  });

  testWidgets('shows the pity count, the guarantee and what is left', (tester) async {
    await seed([
      pull(1, rarity: 5, name: 'Aster', kind: WishItemKind.character),
      for (var i = 2; i <= 10; i++) pull(i),
    ]);
    await pumpScreen(tester);

    // Nine pulls since the 5-star, 90-pull guarantee on this banner.
    expect(find.text('9'), findsWidgets);
    expect(find.text('/ 90'), findsOneWidget);
    expect(find.text('81 to guarantee'), findsOneWidget);
    expect(find.textContaining('last 5★ Aster'), findsOneWidget);
  });

  testWidgets('a banner nobody has pulled on reads as untracked', (tester) async {
    await seed([pull(1)]);
    await pumpScreen(tester);

    expect(
      find.text('Not tracked yet', skipOffstage: false),
      // Four of the five banners are untouched.
      findsNWidgets(WishBanner.values.length - 1),
    );
  });

  testWidgets('soft pity is called out once reached', (tester) async {
    await seed([for (var i = 1; i <= 80; i++) pull(i)]);
    await pumpScreen(tester);

    expect(find.text('Soft pity'), findsOneWidget);
  });

  testWidgets('a lost 50/50 shows the guarantee pill', (tester) async {
    await seed([
      // Keqing is in the permanent pool, so the next 5★ is guaranteed.
      pull(1, rarity: 5, name: 'Keqing', kind: WishItemKind.character),
      pull(2),
    ]);
    await pumpScreen(tester);

    expect(find.text('Next 5★ guaranteed'), findsOneWidget);
  });

  testWidgets('a wishless banner at the guarantee reads as guaranteed next wish', (tester) async {
    await seed([
      for (var i = 1; i <= 90; i++) pull(i),
    ]);
    await pumpScreen(tester);

    expect(find.text('Guaranteed next wish'), findsOneWidget);
  });

  group('import flow', () {
    testWidgets('the empty state offers the import', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Import wish history'), findsOneWidget);
    });

    testWidgets('the disclaimer comes before the paste field', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Import wish history'));
      await tester.pumpAndSettle();

      expect(find.text('Import wish history?'), findsOneWidget);
      expect(find.textContaining('reverse-engineered'), findsOneWidget);
      // No way to paste anything until the disclaimer is acknowledged.
      expect(find.text('Wish history link'), findsNothing);
    });

    testWidgets('cancelling the disclaimer opens nothing', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Import wish history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Wish history link'), findsNothing);
    });

    testWidgets('acknowledging it opens the paste field', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Import wish history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand, continue'));
      await tester.pumpAndSettle();

      expect(find.text('Wish history link'), findsOneWidget);
      expect(find.textContaining('Wish → History'), findsOneWidget);
    });

    testWidgets('a link with no authkey is rejected without a network call', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Import wish history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand, continue'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/getGachaLog?gacha_type=301',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no authkey'), findsOneWidget);
    });

    testWidgets('an account with history offers an update instead', (tester) async {
      await seed([pull(1)]);
      await pumpScreen(tester);

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Wish history'), findsOneWidget);
    });
  });
}
