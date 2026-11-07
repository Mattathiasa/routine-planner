import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/clock/game_server.dart';
import 'package:routine_planner/features/settings/presentation/settings_formatting.dart';

void main() {
  // Same fixture as today_controller_test.dart / app_shell_test.dart:
  // 2026-11-03 is a Tuesday, noon UTC. Addis Ababa is UTC+3.
  final nowUtc = DateTime.utc(2026, 11, 3, 12);
  const addisAbaba = Duration(hours: 3);

  group('resetCaption, against the approved mock\'s 4 rows (localOffset: Addis Ababa)', () {
    test('Asia (+8h) resets 23:00 the day before', () {
      final caption = resetCaption(server: GameServer.asia, nowUtc: nowUtc, localOffset: addisAbaba);
      expect(caption.time, '23:00');
      expect(caption.dayBefore, isTrue);
    });

    test('Europe (+1h) resets 06:00, same day', () {
      final caption = resetCaption(
        server: GameServer.europe,
        nowUtc: nowUtc,
        localOffset: addisAbaba,
      );
      expect(caption.time, '06:00');
      expect(caption.dayBefore, isFalse);
    });

    test('America (-5h) resets 12:00, same day', () {
      final caption = resetCaption(
        server: GameServer.america,
        nowUtc: nowUtc,
        localOffset: addisAbaba,
      );
      expect(caption.time, '12:00');
      expect(caption.dayBefore, isFalse);
    });

    test('TW, HK, MO (+8h) resets 23:00 the day before, same as Asia', () {
      final caption = resetCaption(
        server: GameServer.twHkMo,
        nowUtc: nowUtc,
        localOffset: addisAbaba,
      );
      expect(caption.time, '23:00');
      expect(caption.dayBefore, isTrue);
    });
  });

  test('the caption is not hardcoded to any particular time zone', () {
    final utcCaption = resetCaption(server: GameServer.asia, nowUtc: nowUtc, localOffset: Duration.zero);
    expect(utcCaption.time, '20:00');
    expect(utcCaption.dayBefore, isTrue);
  });
}
