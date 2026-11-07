import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/clock/game_server.dart';
import 'package:routine_planner/core/clock/server_clock.dart';
import 'package:routine_planner/core/clock/system_clock.dart';

void main() {
  group('ServerClock.serverDateFor', () {
    test('differentiates all four servers at a fixed instant', () {
      // 21:00 UTC is past Asia/TW-HK-MO's 20:00 UTC reset boundary but
      // before Europe's (03:00 UTC) and America's (09:00 UTC) next one.
      final instant = DateTime.utc(2026, 6, 15, 21, 0, 0);

      expect(
        ServerClock(FakeClock(instant), GameServer.asia).serverDateFor(instant),
        DateTime.utc(2026, 6, 16),
      );
      expect(
        ServerClock(FakeClock(instant), GameServer.twHkMo).serverDateFor(instant),
        DateTime.utc(2026, 6, 16),
      );
      expect(
        ServerClock(FakeClock(instant), GameServer.europe).serverDateFor(instant),
        DateTime.utc(2026, 6, 15),
      );
      expect(
        ServerClock(FakeClock(instant), GameServer.america).serverDateFor(instant),
        DateTime.utc(2026, 6, 15),
      );
    });

    test('asia and twHkMo always agree (both +8h)', () {
      final instant = DateTime.utc(2026, 3, 2, 5, 17);
      final asia = ServerClock(FakeClock(instant), GameServer.asia).serverDateFor(instant);
      final twHkMo = ServerClock(FakeClock(instant), GameServer.twHkMo).serverDateFor(instant);
      expect(asia, twHkMo);
    });

    test('asia resets exactly at 20:00 UTC (04:00 local)', () {
      final clock = ServerClock(FakeClock(DateTime.utc(2026)), GameServer.asia);

      expect(
        clock.serverDateFor(DateTime.utc(2026, 11, 6, 19, 59, 59)),
        DateTime.utc(2026, 11, 6),
      );
      expect(
        clock.serverDateFor(DateTime.utc(2026, 11, 6, 20, 0, 0)),
        DateTime.utc(2026, 11, 7),
      );
    });

    test('america resets exactly at 09:00 UTC (04:00 local)', () {
      final clock = ServerClock(FakeClock(DateTime.utc(2026)), GameServer.america);

      expect(
        clock.serverDateFor(DateTime.utc(2026, 11, 7, 8, 59, 59)),
        DateTime.utc(2026, 11, 6),
      );
      expect(
        clock.serverDateFor(DateTime.utc(2026, 11, 7, 9, 0, 0)),
        DateTime.utc(2026, 11, 7),
      );
    });

    test('europe resets exactly at 03:00 UTC (04:00 local)', () {
      final clock = ServerClock(FakeClock(DateTime.utc(2026)), GameServer.europe);

      expect(
        clock.serverDateFor(DateTime.utc(2026, 5, 10, 2, 59, 59)),
        DateTime.utc(2026, 5, 9),
      );
      expect(
        clock.serverDateFor(DateTime.utc(2026, 5, 10, 3, 0, 0)),
        DateTime.utc(2026, 5, 10),
      );
    });

    test('rolls over a year boundary correctly', () {
      final clock = ServerClock(FakeClock(DateTime.utc(2026)), GameServer.asia);

      expect(
        clock.serverDateFor(DateTime.utc(2025, 12, 31, 19, 59, 59)),
        DateTime.utc(2025, 12, 31),
      );
      expect(
        clock.serverDateFor(DateTime.utc(2025, 12, 31, 20, 0, 0)),
        DateTime.utc(2026, 1, 1),
      );
    });
  });

  group('ServerClock.serverDate', () {
    test('delegates to the injected clock and matches serverDateFor', () {
      final fake = FakeClock(DateTime.utc(2026, 11, 6, 19, 59, 59));
      final clock = ServerClock(fake, GameServer.asia);

      expect(clock.serverDate(), clock.serverDateFor(fake.nowUtc()));

      fake.advance(const Duration(seconds: 1));
      expect(clock.serverDate(), DateTime.utc(2026, 11, 7));
    });
  });

  group('SystemClock', () {
    test('nowUtc() tracks real wall-clock time', () {
      final before = DateTime.now().toUtc();
      final observed = const SystemClock().nowUtc();
      final after = DateTime.now().toUtc();

      expect(observed.isUtc, isTrue);
      expect(observed.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
      expect(observed.isBefore(after.add(const Duration(seconds: 5))), isTrue);
    });
  });
}
