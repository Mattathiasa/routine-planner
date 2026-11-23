import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';

/// Asia is +8, matching `GameServer.asia.utcOffset`.
const asiaOffset = Duration(hours: 8);

Map<String, Object?> record({
  Object? id = '1700000000000000000',
  Object? gachaType = '301',
  Object? name = 'Hu Tao',
  Object? itemType = 'Character',
  Object? rankType = '5',
  Object? time = '2026-11-03 20:00:00',
}) {
  return {
    'id': id,
    'gacha_type': gachaType,
    'name': name,
    'item_type': itemType,
    'rank_type': rankType,
    'time': time,
  };
}

void main() {
  group('parseWishPulls', () {
    test('parses a record whose numbers all arrive as strings', () {
      final pulls = parseWishPulls([record()], serverOffset: asiaOffset);

      expect(pulls, hasLength(1));
      final pull = pulls.single;
      expect(pull.id, '1700000000000000000');
      expect(pull.banner, WishBanner.character);
      expect(pull.itemName, 'Hu Tao');
      expect(pull.kind, WishItemKind.character);
      expect(pull.rarity, 5);
    });

    test('parses a record whose numbers arrive as real ints', () {
      final pulls = parseWishPulls([
        record(gachaType: 302, rankType: 4, id: 42),
      ], serverOffset: asiaOffset);

      expect(pulls.single.banner, WishBanner.weapon);
      expect(pulls.single.rarity, 4);
      expect(pulls.single.id, '42');
    });

    test('converts the server-local timestamp to UTC with the server offset', () {
      // 20:00 on an Asia (+8) server is 12:00 UTC.
      final pulls = parseWishPulls([
        record(time: '2026-11-03 20:00:00'),
      ], serverOffset: asiaOffset);

      expect(pulls.single.pulledAtUtc, DateTime.utc(2026, 11, 3, 12));
      expect(pulls.single.pulledAtUtc.isUtc, isTrue);
    });

    test('handles a negative server offset (America, -5)', () {
      // 20:00 on an America (-5) server is 01:00 UTC the next day.
      final pulls = parseWishPulls([
        record(time: '2026-11-03 20:00:00'),
      ], serverOffset: const Duration(hours: -5));

      expect(pulls.single.pulledAtUtc, DateTime.utc(2026, 11, 4, 1));
    });

    test('folds gacha_type 400 into the character banner', () {
      final pulls = parseWishPulls([
        record(gachaType: '400'),
      ], serverOffset: asiaOffset);

      expect(pulls.single.banner, WishBanner.character);
    });

    test('reads a weapon item_type', () {
      final pulls = parseWishPulls([
        record(name: 'Dragon\'s Bane', itemType: 'Weapon', gachaType: '302'),
      ], serverOffset: asiaOffset);

      expect(pulls.single.kind, WishItemKind.weapon);
      expect(pulls.single.itemName, "Dragon's Bane");
    });

    test('skips an unrecognised banner code instead of failing the import', () {
      final pulls = parseWishPulls([
        record(gachaType: '999'),
        record(id: 'keeper'),
      ], serverOffset: asiaOffset);

      expect(pulls, hasLength(1));
      expect(pulls.single.id, 'keeper');
    });

    test('skips non-map entries', () {
      final pulls = parseWishPulls([
        'nonsense',
        null,
        record(),
      ], serverOffset: asiaOffset);

      expect(pulls, hasLength(1));
    });

    test('returns an empty list for an empty response', () {
      expect(parseWishPulls(const [], serverOffset: asiaOffset), isEmpty);
    });

    test('preserves the upstream order', () {
      final pulls = parseWishPulls([
        record(id: '3'),
        record(id: '2'),
        record(id: '1'),
      ], serverOffset: asiaOffset);

      expect(pulls.map((p) => p.id), ['3', '2', '1']);
    });

    group('throws', () {
      test('on a missing gacha_type', () {
        expect(
          () => parseWishPulls([
            record(gachaType: null),
          ], serverOffset: asiaOffset),
          throwsA(isA<WishPullFormatException>()),
        );
      });

      test('on a missing id', () {
        expect(
          () => parseWishPulls([record(id: null)], serverOffset: asiaOffset),
          throwsA(isA<WishPullFormatException>()),
        );
      });

      test('on a missing rank_type', () {
        expect(
          () =>
              parseWishPulls([record(rankType: null)], serverOffset: asiaOffset),
          throwsA(isA<WishPullFormatException>()),
        );
      });

      test('on an unparseable time', () {
        expect(
          () => parseWishPulls([
            record(time: 'yesterday'),
          ], serverOffset: asiaOffset),
          throwsA(isA<WishPullFormatException>()),
        );
      });
    });
  });
}
