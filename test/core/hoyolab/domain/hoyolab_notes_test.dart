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

    test('reads daily commissions', () {
      final notes = parseHoyolabNotes({
        'current_resin': 142,
        'max_resin': 200,
        'resin_recovery_time': 27840,
        'total_task_num': 4,
        'finished_task_num': 3,
        'is_extra_task_reward_received': false,
      });

      expect(notes.finishedTaskNum, 3);
      expect(notes.totalTaskNum, 4);
      expect(notes.extraTaskRewardReceived, isFalse);
    });

    test('reads boss discounts, expeditions and realm currency', () {
      final notes = parseHoyolabNotes({
        'current_resin': 142,
        'max_resin': 200,
        'resin_recovery_time': 27840,
        'resin_discount_num_limit': 3,
        'remain_resin_discount_num': 2,
        'current_expedition_num': 2,
        'max_expedition_num': 5,
        'expeditions': [
          {'status': 'Finished', 'remained_time': '0'},
          {'status': 'Ongoing', 'remained_time': '7200'},
        ],
        'current_home_coin': 1800,
        'max_home_coin': 2400,
        'home_coin_recovery_time': 10000,
      });

      expect(notes.remainResinDiscountNum, 2);
      expect(notes.resinDiscountNumLimit, 3);
      expect(notes.currentExpeditionNum, 2);
      expect(notes.maxExpeditionNum, 5);
      expect(notes.expeditions, hasLength(2));
      expect(notes.expeditions.first.finished, isTrue);
      expect(notes.expeditions.first.remainedSeconds, 0);
      expect(notes.expeditions.last.finished, isFalse);
      expect(notes.expeditions.last.remainedSeconds, 7200);
      expect(notes.currentHomeCoin, 1800);
      expect(notes.maxHomeCoin, 2400);
      expect(notes.homeCoinRecoverySeconds, 10000);
    });

    // These field names are community-sourced and unverified
    // (docs/ASSUMPTIONS.md). A rename upstream must degrade to "we don't
    // know" rather than break resin sync, which is the feature that
    // actually matters.
    test('degrades to null when the optional fields are absent', () {
      final notes = parseHoyolabNotes({
        'current_resin': 142,
        'max_resin': 200,
        'resin_recovery_time': 27840,
      });

      expect(notes.currentResin, 142);
      expect(notes.finishedTaskNum, isNull);
      expect(notes.totalTaskNum, isNull);
      expect(notes.extraTaskRewardReceived, isNull);
      expect(notes.remainResinDiscountNum, isNull);
      expect(notes.currentHomeCoin, isNull);
      expect(notes.expeditions, isEmpty);
    });

    test('tolerates numeric strings and string booleans in the optional fields', () {
      final notes = parseHoyolabNotes({
        'current_resin': '128',
        'max_resin': '200',
        'resin_recovery_time': '34106',
        'finished_task_num': '4',
        'total_task_num': '4',
        'is_extra_task_reward_received': 'true',
        'current_home_coin': '1800',
      });

      expect(notes.finishedTaskNum, 4);
      expect(notes.totalTaskNum, 4);
      expect(notes.extraTaskRewardReceived, isTrue);
      expect(notes.currentHomeCoin, 1800);
    });

    test('a malformed expeditions payload yields an empty list, not a throw', () {
      final notes = parseHoyolabNotes({
        'current_resin': 142,
        'max_resin': 200,
        'resin_recovery_time': 27840,
        'expeditions': 'unexpected',
      });

      expect(notes.expeditions, isEmpty);
    });

    test('accepts numeric strings — HoYoLab serializes these 3 fields as strings', () {
      final notes = parseHoyolabNotes({
        'current_resin': '128',
        'max_resin': '200',
        'resin_recovery_time': '34106',
        'finished_task_num': 4,
        'total_task_num': 4,
      });
      expect(notes.currentResin, 128);
      expect(notes.maxResin, 200);
      expect(notes.secondsUntilFull, 34106);
    });

    test('throws HoyolabNotesFormatException when a needed field is missing or unparseable', () {
      expect(
        () => parseHoyolabNotes({'max_resin': 200, 'resin_recovery_time': 100}),
        throwsA(isA<HoyolabNotesFormatException>()),
      );
      expect(
        () => parseHoyolabNotes({
          'current_resin': 'not a number',
          'max_resin': 200,
          'resin_recovery_time': 100,
        }),
        throwsA(isA<HoyolabNotesFormatException>()),
      );
    });
  });
}
