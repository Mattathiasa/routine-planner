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
import 'package:routine_planner/core/widgets/app_card.dart';
import 'package:routine_planner/features/planner/presentation/rarity_chip.dart';
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

/// The "Set pity" button inside a named banner's card. Untouched banners
/// render in enum order, so index-based targeting would be brittle.
Finder setPityButtonFor(String bannerLabel) {
  return find.descendant(
    of: find.ancestor(
      of: find.text(bannerLabel, skipOffstage: false),
      matching: find.byType(AppCard),
    ),
    matching: find.text('Set pity', skipOffstage: false),
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

  group('manual pity', () {
    testWidgets('an untouched banner offers to set pity by hand', (tester) async {
      await seed([pull(1)]);
      await pumpScreen(tester);

      // One per untouched banner.
      expect(
        find.text('Set pity', skipOffstage: false),
        findsNWidgets(WishBanner.values.length - 1),
      );
    });

    testWidgets('with nothing tracked at all the empty state replaces the cards', (tester) async {
      await pumpScreen(tester);

      expect(find.text('No wishes yet'), findsOneWidget);
      expect(find.text('Set pity', skipOffstage: false), findsNothing);
    });

    testWidgets('a banner tracked by hand shows its number and can be edited', (tester) async {
      await seed([pull(1)]);
      await pumpScreen(tester);

      await tester.tap(find.text('Set pity', skipOffstage: false).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '62');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('62'), findsWidgets);
      expect(find.text('Tracked manually · edit'), findsOneWidget);
    });

    testWidgets('a pity above the guarantee is rejected', (tester) async {
      await seed([pull(1)]);
      await pumpScreen(tester);

      await tester.tap(find.text('Set pity', skipOffstage: false).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '400');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter a 5★ pity'), findsOneWidget);
    });

    testWidgets('clearing a manual number stops tracking that banner', (tester) async {
      await seed([pull(1)]);
      await pumpScreen(tester);

      await tester.tap(find.text('Set pity', skipOffstage: false).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '20');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Tracked manually · edit'), findsOneWidget);

      await tester.tap(find.text('Tracked manually · edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Tracked manually · edit'), findsNothing);
    });

    testWidgets('the 50/50 switch appears on the character banner', (tester) async {
      await seed([pull(1, banner: WishBanner.weapon)]);
      await pumpScreen(tester);

      await tester.tap(setPityButtonFor('Character Event'));
      await tester.pumpAndSettle();

      expect(find.text('Character Event pity'), findsOneWidget);
      expect(find.text('Next 5★ is guaranteed'), findsOneWidget);
    });

    testWidgets('it does not appear on banners without a 50/50', (tester) async {
      await seed([pull(1, banner: WishBanner.weapon)]);
      await pumpScreen(tester);

      await tester.tap(setPityButtonFor('Standard Wish'));
      await tester.pumpAndSettle();

      expect(find.text('Standard Wish pity'), findsOneWidget);
      expect(find.text('Next 5★ is guaranteed'), findsNothing);
    });
  });

  group('statistics and history', () {
    testWidgets('sums up the history and lists every 5-star', (tester) async {
      await seed([
        for (var i = 1; i <= 9; i++) pull(i),
        pull(10, rarity: 5, name: 'Aster', kind: WishItemKind.character),
        pull(11, rarity: 4, name: 'Wren', kind: WishItemKind.character),
        for (var i = 12; i <= 70; i++) pull(i),
        pull(71, rarity: 5, name: 'Corvin', kind: WishItemKind.character),
      ]);
      await pumpScreen(tester);

      expect(find.text('Your luck'), findsOneWidget);
      expect(find.text('Every 5★', skipOffstage: false), findsOneWidget);
      // 71 wishes at 160 primogems each, grouped.
      expect(find.text('11,360', skipOffstage: false), findsOneWidget);
      expect(find.text('Corvin', skipOffstage: false), findsWidgets);
      expect(find.text('pity 61', skipOffstage: false), findsWidgets);
    });

    testWidgets('a single 5-star reports no average, and says why', (tester) async {
      await seed([
        for (var i = 1; i <= 9; i++) pull(i),
        pull(10, rarity: 5, name: 'Aster', kind: WishItemKind.character),
      ]);
      await pumpScreen(tester);

      expect(find.text('—', skipOffstage: false), findsOneWidget);
      expect(
        find.textContaining('needs a second 5★', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('lists recent wishes newest first', (tester) async {
      await seed([
        pull(1, name: 'Oldest'),
        pull(2, name: 'Middle'),
        pull(3, name: 'Newest'),
      ]);
      await pumpScreen(tester);

      expect(find.text('Recent wishes'), findsOneWidget);

      final newest = tester.getTopLeft(
        find.text('Newest', skipOffstage: false),
      );
      final oldest = tester.getTopLeft(
        find.text('Oldest', skipOffstage: false),
      );
      expect(newest.dy, lessThan(oldest.dy));
    });

    testWidgets('a rarity chip marks 4-stars and 5-stars only', (tester) async {
      await seed([
        pull(1),
        pull(2, rarity: 4, name: 'Wren', kind: WishItemKind.character),
        pull(3, rarity: 5, name: 'Aster', kind: WishItemKind.character),
      ]);
      await pumpScreen(tester);

      // Two chips, not three: the 3★ row gets none. Counting the widget
      // rather than its text, because the statistics card also prints a
      // literal '4★' as a column label.
      expect(find.byType(RarityChip, skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('no statistics section before anything is imported', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Your luck'), findsNothing);
      expect(find.text('Recent wishes'), findsNothing);
    });
  });
}
