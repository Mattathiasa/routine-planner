import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';

void main() {
  group('WishBanner.fromGachaType', () {
    test('maps every canonical code to its banner', () {
      expect(WishBanner.fromGachaType(100), WishBanner.beginner);
      expect(WishBanner.fromGachaType(200), WishBanner.standard);
      expect(WishBanner.fromGachaType(301), WishBanner.character);
      expect(WishBanner.fromGachaType(302), WishBanner.weapon);
      expect(WishBanner.fromGachaType(500), WishBanner.chronicled);
    });

    test('folds the second character-banner code (400) into character', () {
      expect(WishBanner.fromGachaType(400), WishBanner.character);
    });

    test('returns null for an unknown code instead of throwing', () {
      // A future banner must be skipped on import, never crash it.
      expect(WishBanner.fromGachaType(999), isNull);
      expect(WishBanner.fromGachaType(0), isNull);
    });
  });

  group('queryableGachaTypes', () {
    test('covers every canonical code plus 400', () {
      expect(
        WishBanner.queryableGachaTypes,
        containsAll(<int>[100, 200, 301, 302, 400, 500]),
      );
    });

    test('every queryable code resolves to a banner', () {
      for (final code in WishBanner.queryableGachaTypes) {
        expect(
          WishBanner.fromGachaType(code),
          isNotNull,
          reason: 'gacha_type $code must map to a banner',
        );
      }
    });

    test('has no duplicates', () {
      expect(
        WishBanner.queryableGachaTypes.toSet().length,
        WishBanner.queryableGachaTypes.length,
      );
    });
  });

  group('display', () {
    test('every banner has a non-empty label and short label', () {
      for (final banner in WishBanner.values) {
        expect(banner.label, isNotEmpty);
        expect(banner.shortLabel, isNotEmpty);
      }
    });
  });
}
