import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/primogems/presentation/primogem_date_format.dart';

void main() {
  group('formatForecastDate', () {
    test('drops the year for a date in the same year', () {
      expect(
        formatForecastDate(
          DateTime.utc(2026, 12, 25),
          relativeTo: DateTime.utc(2026, 11, 3),
        ),
        '25 Dec',
      );
    });

    test('keeps the year when the forecast crosses into the next one', () {
      expect(
        formatForecastDate(
          DateTime.utc(2027, 2, 12),
          relativeTo: DateTime.utc(2026, 11, 3),
        ),
        '12 Feb 2027',
      );
    });

    test('includes the year when there is nothing to compare against', () {
      expect(formatForecastDate(DateTime.utc(2027, 1, 1)), '1 Jan 2027');
    });

    test('names every month', () {
      for (var month = 1; month <= 12; month++) {
        expect(
          formatForecastDate(DateTime.utc(2026, month, 1)),
          isNot(contains('null')),
        );
      }
    });
  });
}
