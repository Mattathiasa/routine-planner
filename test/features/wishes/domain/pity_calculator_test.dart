import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/wishes/domain/pity_calculator.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';

var _seq = 0;

/// Builds a pull with an ascending id, so a list literal reads oldest-first.
WishPull pull({
  int rarity = 3,
  String name = 'Cool Steel',
  WishBanner banner = WishBanner.character,
  WishItemKind kind = WishItemKind.weapon,
}) {
  _seq++;
  return WishPull(
    id: _seq.toString().padLeft(4, '0'),
    banner: banner,
    itemName: name,
    kind: kind,
    rarity: rarity,
    pulledAtUtc: DateTime.utc(2026, 11, 3, 12).add(Duration(minutes: _seq)),
  );
}

WishPull fiveStarCharacter(String name) =>
    pull(rarity: 5, name: name, kind: WishItemKind.character);

void main() {
  setUp(() => _seq = 0);

  group('pityFor', () {
    test('an empty history is zero pity with no last 5-star', () {
      final pity = pityFor(WishBanner.character, const []);

      expect(pity.pullsSinceFive, 0);
      expect(pity.pullsSinceFour, 0);
      expect(pity.lastFive, isNull);
      expect(pity.totalPulls, 0);
      expect(pity.guaranteedNextFive, isFalse);
    });

    test('counts every pull when no 5-star has ever dropped', () {
      final pity = pityFor(WishBanner.character, [
        for (var i = 0; i < 37; i++) pull(),
      ]);

      expect(pity.pullsSinceFive, 37);
      expect(pity.pullsSinceFour, 37);
    });

    test('counts pulls since the most recent 5-star, not the first', () {
      final pity = pityFor(WishBanner.character, [
        fiveStarCharacter('Hu Tao'),
        for (var i = 0; i < 12; i++) pull(),
        fiveStarCharacter('Nahida'),
        for (var i = 0; i < 5; i++) pull(),
      ]);

      expect(pity.pullsSinceFive, 5);
      expect(pity.lastFive?.itemName, 'Nahida');
    });

    test('a 5-star on the newest pull leaves zero pity', () {
      final pity = pityFor(WishBanner.character, [
        for (var i = 0; i < 80; i++) pull(),
        fiveStarCharacter('Furina'),
      ]);

      expect(pity.pullsSinceFive, 0);
      expect(pity.lastFive?.itemName, 'Furina');
    });

    test('4-star pity is tracked independently of 5-star pity', () {
      final pity = pityFor(WishBanner.character, [
        fiveStarCharacter('Furina'),
        for (var i = 0; i < 4; i++) pull(),
        pull(rarity: 4, name: 'Xingqiu'),
        for (var i = 0; i < 3; i++) pull(),
      ]);

      expect(pity.pullsSinceFive, 8);
      expect(pity.pullsSinceFour, 3);
    });

    test('a 5-star also resets 4-star pity', () {
      final pity = pityFor(WishBanner.character, [
        pull(rarity: 4, name: 'Xingqiu'),
        for (var i = 0; i < 20; i++) pull(),
        fiveStarCharacter('Furina'),
        pull(),
        pull(),
      ]);

      expect(pity.pullsSinceFour, 2);
    });

    test('an all-3-star history counts every pull on both counters', () {
      final pity = pityFor(WishBanner.weapon, [
        for (var i = 0; i < 9; i++) pull(banner: WishBanner.weapon),
      ]);

      expect(pity.pullsSinceFive, 9);
      expect(pity.pullsSinceFour, 9);
    });
  });

  group('hard and soft pity per banner', () {
    test('the weapon banner guarantees sooner than the rest', () {
      expect(hardPityFor(WishBanner.weapon), hardPityFiveStarWeapon);
      expect(softPityStartFor(WishBanner.weapon), softPityStartWeapon);
    });

    test('every other banner uses the 90-pull guarantee', () {
      for (final banner in WishBanner.values) {
        if (banner == WishBanner.weapon) continue;
        expect(hardPityFor(banner), hardPityFiveStarCharacter);
        expect(softPityStartFor(banner), softPityStartCharacter);
      }
    });

    test('pullsToHardPity and pullsToSoftPity count down and clamp at zero', () {
      final pity = pityFor(WishBanner.character, [
        for (var i = 0; i < 80; i++) pull(),
      ]);

      expect(pity.pullsSinceFive, 80);
      expect(pullsToHardPity(pity), 10);
      // Past soft pity already, so it clamps rather than going negative.
      expect(pullsToSoftPity(pity), 0);
    });
  });

  group('50/50 inference', () {
    test('a permanent-pool 5-star means the next 5-star is guaranteed', () {
      final pity = pityFor(WishBanner.character, [fiveStarCharacter('Keqing')]);

      expect(pity.guaranteedNextFive, isTrue);
    });

    test('an off-pool 5-star was the featured one, so no guarantee', () {
      final pity = pityFor(WishBanner.character, [fiveStarCharacter('Hu Tao')]);

      expect(pity.guaranteedNextFive, isFalse);
    });

    test('is never inferred on the standard banner', () {
      final pity = pityFor(WishBanner.standard, [
        pull(
          rarity: 5,
          name: 'Keqing',
          kind: WishItemKind.character,
          banner: WishBanner.standard,
        ),
      ]);

      expect(pity.guaranteedNextFive, isFalse);
    });

    test('is never inferred on the weapon banner (Epitomized Path is unknowable)', () {
      final pity = pityFor(WishBanner.weapon, [
        pull(
          rarity: 5,
          name: 'Amos\' Bow',
          banner: WishBanner.weapon,
        ),
      ]);

      expect(pity.guaranteedNextFive, isFalse);
    });

    test('a 5-star weapon on the character banner does not set a guarantee', () {
      // Can't happen today, but it must not be read as a lost 50/50.
      final pity = pityFor(WishBanner.character, [
        pull(rarity: 5, name: 'Skyward Harp'),
      ]);

      expect(pity.guaranteedNextFive, isFalse);
    });

    test('only the most recent 5-star decides the guarantee', () {
      final pity = pityFor(WishBanner.character, [
        fiveStarCharacter('Keqing'),
        for (var i = 0; i < 70; i++) pull(),
        fiveStarCharacter('Furina'),
        pull(),
      ]);

      expect(pity.guaranteedNextFive, isFalse);
    });
  });

  group('pityForAll', () {
    test('splits a mixed history by banner', () {
      final pulls = [
        fiveStarCharacter('Hu Tao'),
        pull(),
        pull(banner: WishBanner.weapon),
        pull(banner: WishBanner.weapon),
        pull(banner: WishBanner.standard),
      ];

      final all = pityForAll(pulls);

      expect(all[WishBanner.character]!.totalPulls, 2);
      expect(all[WishBanner.character]!.pullsSinceFive, 1);
      expect(all[WishBanner.weapon]!.totalPulls, 2);
      expect(all[WishBanner.weapon]!.pullsSinceFive, 2);
      expect(all[WishBanner.standard]!.totalPulls, 1);
    });

    test('includes every banner even with nothing pulled on it', () {
      final all = pityForAll(const []);

      expect(all.keys, containsAll(WishBanner.values));
      for (final pity in all.values) {
        expect(pity.totalPulls, 0);
      }
    });
  });
}
