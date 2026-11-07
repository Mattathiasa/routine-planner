import 'clock.dart';

/// The only [Clock] implementation allowed to call `DateTime.now()`. Every
/// other class — especially domain code — takes a [Clock] instead.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
