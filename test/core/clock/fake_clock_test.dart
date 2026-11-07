import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';

void main() {
  group('FakeClock', () {
    test('starts at the given instant', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 12));
    });

    test('set() overwrites the instant', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock.set(DateTime.utc(2030, 6, 15, 8));
      expect(clock.nowUtc(), DateTime.utc(2030, 6, 15, 8));
    });

    test('set() normalizes non-UTC input to UTC', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock.set(DateTime(2026, 1, 1));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('advance() adds the given duration', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1, 0, 0, 0));
      clock.advance(const Duration(minutes: 90));
      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 1, 30, 0));
    });

    test('advance() can be called repeatedly and accumulates', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      clock.advance(const Duration(seconds: 480));
      clock.advance(const Duration(seconds: 480));
      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1).add(const Duration(seconds: 960)));
    });
  });
}
