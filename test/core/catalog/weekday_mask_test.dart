import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/weekday_mask.dart';

void main() {
  group('isAlwaysOpen', () {
    test('true when every Mon-Sat bit is set', () {
      const allDays = 0x7F; // all 7 bits, including an explicit Sunday bit
      expect(isAlwaysOpen(allDays), isTrue);

      const monToSatOnly = 0x3F; // no Sunday bit at all
      expect(isAlwaysOpen(monToSatOnly), isTrue);
    });

    test('false when any weekday is missing', () {
      const missingWednesday = 0x3F & ~(1 << 2);
      expect(isAlwaysOpen(missingWednesday), isFalse);
    });

    test('a mask with only Sunday is not "always open"', () {
      const sundayOnly = 1 << 6;
      expect(isAlwaysOpen(sundayOnly), isFalse);
    });
  });

  group('formatWeekdayMask', () {
    test('formats set days as comma-separated abbreviations, Mon..Sun order', () {
      const tueFriSun = (1 << 1) | (1 << 4) | (1 << 6);
      expect(formatWeekdayMask(tueFriSun), 'Tue, Fri, Sun');
    });

    test('formats a single day', () {
      expect(formatWeekdayMask(1 << 0), 'Mon');
    });

    test('an empty mask formats as an empty string', () {
      expect(formatWeekdayMask(0), '');
    });
  });
}
