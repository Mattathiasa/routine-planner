import '../../../core/clock/fake_clock.dart';
import '../../../core/clock/game_server.dart';
import '../../../core/clock/server_clock.dart';

/// The Game-server picker's "resets HH:MM [the day before]" caption, in
/// the viewer's own local time — never hardcode a particular city/offset
/// (the approved mock's "Addis Ababa" is sample data).
///
/// [localOffset] is injected rather than read internally via
/// `DateTime.now().timeZoneOffset`, keeping this hermetically testable
/// like every other pure-domain helper in this codebase.
({String time, bool dayBefore}) resetCaption({
  required GameServer server,
  required DateTime nowUtc,
  required Duration localOffset,
}) {
  final serverClock = ServerClock(FakeClock(nowUtc), server);
  final resetUtc = serverClock.dayStartUtc(nowUtc);
  final resetLocal = resetUtc.add(localOffset);
  final nowLocal = nowUtc.add(localOffset);

  final resetLocalDate = DateTime.utc(resetLocal.year, resetLocal.month, resetLocal.day);
  final nowLocalDate = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);

  return (
    time:
        '${resetLocal.hour.toString().padLeft(2, '0')}:'
        '${resetLocal.minute.toString().padLeft(2, '0')}',
    dayBefore: resetLocalDate.isBefore(nowLocalDate),
  );
}
