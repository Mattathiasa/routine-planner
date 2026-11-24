import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/domain/hoyolab_region.dart';

void main() {
  group('hoyolabRegionForUid', () {
    test('maps each known overseas prefix to its region', () {
      expect(hoyolabRegionForUid('600000001'), 'os_usa');
      expect(hoyolabRegionForUid('700000001'), 'os_euro');
      expect(hoyolabRegionForUid('800000001'), 'os_asia');
      expect(hoyolabRegionForUid('1800000001'), 'os_asia');
      expect(hoyolabRegionForUid('900000001'), 'os_cht');
    });

    test('trims surrounding whitespace before reading the prefix', () {
      expect(hoyolabRegionForUid(' 600000001 '), 'os_usa');
    });

    test('throws for an unrecognized prefix', () {
      expect(
        () => hoyolabRegionForUid('500000001'),
        throwsA(isA<UnknownHoyolabUidException>()),
      );
    });

    test('throws for a UID too short to have a prefix', () {
      expect(
        () => hoyolabRegionForUid('1234567'),
        throwsA(isA<UnknownHoyolabUidException>()),
      );
    });
  });

  group('serverOffsetForRegion', () {
    test('matches the four known server offsets', () {
      expect(serverOffsetForRegion('os_usa'), const Duration(hours: -5));
      expect(serverOffsetForRegion('os_euro'), const Duration(hours: 1));
      expect(serverOffsetForRegion('os_asia'), const Duration(hours: 8));
      expect(serverOffsetForRegion('os_cht'), const Duration(hours: 8));
    });

    test('rejects a region it does not know', () {
      expect(
        () => serverOffsetForRegion('cn_gf01'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('every region a UID can produce has an offset', () {
      for (final uid in ['600000001', '700000001', '800000001', '1800000001', '900000001']) {
        expect(
          () => serverOffsetForRegion(hoyolabRegionForUid(uid)),
          returnsNormally,
          reason: 'UID $uid',
        );
      }
    });
  });
}
