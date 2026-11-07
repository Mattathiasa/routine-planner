import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';

void main() {
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);
  const r = Duration(seconds: 480);

  group('ResinEngine.k', () {
    test('n == null -> 0', () {
      final state = ResinState(v: 200, n: null, cap: 200);
      expect(engine.k(state, now), 0);
    });

    test('now before n -> 0', () {
      final state = ResinState(v: 100, n: now.add(const Duration(minutes: 1)));
      expect(engine.k(state, now), 0);
    });

    test('now == n -> 1', () {
      final state = ResinState(v: 100, n: now);
      expect(engine.k(state, now), 1);
    });

    test('now == n + R - 1s -> still 1', () {
      final n = now.subtract(const Duration(seconds: 479));
      final state = ResinState(v: 100, n: n);
      expect(engine.k(state, now), 1);
    });

    test('now == n + R -> 2', () {
      final n = now.subtract(r);
      final state = ResinState(v: 100, n: n);
      expect(engine.k(state, now), 2);
    });
  });

  group('ResinEngine.v', () {
    test('adds pending ticks to the anchor', () {
      final n = now.subtract(r); // one full interval elapsed -> k == 2
      final state = ResinState(v: 100, n: n);
      expect(engine.v(state, now), 102);
    });

    test('clamps at cap even with many pending ticks', () {
      final n = now.subtract(const Duration(days: 30));
      final state = ResinState(v: 190, n: n, cap: 200);
      expect(engine.v(state, now), 200);
    });

    test('equals the anchor exactly at cap (n == null)', () {
      final state = ResinState(v: 200, n: null, cap: 200);
      expect(engine.v(state, now), 200);
    });

    test('does not clamp a legitimately over-cap value (n == null)', () {
      final state = ResinState(v: 250, n: null, cap: 200);
      expect(engine.v(state, now), 250);
    });
  });

  group('ResinEngine.timeToThreshold', () {
    test('null when already capped (n == null)', () {
      final state = ResinState(v: 200, n: null, cap: 200);
      expect(engine.timeToThreshold(state, 200), isNull);
    });

    test('null when threshold already met at anchor', () {
      final state = ResinState(v: 150, n: now);
      expect(engine.timeToThreshold(state, 150), isNull);
      expect(engine.timeToThreshold(state, 100), isNull);
    });

    test('null when threshold exceeds cap', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      expect(engine.timeToThreshold(state, 201), isNull);
    });

    test('exact arithmetic at a mid threshold', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      // t_T = n + (T - v - 1) * R, T = 150 -> 49 ticks needed.
      expect(engine.timeToThreshold(state, 150), now.add(r * 49));
    });

    test('exact arithmetic at cap', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      // T = cap = 200 -> 99 ticks needed.
      expect(engine.timeToThreshold(state, 200), now.add(r * 99));
    });

    test('cross-check against Sync(fullIn:)', () {
      const fullIn = Duration(minutes: 80);
      final (synced, _) = engine.sync(const ResinState(v: 0), now, x: 190, fullIn: fullIn);
      expect(engine.timeToThreshold(synced, synced.cap), now.add(fullIn));
    });
  });
}
