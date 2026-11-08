import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';
import 'package:routine_planner/features/resin/presentation/resin_formatting.dart';

void main() {
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);

  group('resinCapTimers', () {
    test('a genuinely full state (n == null) has no timers', () {
      final state = ResinState(v: 200, n: null, cap: 200);
      final timers = resinCapTimers(engine: engine, state: state, now: now);
      expect(timers.nextTick, isNull);
      expect(timers.fullAt, isNull);
    });

    test('a not-yet-full state keeps its real anchor and threshold time', () {
      final n = now.add(const Duration(minutes: 3));
      final state = ResinState(v: 180, n: n, cap: 200);
      final timers = resinCapTimers(engine: engine, state: state, now: now);
      expect(timers.nextTick, n);
      expect(timers.fullAt, engine.timeToThreshold(state, state.cap));
    });

    test('a stale anchor — real elapsed time already projects v to cap, '
        'but the stored anchor was never refreshed by a mutation — reports '
        'no pending timer instead of a nonsensical past/zero one', () {
      // Anchor says v=190 as of 3 days ago; `engine.v(state, now)` will
      // have long since projected past cap even though `state.n` (and
      // `timeToThreshold`, purely anchor-based) still point at a tick
      // that, by `now`, has already happened.
      final staleN = now.subtract(const Duration(days: 3));
      final state = ResinState(v: 190, n: staleN, cap: 200);

      // Sanity-check the premise: the raw engine calls alone really would
      // produce a stale, already-elapsed "next tick"/"full at".
      expect(engine.v(state, now), 200);
      expect(engine.timeToThreshold(state, state.cap)!.isBefore(now), isTrue);

      final timers = resinCapTimers(engine: engine, state: state, now: now);
      expect(timers.nextTick, isNull);
      expect(timers.fullAt, isNull);
    });
  });
}
