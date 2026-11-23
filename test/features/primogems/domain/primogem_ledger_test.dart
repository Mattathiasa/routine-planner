import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/primogems/domain/primogem_ledger.dart';

final anchoredAt = DateTime.utc(2026, 11, 3, 12);

PrimogemAnchorInput anchor({
  int balance = 1000,
  int fates = 0,
  String anchorMonth = '2026-11',
  int? monthIncomeAtAnchor = 0,
}) {
  return (
    balance: balance,
    fates: fates,
    anchoredAt: anchoredAt,
    anchorMonth: anchorMonth,
    monthIncomeAtAnchor: monthIncomeAtAnchor,
  );
}

int balance({
  PrimogemAnchorInput? withAnchor,
  Map<String, int> income = const {},
  List<PrimogemAdjustmentInput> adjustments = const [],
  int wishes = 0,
}) {
  return balanceAt(
    anchor: withAnchor ?? anchor(),
    monthlyIncome: income,
    adjustments: adjustments,
    wishesSinceAnchor: wishes,
    now: anchoredAt.add(const Duration(days: 30)),
  );
}

void main() {
  group('balanceAt', () {
    test('with nothing since the anchor, the balance is the anchor', () {
      expect(balance(), 1000);
    });

    test('adds income from months after the anchor month', () {
      expect(balance(income: {'2026-12': 3200}), 4200);
    });

    test('ignores income from months before the anchor month', () {
      expect(balance(income: {'2026-10': 5000}), 1000);
    });

    test('credits only the anchor month income earned since the anchor', () {
      // The diary read 1200 when the anchor was set and reads 1500 now, so
      // 300 is new.
      expect(
        balance(
          withAnchor: anchor(monthIncomeAtAnchor: 1200),
          income: {'2026-11': 1500},
        ),
        1300,
      );
    });

    test('credits none of the anchor month when the reading is unknown', () {
      // Understating is the safe error: without the reading at anchor time
      // there is no way to tell which part was already counted.
      expect(
        balance(
          withAnchor: anchor(monthIncomeAtAnchor: null),
          income: {'2026-11': 1500},
        ),
        1000,
      );
    });

    test('never subtracts when the anchor month total went backwards', () {
      // Shouldn't happen, but a re-anchor mid-month could look like it.
      expect(
        balance(
          withAnchor: anchor(monthIncomeAtAnchor: 2000),
          income: {'2026-11': 1500},
        ),
        1000,
      );
    });

    test('spans several later months', () {
      expect(
        balance(income: {'2026-11': 0, '2026-12': 1000, '2027-01': 2000}),
        4000,
      );
    });

    test('charges 160 primogems a wish', () {
      expect(balance(wishes: 5), 1000 - 800);
    });

    test('applies adjustments made after the anchor', () {
      expect(
        balance(
          adjustments: [
            (at: anchoredAt.add(const Duration(days: 1)), delta: 500),
            (at: anchoredAt.add(const Duration(days: 2)), delta: -200),
          ],
        ),
        1300,
      );
    });

    test('ignores adjustments from before the anchor', () {
      expect(
        balance(
          adjustments: [
            (at: anchoredAt.subtract(const Duration(days: 1)), delta: 5000),
          ],
        ),
        1000,
      );
    });

    test('ignores an adjustment at the exact anchor instant', () {
      // The anchor is the player stating their balance, so anything at that
      // moment is already in it.
      expect(balance(adjustments: [(at: anchoredAt, delta: 5000)]), 1000);
    });

    test('clamps at zero rather than going negative', () {
      expect(balance(wishes: 100), 0);
    });

    test('combines income, adjustments and spending', () {
      expect(
        balance(
          income: {'2026-12': 2000},
          adjustments: [
            (at: anchoredAt.add(const Duration(days: 1)), delta: -500),
          ],
          wishes: 10,
        ),
        1000 + 2000 - 500 - 1600,
      );
    });
  });

  group('wishesAffordable', () {
    test('divides by the price of a wish', () {
      expect(wishesAffordable(1600), 10);
      expect(wishesAffordable(1599), 9);
      expect(wishesAffordable(0), 0);
    });

    test('counts fates already held', () {
      expect(wishesAffordable(320, fates: 7), 9);
    });
  });

  group('projectedDailyIncome', () {
    test('counts commissions alone by default', () {
      expect(
        projectedDailyIncome(welkin: false, battlePass: false),
        commissionPrimogems,
      );
    });

    test('adds the Welkin when the player has one', () {
      expect(
        projectedDailyIncome(welkin: true, battlePass: false),
        commissionPrimogems + welkinPrimogems,
      );
    });

    test('spreads the battle pass across its cycle', () {
      expect(
        projectedDailyIncome(welkin: false, battlePass: true),
        commissionPrimogems + battlePassPrimogems ~/ battlePassCycleDays,
      );
    });

    test('adds both together', () {
      expect(
        projectedDailyIncome(welkin: true, battlePass: true),
        greaterThan(projectedDailyIncome(welkin: true, battlePass: false)),
      );
    });
  });

  group('dateForWishes', () {
    final now = DateTime.utc(2026, 11, 3, 12);

    test('is now when the wishes are already affordable', () {
      expect(
        dateForWishes(
          balance: 16000,
          fates: 0,
          wishes: 90,
          dailyIncome: 60,
          now: now,
        ),
        now,
      );
    });

    test('is now exactly when the balance just covers it', () {
      expect(
        dateForWishes(
          balance: 90 * 160,
          fates: 0,
          wishes: 90,
          dailyIncome: 60,
          now: now,
        ),
        now,
      );
    });

    test('rounds up to the day the shortfall is covered', () {
      // 600 short at 60 a day is 10 days.
      expect(
        dateForWishes(
          balance: 1000 - 400,
          fates: 0,
          wishes: 10,
          dailyIncome: 60,
          now: now,
        ),
        now.add(const Duration(days: 17)),
      );
    });

    test('rounds a partial day up', () {
      expect(
        dateForWishes(
          balance: 0,
          fates: 0,
          wishes: 1,
          dailyIncome: 150,
          now: now,
        ),
        now.add(const Duration(days: 2)),
      );
    });

    test('counts fates toward the goal', () {
      expect(
        dateForWishes(
          balance: 0,
          fates: 90,
          wishes: 90,
          dailyIncome: 60,
          now: now,
        ),
        now,
      );
    });

    test('is unknowable with no income at all', () {
      expect(
        dateForWishes(
          balance: 0,
          fates: 0,
          wishes: 90,
          dailyIncome: 0,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('shortfallFor', () {
    test('reports what is still missing', () {
      expect(shortfallFor(balance: 1000, fates: 0, wishes: 10), 600);
    });

    test('is zero once affordable', () {
      expect(shortfallFor(balance: 2000, fates: 0, wishes: 10), 0);
    });

    test('counts fates', () {
      expect(shortfallFor(balance: 0, fates: 10, wishes: 10), 0);
    });
  });
}
