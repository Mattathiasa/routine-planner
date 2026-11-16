import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';
import 'package:routine_planner/features/resin/domain/resin_event.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';

void main() {
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);
  const r = Duration(seconds: 480);
  final notDueYet = now.add(const Duration(minutes: 5));

  group('sync', () {
    test('x >= cap sets n to null', () {
      final (state, event) = engine.sync(const ResinState(v: 0), now, x: 200);
      expect(state.v, 200);
      expect(state.n, isNull);
      expect(event, isA<ResinEventSync>());
    });

    test('x > cap (over-cap UI read) stores v as-is with n null', () {
      final (state, _) = engine.sync(const ResinState(v: 0), now, x: 215);
      expect(state.v, 215);
      expect(state.n, isNull);
    });

    test('x < cap with fullIn derives n from the threshold formula', () {
      const fullIn = Duration(minutes: 80);
      final (state, _) = engine.sync(const ResinState(v: 0), now, x: 190, fullIn: fullIn);
      expect(state.n, now.add(const Duration(minutes: 8)));
      expect(engine.timeToThreshold(state, state.cap), now.add(fullIn));
    });

    test('x < cap without fullIn defaults to now + R/2 (4 min)', () {
      final (state, _) = engine.sync(const ResinState(v: 0), now, x: 50);
      expect(state.n, now.add(const Duration(minutes: 4)));
    });
  });

  group('spend', () {
    test('sufficient resin decreases v and restarts the timer when under cap', () {
      final (state, event) = engine.spend(ResinState(v: 100, n: notDueYet), now, cost: 30);
      expect(state.v, 70);
      expect(state.n, now.add(r));
      expect(event, isA<ResinEventSpend>());
    });

    test('spending that still leaves v at or above cap keeps n null', () {
      final (state, _) = engine.spend(const ResinState(v: 250, n: null, cap: 200), now, cost: 10);
      expect(state.v, 240);
      expect(state.n, isNull);
    });

    test('operates on the projected value, not the stale anchor', () {
      final n = now.subtract(r * 29); // 29 whole ticks elapsed -> k == 30 -> v(now) == 130
      final state = ResinState(v: 100, n: n);
      expect(engine.v(state, now), 130);

      final (result, _) = engine.spend(state, now, cost: 30);
      expect(result.v, 100);
    });

    test('throws when projected resin is insufficient', () {
      expect(
        () => engine.spend(ResinState(v: 10, n: notDueYet), now, cost: 20),
        throwsA(isA<InsufficientResinException>()),
      );
    });
  });

  group('craftCondensed', () {
    test('sufficient resin decreases v and increases condensed inventory', () {
      final (state, event) = engine.craftCondensed(
        ResinState(v: 100, n: notDueYet),
        now,
        cost: 40,
      );
      expect(state.v, 60);
      expect(state.condensed, 1);
      expect(state.n, now.add(r));
      expect(event, isA<ResinEventCraftCondensed>());
    });

    test('throws when projected resin is insufficient', () {
      expect(
        () => engine.craftCondensed(ResinState(v: 10, n: notDueYet), now, cost: 40),
        throwsA(isA<InsufficientResinException>()),
      );
    });
  });

  group('useFragile', () {
    test('sufficient inventory increases v and decreases fragile count', () {
      final (state, event) = engine.useFragile(
        ResinState(v: 190, n: notDueYet, fragile: 2),
        now,
      );
      expect(state.v, 250); // 190 + 60, allowed to exceed cap
      expect(state.fragile, 1);
      expect(state.n, isNull); // 250 >= cap(200): resin above cap does not regenerate
      expect(event, isA<ResinEventUseFragile>());
    });

    test('throws when fragile inventory is insufficient', () {
      expect(
        () => engine.useFragile(const ResinState(v: 0, n: null, fragile: 0), now),
        throwsA(isA<InsufficientResinException>()),
      );
    });
  });

  group('useCondensed', () {
    test('sufficient inventory increases v by 40 per item and restarts the timer under cap', () {
      final (state, event) = engine.useCondensed(
        ResinState(v: 100, n: notDueYet, condensed: 3),
        now,
      );
      expect(state.v, 140);
      expect(state.condensed, 2);
      expect(state.n, now.add(r));
      expect(event, isA<ResinEventUseCondensed>());
    });

    test('throws when condensed inventory is insufficient', () {
      expect(
        () => engine.useCondensed(const ResinState(v: 0, n: null, condensed: 0), now),
        throwsA(isA<InsufficientResinException>()),
      );
    });
  });

  group('useTransient', () {
    test('consumes an unexpired batch entirely and increases v', () {
      final batch = TransientResinBatch(
        id: 'batch-1',
        count: 2,
        expiresAt: now.add(const Duration(days: 1)),
      );
      final state = ResinState(v: 100, n: notDueYet, transient: [batch]);

      final (result, event) = engine.useTransient(state, now, batchId: 'batch-1');

      expect(result.v, 220); // 100 + 60*2, allowed to exceed cap
      expect(result.transient, isEmpty);
      expect(result.n, isNull);
      expect(event, isA<ResinEventUseTransient>());
    });

    test('throws for an unknown batch id', () {
      expect(
        () => engine.useTransient(const ResinState(v: 0, n: null), now, batchId: 'missing'),
        throwsA(isA<InvalidTransientBatchException>()),
      );
    });

    test('throws for an already-expired batch', () {
      final batch = TransientResinBatch(
        id: 'batch-1',
        count: 1,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      final state = ResinState(v: 0, n: null, transient: [batch]);

      expect(
        () => engine.useTransient(state, now, batchId: 'batch-1'),
        throwsA(isA<InvalidTransientBatchException>()),
      );
    });
  });

  group('planningTotal', () {
    test('reduces to v(now) when there is no inventory', () {
      final state = ResinState(v: 120, n: notDueYet);
      expect(engine.planningTotal(state, now), 120);
    });

    test('adds condensed, fragile and unexpired transient resin', () {
      final state = ResinState(
        v: 100,
        n: notDueYet,
        condensed: 2,
        fragile: 1,
        transient: [
          TransientResinBatch(id: 'a', count: 1, expiresAt: now.add(const Duration(days: 1))),
          TransientResinBatch(id: 'b', count: 3, expiresAt: now.subtract(const Duration(days: 1))),
        ],
      );
      // 100 + 40*2 + 60*(1 + 1) = 300. Batch 'b' is expired and excluded.
      expect(engine.planningTotal(state, now), 300);
    });

    test('a batch expiring exactly at now is treated as expired', () {
      final state = ResinState(
        v: 0,
        n: notDueYet,
        transient: [TransientResinBatch(id: 'a', count: 1, expiresAt: now)],
      );
      expect(engine.planningTotal(state, now), 0);
    });
  });

  // ASSUMPTION TESTS (docs/ASSUMPTIONS.md): these pin the engine's current
  // guesses about two in-game mechanics nobody has verified. They document
  // behaviour under the named constants — they are not trusted fixtures,
  // and other tests must not rely on these behaviours as ground truth.
  group('unverified mechanics behind named constants', () {
    test('ASSUMPTION 1: spending below cap restarts the timer from zero', () {
      expect(ResinEngine.assumedTimerRestartsFromZeroOnReset, isTrue,
          reason: 'If this constant was flipped, update docs/ASSUMPTIONS.md and this group.');
      // Timer was mid-tick (due in 5 min); after spending, it restarts at
      // a full R rather than keeping the old phase.
      final (state, _) = engine.spend(ResinState(v: 100, n: notDueYet), now, cost: 20);
      expect(state.n, now.add(r));
    });

    test('ASSUMPTION 2: resin at or above cap does not regenerate', () {
      expect(ResinEngine.assumedNoRegenerationAboveCap, isTrue,
          reason: 'If this constant was flipped, update docs/ASSUMPTIONS.md and this group.');
      // Over-cap value from a fragile resin: no timer, value frozen even
      // a week later.
      final (state, _) = engine.useFragile(const ResinState(v: 180, n: null, fragile: 1), now);
      expect(state.v, 240);
      expect(state.n, isNull);
      expect(engine.v(state, now.add(const Duration(days: 7))), 240);
    });

    test('time travel: a device clock jumped backward never produces negative ticks', () {
      // The engine is a pure function of the queried instant; a query
      // before the anchor (clock set back) yields k == 0, not an error or
      // a negative projection.
      final state = ResinState(v: 100, n: now);
      final past = now.subtract(const Duration(days: 2));
      expect(engine.k(state, past), 0);
      expect(engine.v(state, past), 100);
      expect(engine.timeToThreshold(state, 150), now.add(r * 49));
    });

    test('time travel: a device clock jumped far forward just clamps at cap', () {
      final state = ResinState(v: 100, n: now);
      expect(engine.v(state, now.add(const Duration(days: 365))), state.cap);
    });
  });
}
