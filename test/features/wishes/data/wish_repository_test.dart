import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';
import 'package:drift/drift.dart' show Value;

final now = DateTime.utc(2026, 11, 3, 12);

/// Snowflake ids are fixed-width decimal strings; these mimic that.
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
  late UserDatabase db;
  late WishRepository repository;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = WishRepository(db);
    addTearDown(db.close);

    // wish_pulls references profiles, so the account has to exist first.
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: const Value('Main'),
            server: 'asia',
            updatedAt: now,
          ),
        );
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'profile-2',
            displayName: const Value('Alt'),
            server: 'europe',
            updatedAt: now,
          ),
        );
  });

  group('insertPulls', () {
    test('stores pulls and reports how many were new', () async {
      final imported = await repository.insertPulls('profile-1', [
        pull(1),
        pull(2),
      ], now: now);

      expect(imported, 2);
      expect(await repository.pullCount('profile-1'), 2);
    });

    test('re-importing an overlapping window duplicates nothing', () async {
      await repository.insertPulls(
        'profile-1',
        [pull(1), pull(2)],
        now: now,
      );
      final secondRun = await repository.insertPulls('profile-1', [
        pull(2), // already stored
        pull(3), // new
      ], now: now);

      expect(secondRun, 1);
      expect(await repository.pullCount('profile-1'), 3);
    });

    test('an empty batch is a no-op', () async {
      expect(await repository.insertPulls('profile-1', const [], now: now), 0);
      expect(await repository.pullCount('profile-1'), 0);
    });

    test('advances the high-water mark to the newest id per banner', () async {
      await repository.insertPulls('profile-1', [
        pull(1),
        pull(5),
        pull(3),
        pull(9, banner: WishBanner.weapon),
      ], now: now);

      expect(
        await repository.lastImportedId('profile-1', WishBanner.character),
        snowflake(5),
      );
      expect(
        await repository.lastImportedId('profile-1', WishBanner.weapon),
        snowflake(9),
      );
      // A banner with nothing imported has no mark at all.
      expect(
        await repository.lastImportedId('profile-1', WishBanner.standard),
        isNull,
      );
    });

    test('never moves the high-water mark backwards', () async {
      await repository.insertPulls('profile-1', [pull(10)], now: now);
      await repository.insertPulls('profile-1', [pull(2)], now: now);

      expect(
        await repository.lastImportedId('profile-1', WishBanner.character),
        snowflake(10),
      );
    });
  });

  group('pullsFor', () {
    test('returns pulls oldest first, which is what the domain expects', () async {
      await repository.insertPulls('profile-1', [
        pull(3),
        pull(1),
        pull(2),
      ], now: now);

      final pulls = await repository.pullsFor('profile-1');

      expect(pulls.map((p) => p.id), [
        snowflake(1),
        snowflake(2),
        snowflake(3),
      ]);
    });

    test('round-trips every field', () async {
      await repository.insertPulls('profile-1', [
        pull(1, rarity: 5, name: 'Hu Tao', kind: WishItemKind.character),
      ], now: now);

      final stored = (await repository.pullsFor('profile-1')).single;

      expect(stored.id, snowflake(1));
      expect(stored.banner, WishBanner.character);
      expect(stored.itemName, 'Hu Tao');
      expect(stored.kind, WishItemKind.character);
      expect(stored.rarity, 5);
      expect(stored.pulledAtUtc, now.add(const Duration(minutes: 1)));
      expect(stored.pulledAtUtc.isUtc, isTrue);
    });

    test('filters by banner', () async {
      await repository.insertPulls('profile-1', [
        pull(1),
        pull(2, banner: WishBanner.weapon),
      ], now: now);

      expect(
        await repository.pullsFor('profile-1', banner: WishBanner.weapon),
        hasLength(1),
      );
    });

    test('is scoped to one account', () async {
      await repository.insertPulls('profile-1', [pull(1)], now: now);
      await repository.insertPulls('profile-2', [pull(2)], now: now);

      expect(await repository.pullsFor('profile-1'), hasLength(1));
      expect(await repository.pullsFor('profile-2'), hasLength(1));
      expect(
        (await repository.pullsFor('profile-2')).single.id,
        snowflake(2),
      );
    });
  });

  group('pullCountSince', () {
    test('counts only pulls strictly after the given instant', () async {
      await repository.insertPulls('profile-1', [
        pull(1), // now + 1min
        pull(5), // now + 5min
        pull(9), // now + 9min
      ], now: now);

      final cutoff = now.add(const Duration(minutes: 5));

      expect(await repository.pullCountSince('profile-1', cutoff), 1);
      expect(await repository.pullCountSince('profile-1', now), 3);
    });
  });

  group('saveManualPity', () {
    test('stores manual pity without disturbing an import mark', () async {
      await repository.insertPulls('profile-1', [pull(7)], now: now);
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: 62,
        pityFour: 4,
        guaranteed: true,
        now: now,
      );

      final state = await repository.importStateFor('profile-1');
      final row = state.single;
      expect(row.manualPityFive, 62);
      expect(row.manualPityFour, 4);
      expect(row.manualGuaranteed, isTrue);
      expect(row.lastImportedPullId, snowflake(7));
    });

    test('an import does not wipe manual pity already entered', () async {
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: 30,
        pityFour: 2,
        guaranteed: false,
        now: now,
      );
      await repository.insertPulls('profile-1', [pull(1)], now: now);

      final row = (await repository.importStateFor('profile-1')).single;
      expect(row.manualPityFive, 30);
      expect(row.lastImportedPullId, snowflake(1));
    });

    test('nulls clear a previously entered value', () async {
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: 30,
        pityFour: 2,
        guaranteed: true,
        now: now,
      );
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: null,
        pityFour: null,
        guaranteed: null,
        now: now,
      );

      final row = (await repository.importStateFor('profile-1')).single;
      expect(row.manualPityFive, isNull);
      expect(row.manualGuaranteed, isNull);
    });

    test('keeps one row per banner', () async {
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: 10,
        pityFour: 1,
        guaranteed: false,
        now: now,
      );
      await repository.saveManualPity(
        'profile-1',
        WishBanner.character,
        pityFive: 11,
        pityFour: 2,
        guaranteed: false,
        now: now,
      );
      await repository.saveManualPity(
        'profile-1',
        WishBanner.weapon,
        pityFive: 5,
        pityFour: 1,
        guaranteed: false,
        now: now,
      );

      final state = await repository.importStateFor('profile-1');
      expect(state, hasLength(2));
      expect(
        state.firstWhere((r) => r.bannerType == 301).manualPityFive,
        11,
      );
    });
  });

  group('clearPulls', () {
    test('removes this account history and state, leaving others alone', () async {
      await repository.insertPulls('profile-1', [pull(1)], now: now);
      await repository.insertPulls('profile-2', [pull(2)], now: now);

      await repository.clearPulls('profile-1');

      expect(await repository.pullCount('profile-1'), 0);
      expect(await repository.importStateFor('profile-1'), isEmpty);
      expect(await repository.pullCount('profile-2'), 1);
    });

    test('a cleared pull can be imported again', () async {
      // The reason the delete is hard rather than soft: a soft-deleted row
      // keeps its snowflake primary key and would block the re-import.
      await repository.insertPulls('profile-1', [pull(1)], now: now);
      await repository.clearPulls('profile-1');

      final reimported = await repository.insertPulls('profile-1', [
        pull(1),
      ], now: now);

      expect(reimported, 1);
      expect(await repository.pullCount('profile-1'), 1);
    });
  });
}
