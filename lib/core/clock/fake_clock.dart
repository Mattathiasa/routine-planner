import 'clock.dart';

/// A [Clock] double for tests: starts at a fixed instant and only moves when
/// told to.
class FakeClock implements Clock {
  FakeClock(DateTime initialUtc) : _now = initialUtc.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Jumps directly to [utc].
  void set(DateTime utc) => _now = utc.toUtc();

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _now = _now.add(duration);
}
