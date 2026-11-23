import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/wishes/domain/pity_calculator.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';
import 'package:routine_planner/features/wishes/domain/wish_pull.dart';
import 'package:routine_planner/features/wishes/domain/wish_stats.dart';

var _seq = 0;

WishPull pull({int rarity = 3, String name = 'Cool Steel'}) {
  _seq++;
  return WishPull(
    id: _seq.toString().padLeft(4, '0'),
    banner: WishBanner.character,
    itemName: name,
    kind: WishItemKind.weapon,
    rarity: rarity,
    pulledAtUtc: DateTime.utc(2026, 11, 3, 12).add(Duration(minutes: _seq)),
  );
}

void main() {
  setUp(() => _seq = 0);

  group('statsFor', () {
    test('an empty history is all zeroes and no averages', () {
      final stats = statsFor(const []);

      expect(stats.totalPulls, 0);
      expect(stats.fiveStarCount, 0);
      expect(stats.fourStarCount, 0);
      expect(stats.primogemsSpent, 0);
      expect(stats.averageFivePity, isNull);
      expect(stats.fiveStars, isEmpty);
      expect(stats.firstPullAt, isNull);
      expect(stats.lastPullAt, isNull);
    });

    test('counts rarities and charges 160 primogems a wish', () {
      final stats = statsFor([
        pull(),
        pull(rarity: 4, name: 'Xingqiu'),
        pull(rarity: 5, name: 'Hu Tao'),
        pull(),
      ]);

      expect(stats.totalPulls, 4);
      expect(stats.fiveStarCount, 1);
      expect(stats.fourStarCount, 1);
      expect(stats.primogemsSpent, 4 * primogemsPerWish);
      expect(stats.primogemsSpent, 640);
    });

    test('records each 5-star with the pity it came at', () {
      final stats = statsFor([
        for (var i = 0; i < 9; i++) pull(),
        pull(rarity: 5, name: 'Hu Tao'), // 10th pull
        for (var i = 0; i < 74; i++) pull(),
        pull(rarity: 5, name: 'Nahida'), // 75 after the last
      ]);

      // Newest first.
      expect(stats.fiveStars.map((f) => f.pull.itemName), [
        'Nahida',
        'Hu Tao',
      ]);
      expect(stats.fiveStars.first.pity, 75);
      expect(stats.fiveStars.last.pity, 10);
    });

    test(
      'the average excludes the first 5-star, whose pity is truncated by the '
      'import window',
      () {
        final stats = statsFor([
          for (var i = 0; i < 4; i++) pull(),
          pull(rarity: 5, name: 'Hu Tao'), // pity 5, but unknowable in truth
          for (var i = 0; i < 79; i++) pull(),
          pull(rarity: 5, name: 'Nahida'), // pity 80
        ]);

        expect(stats.averageFivePity, 80);
      },
    );

    test('averages every 5-star after the first', () {
      final stats = statsFor([
        pull(rarity: 5, name: 'Hu Tao'), // excluded
        for (var i = 0; i < 59; i++) pull(),
        pull(rarity: 5, name: 'Nahida'), // pity 60
        for (var i = 0; i < 79; i++) pull(),
        pull(rarity: 5, name: 'Furina'), // pity 80
      ]);

      expect(stats.averageFivePity, 70);
    });

    test('a single 5-star leaves the average unknown rather than wrong', () {
      final stats = statsFor([pull(), pull(rarity: 5, name: 'Hu Tao')]);

      expect(stats.fiveStarCount, 1);
      expect(stats.averageFivePity, isNull);
    });

    test('reports the span of the history', () {
      final pulls = [pull(), pull(), pull()];
      final stats = statsFor(pulls);

      expect(stats.firstPullAt, pulls.first.pulledAtUtc);
      expect(stats.lastPullAt, pulls.last.pulledAtUtc);
    });

    test('a history with no 5-star still counts 4-stars and cost', () {
      final stats = statsFor([
        for (var i = 0; i < 20; i++) pull(),
        pull(rarity: 4, name: 'Xingqiu'),
      ]);

      expect(stats.fiveStars, isEmpty);
      expect(stats.averageFivePity, isNull);
      expect(stats.fourStarCount, 1);
      expect(stats.primogemsSpent, 21 * 160);
    });
  });
}
