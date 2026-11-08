import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/domain/hoyolab_notes.dart';

void main() {
  group('parseHoyolabNotes', () {
    test('reads the 3 fields this app needs from a real-shaped response', () {
      final json = {
        'current_resin': 142,
        'max_resin': 200,
        'resin_recovery_time': 27840,
        'resin_discount_num_limit': 3,
        'remain_resin_discount_num': 2,
        'total_task_num': 4,
        'finished_task_num': 1,
        'is_extra_task_reward_received': false,
        'expeditions': <dynamic>[],
        'max_expedition_num': 5,
        'current_home_coin': 1800,
        'max_home_coin': 2400,
        'home_coin_recovery_time': 10000,
      };

      final notes = parseHoyolabNotes(json);
      expect(notes.currentResin, 142);
      expect(notes.maxResin, 200);
      expect(notes.secondsUntilFull, 27840);
    });

    test('throws HoyolabNotesFormatException when a needed field is missing or the wrong type', () {
      expect(
        () => parseHoyolabNotes({'max_resin': 200, 'resin_recovery_time': 100}),
        throwsA(isA<HoyolabNotesFormatException>()),
      );
      expect(
        () => parseHoyolabNotes({
          'current_resin': '142', // wrong type
          'max_resin': 200,
          'resin_recovery_time': 100,
        }),
        throwsA(isA<HoyolabNotesFormatException>()),
      );
    });
  });
}
