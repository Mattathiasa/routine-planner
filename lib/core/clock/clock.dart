/// A source of the current instant, injected everywhere instead of calling
/// `DateTime.now()` directly so that domain and app code stay deterministic
/// and testable.
abstract class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();
}
