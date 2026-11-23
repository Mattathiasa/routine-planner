import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/profile_providers.dart';
import 'package:routine_planner/features/wishes/application/wish_view_models.dart';
import 'package:routine_planner/features/wishes/application/wishes_controller.dart';
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';

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
  late ProviderContainer container;
  late WishRepository repository;

  setUp(() async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(FakeClock(now)),
      ],
    );
    addTearDown(container.dispose);

    repository = WishRepository(userDb);
  });

  /// The controller bootstraps a profile through currentProfileProvider, so
  /// read it first and use whatever id it settled on.
  Future<String> profileId() async {
    final data = await container.read(wishesControllerProvider.future);
    return data.profileId;
  }

  test('an account with no history reports no history and unknown pity', () async {
    final data = await container.read(wishesControllerProvider.future);

    expect(data.hasHistory, isFalse);
    expect(data.stats.totalPulls, 0);
    expect(data.recentHistory, isEmpty);
    expect(data.lastImportedAt, isNull);
    // Every banner still gets a card, so the screen never special-cases one.
    expect(data.banners, hasLength(WishBanner.values.length));
    for (final card in data.banners) {
      expect(card.source, PitySource.unknown);
      expect(card.pity, 0);
    }
  });

  test('imported history drives pity, stats and the history list', () async {
    final id = await profileId();
    await repository.insertPulls(id, [
      for (var i = 1; i <= 9; i++) pull(i),
      pull(10, rarity: 5, name: 'Hu Tao', kind: WishItemKind.character),
      pull(11),
      pull(12, rarity: 4, name: 'Xingqiu', kind: WishItemKind.character),
    ], now: now);
    container.invalidate(wishesControllerProvider);

    final data = await container.read(wishesControllerProvider.future);
    final character = data.banners.firstWhere(
      (b) => b.banner == WishBanner.character,
    );

    expect(data.hasHistory, isTrue);
    expect(character.source, PitySource.imported);
    expect(character.pity, 2); // two pulls after the 5-star
    expect(character.pityFour, 0); // the newest pull is the 4-star
    expect(character.totalPulls, 12);
    expect(character.lastFiveName, 'Hu Tao');

    expect(data.stats.fiveStarCount, 1);
    expect(data.stats.fourStarCount, 1);
    expect(data.stats.primogemsSpent, 12 * 160);

    // History is newest first.
    expect(data.recentHistory.first.itemName, 'Xingqiu');
    expect(data.recentHistory.last.itemName, 'Cool Steel');
  });

  test('attaches an element from the catalog to a character pull', () async {
    final id = await profileId();
    // 'Aster' is a seed-catalog character (the seed catalog's names are
    // sample data, not real ones).
    await repository.insertPulls(id, [
      pull(1, rarity: 5, name: 'Aster', kind: WishItemKind.character),
    ], now: now);
    container.invalidate(wishesControllerProvider);

    final data = await container.read(wishesControllerProvider.future);

    expect(data.recentHistory.single.element, isNotNull);
  });

  test('a name the catalog does not know still appears, without an element', () async {
    final id = await profileId();
    await repository.insertPulls(id, [
      pull(1, rarity: 5, name: 'Someone From A Future Patch'),
    ], now: now);
    container.invalidate(wishesControllerProvider);

    final data = await container.read(wishesControllerProvider.future);

    expect(data.recentHistory.single.itemName, 'Someone From A Future Patch');
    expect(data.recentHistory.single.element, isNull);
  });

  test('pity is reported per 5-star in the stats list, and only for 5-stars', () async {
    final id = await profileId();
    await repository.insertPulls(id, [
      pull(1, rarity: 5, name: 'Hu Tao', kind: WishItemKind.character),
      for (var i = 2; i <= 60; i++) pull(i),
      pull(61, rarity: 5, name: 'Nahida', kind: WishItemKind.character),
    ], now: now);
    container.invalidate(wishesControllerProvider);

    final data = await container.read(wishesControllerProvider.future);

    expect(data.stats.fiveStars.first.itemName, 'Nahida');
    expect(data.stats.fiveStars.first.pity, 60);
    // Nothing below 5-star carries a pity number.
    expect(
      data.recentHistory.where((e) => e.rarity < 5).every((e) => e.pity == null),
      isTrue,
    );
  });

  group('manual pity', () {
    test('is used when there is no imported history', () async {
      await container
          .read(wishesControllerProvider.notifier)
          .setManualPity(
            WishBanner.character,
            pityFive: 62,
            pityFour: 3,
            guaranteed: true,
          );

      final data = await container.read(wishesControllerProvider.future);
      final character = data.banners.firstWhere(
        (b) => b.banner == WishBanner.character,
      );

      expect(character.source, PitySource.manual);
      expect(character.pity, 62);
      expect(character.pityFour, 3);
      expect(character.guaranteedNextFive, isTrue);
    });

    test('imported history wins over a manual number', () async {
      final id = await profileId();
      await container
          .read(wishesControllerProvider.notifier)
          .setManualPity(
            WishBanner.character,
            pityFive: 62,
            pityFour: 3,
            guaranteed: true,
          );
      await repository.insertPulls(id, [pull(1), pull(2)], now: now);
      container.invalidate(wishesControllerProvider);

      final data = await container.read(wishesControllerProvider.future);
      final character = data.banners.firstWhere(
        (b) => b.banner == WishBanner.character,
      );

      // The two real pulls, not the typed-in 62.
      expect(character.source, PitySource.imported);
      expect(character.pity, 2);
    });

    test('only affects the banner it was entered for', () async {
      await container
          .read(wishesControllerProvider.notifier)
          .setManualPity(
            WishBanner.weapon,
            pityFive: 40,
            pityFour: 1,
            guaranteed: false,
          );

      final data = await container.read(wishesControllerProvider.future);

      expect(
        data.banners.firstWhere((b) => b.banner == WishBanner.weapon).pity,
        40,
      );
      expect(
        data.banners.firstWhere((b) => b.banner == WishBanner.character).source,
        PitySource.unknown,
      );
    });
  });

  test('clearHistory empties the account history', () async {
    final id = await profileId();
    await repository.insertPulls(id, [pull(1)], now: now);
    container.invalidate(wishesControllerProvider);
    expect(
      (await container.read(wishesControllerProvider.future)).hasHistory,
      isTrue,
    );

    await container.read(wishesControllerProvider.notifier).clearHistory();

    final data = await container.read(wishesControllerProvider.future);
    expect(data.hasHistory, isFalse);
    expect(await repository.pullCount(id), 0);
  });

  group('card derived values', () {
    test('the weapon banner uses the shorter guarantee', () async {
      final data = await container.read(wishesControllerProvider.future);

      expect(
        data.banners.firstWhere((b) => b.banner == WishBanner.weapon).hardPity,
        80,
      );
      expect(
        data.banners
            .firstWhere((b) => b.banner == WishBanner.character)
            .hardPity,
        90,
      );
    });

    test('percent and remaining counts track pity', () async {
      final id = await profileId();
      await repository.insertPulls(id, [
        for (var i = 1; i <= 45; i++) pull(i),
      ], now: now);
      container.invalidate(wishesControllerProvider);

      final data = await container.read(wishesControllerProvider.future);
      final character = data.banners.firstWhere(
        (b) => b.banner == WishBanner.character,
      );

      expect(character.pity, 45);
      expect(character.percentToHardPity, 50);
      expect(character.pullsToHardPity, 45);
      expect(character.reachedSoftPity, isFalse);
    });

    test('soft pity registers once it is reached', () async {
      final id = await profileId();
      await repository.insertPulls(id, [
        for (var i = 1; i <= 80; i++) pull(i),
      ], now: now);
      container.invalidate(wishesControllerProvider);

      final data = await container.read(wishesControllerProvider.future);

      expect(
        data.banners
            .firstWhere((b) => b.banner == WishBanner.character)
            .reachedSoftPity,
        isTrue,
      );
    });
  });

  test('names the account only when more than one exists', () async {
    final data = await container.read(wishesControllerProvider.future);
    expect(data.labelAccount, isFalse);

    await userDb
        .into(userDb.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'profile-2',
            displayName: const Value('Alt'),
            server: 'europe',
            updatedAt: now,
          ),
        );
    // Mutating the profile list invalidates its provider too — the app's own
    // convention, since nothing here is stream-backed.
    container.invalidate(profileListProvider);
    container.invalidate(wishesControllerProvider);

    final withTwo = await container.read(wishesControllerProvider.future);
    expect(withTwo.labelAccount, isTrue);
  });
}
