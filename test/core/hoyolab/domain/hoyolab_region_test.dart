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
}
