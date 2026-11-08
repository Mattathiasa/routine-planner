import '../domain/resin_engine.dart';
import '../domain/resin_state.dart';

/// Guards `state.n`/`ResinEngine.timeToThreshold` against a stale anchor:
/// both are purely anchor-based, so once enough real time has passed to
/// project `v` to cap without any mutation ever re-anchoring the stored
/// state, they can still point at a tick that's already happened — reading
/// as a live "+1 in 0:00" or a past "Full at" time instead of "no pending
/// tick." Guarding on the projected value rather than the raw anchor fixes
/// that, shared by every screen that renders these two values.
({DateTime? nextTick, DateTime? fullAt}) resinCapTimers({
  required ResinEngine engine,
  required ResinState state,
  required DateTime now,
}) {
  final atCap = engine.v(state, now) >= state.cap;
  return (
    nextTick: atCap ? null : state.n,
    fullAt: atCap ? null : engine.timeToThreshold(state, state.cap),
  );
}

/// `"5:12"`-style countdown — no leading zero on minutes.
String formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  return '${clamped.inMinutes}:${(clamped.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// `"18:03"`-style 24h clock time. Every `DateTime` in this app is UTC
/// (see `core/clock`) — this reads the hour/minute as-is, no conversion.
String formatTime(DateTime utc) {
  return '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}
