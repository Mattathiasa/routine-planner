import 'resin_event.dart';
import 'resin_state.dart';

/// Thrown when a mutation needs more resin than is currently available.
class InsufficientResinException implements Exception {
  const InsufficientResinException(this.message);
  final String message;

  @override
  String toString() => 'InsufficientResinException: $message';
}

/// Thrown when a mutation references a transient resin batch that doesn't
/// exist or has already expired.
class InvalidTransientBatchException implements Exception {
  const InvalidTransientBatchException(this.message);
  final String message;

  @override
  String toString() => 'InvalidTransientBatchException: $message';
}

/// Pure-Dart resin regen/mutation engine. Resin is stored as an anchor
/// (`v`, `n`) rather than a ticking counter; every query/mutation here takes
/// an explicit `now` instead of a `Clock` so the engine stays trivially
/// pure — clock injection happens one layer up, in a future controller.
class ResinEngine {
  const ResinEngine({this.regenInterval = const Duration(seconds: 480)});

  /// `R`: seconds per +1 resin tick.
  final Duration regenInterval;

  /// Resin value of one condensed resin item once used.
  static const int condensedResinValue = 40;

  /// Resin value of one fragile or transient resin item once used.
  static const int fragileOrTransientResinValue = 60;

  /// `k(t) = floor((t - n) / R) + 1` if `n != null` and `t >= n`, else `0`.
  int k(ResinState state, DateTime now) {
    final n = state.n;
    if (n == null || now.isBefore(n)) return 0;
    final elapsedTicks = now.difference(n).inSeconds ~/ regenInterval.inSeconds;
    return elapsedTicks + 1;
  }

  /// `v(t) = min(cap, v + k(t))` while regen is active; once `n == null`
  /// there are no pending ticks (`k` is always `0`), so the stored value is
  /// returned as-is — including when it's legitimately above cap from
  /// using Condensed/Fragile/Transient resin. The `min` only ever needs to
  /// guard against a large elapsed-tick count overshooting cap while a
  /// regen is actively in progress.
  int v(ResinState state, DateTime now) {
    if (state.n == null) return state.v;
    final projected = state.v + k(state, now);
    return projected > state.cap ? state.cap : projected;
  }

  /// Time at which `v(t)` first reaches [threshold], computed from the
  /// anchor (`t_T = n + (T - v - 1) * R`); `null` if already capped
  /// (`n == null`), already met at the anchor, or unreachable via regen
  /// alone (`threshold > cap`).
  DateTime? timeToThreshold(ResinState state, int threshold) {
    final n = state.n;
    if (n == null) return null;
    if (threshold <= state.v) return null;
    if (threshold > state.cap) return null;
    final ticksNeeded = threshold - state.v - 1;
    return n.add(regenInterval * ticksNeeded);
  }

  /// `E = v(t) + 40*condensed + 60*(fragile + sum of unexpired transient)`.
  int planningTotal(ResinState state, DateTime now) {
    var unexpiredTransient = 0;
    for (final batch in state.transient) {
      if (batch.expiresAt.isAfter(now)) unexpiredTransient += batch.count;
    }
    return v(state, now) +
        condensedResinValue * state.condensed +
        fragileOrTransientResinValue * (state.fragile + unexpiredTransient);
  }

  /// Timer restarts from zero (`now + R`) while still under cap; no timer
  /// (`null`) once at or above cap — resin above cap does not regenerate.
  DateTime? _reanchor(int newV, int cap, DateTime now) {
    return newV >= cap ? null : now.add(regenInterval);
  }

  /// Reads `x` straight from the in-game UI. With [fullIn] (an in-game
  /// "full in" countdown), `n` is derived exactly from the threshold
  /// formula; without it, `n` defaults to `now + R/2` — the expected wait
  /// if the tick phase is unknown (inherently uncertain by ±R/2 = 4 min).
  (ResinState, ResinEvent) sync(
    ResinState state,
    DateTime now, {
    required int x,
    Duration? fullIn,
  }) {
    final cap = state.cap;
    final DateTime? n;
    if (x >= cap) {
      n = null;
    } else if (fullIn != null) {
      n = now.add(fullIn).subtract(regenInterval * (cap - x - 1));
    } else {
      n = now.add(Duration(seconds: regenInterval.inSeconds ~/ 2));
    }
    final newState = state.copyWith(v: x, n: n);
    final event = ResinEvent.sync(occurredAt: now, x: x, fullIn: fullIn);
    return (newState, event);
  }

  /// Spends [cost] resin on a run, projecting to [now] first so pending
  /// regen ticks aren't lost.
  (ResinState, ResinEvent) spend(ResinState state, DateTime now, {required int cost}) {
    final projected = v(state, now);
    if (projected < cost) {
      throw InsufficientResinException('Need $cost resin but only $projected available.');
    }
    final newV = projected - cost;
    final newState = state.copyWith(v: newV, n: _reanchor(newV, state.cap, now));
    final event = ResinEvent.spend(occurredAt: now, cost: cost);
    return (newState, event);
  }

  /// Converts [cost] raw resin into [amount] condensed resin items.
  (ResinState, ResinEvent) craftCondensed(
    ResinState state,
    DateTime now, {
    required int cost,
    int amount = 1,
  }) {
    final projected = v(state, now);
    if (projected < cost) {
      throw InsufficientResinException(
        'Need $cost resin to craft condensed resin but only $projected available.',
      );
    }
    final newV = projected - cost;
    final newState = state.copyWith(
      v: newV,
      n: _reanchor(newV, state.cap, now),
      condensed: state.condensed + amount,
    );
    final event = ResinEvent.craftCondensed(occurredAt: now, cost: cost, amount: amount);
    return (newState, event);
  }

  /// Converts [amount] fragile resin items into raw resin (may push `v`
  /// above cap, matching the real game).
  (ResinState, ResinEvent) useFragile(ResinState state, DateTime now, {int amount = 1}) {
    if (state.fragile < amount) {
      throw InsufficientResinException('Only ${state.fragile} fragile resin available, need $amount.');
    }
    final newV = v(state, now) + fragileOrTransientResinValue * amount;
    final newState = state.copyWith(
      v: newV,
      n: _reanchor(newV, state.cap, now),
      fragile: state.fragile - amount,
    );
    final event = ResinEvent.useFragile(occurredAt: now, amount: amount);
    return (newState, event);
  }

  /// Converts [amount] condensed resin items into raw resin (may push `v`
  /// above cap, matching the real game).
  (ResinState, ResinEvent) useCondensed(ResinState state, DateTime now, {int amount = 1}) {
    if (state.condensed < amount) {
      throw InsufficientResinException('Only ${state.condensed} condensed resin available, need $amount.');
    }
    final newV = v(state, now) + condensedResinValue * amount;
    final newState = state.copyWith(
      v: newV,
      n: _reanchor(newV, state.cap, now),
      condensed: state.condensed - amount,
    );
    final event = ResinEvent.useCondensed(occurredAt: now, amount: amount);
    return (newState, event);
  }

  /// Converts an entire unexpired transient resin batch into raw resin.
  (ResinState, ResinEvent) useTransient(ResinState state, DateTime now, {required String batchId}) {
    TransientResinBatch? batch;
    for (final candidate in state.transient) {
      if (candidate.id == batchId) {
        batch = candidate;
        break;
      }
    }
    if (batch == null) {
      throw InvalidTransientBatchException('No transient resin batch with id "$batchId".');
    }
    if (!batch.expiresAt.isAfter(now)) {
      throw InvalidTransientBatchException('Transient resin batch "$batchId" has expired.');
    }
    final newV = v(state, now) + fragileOrTransientResinValue * batch.count;
    final newState = state.copyWith(
      v: newV,
      n: _reanchor(newV, state.cap, now),
      transient: state.transient.where((b) => b.id != batchId).toList(),
    );
    final event = ResinEvent.useTransient(occurredAt: now, batchId: batchId, count: batch.count);
    return (newState, event);
  }
}
