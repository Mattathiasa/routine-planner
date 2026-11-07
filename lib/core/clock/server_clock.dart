import 'clock.dart';
import 'game_server.dart';

/// Computes the in-game "server date" for a [GameServer], whose day resets
/// at 04:00 server time rather than midnight. Never derive day boundaries
/// from the phone's local clock — everything goes through here.
class ServerClock {
  const ServerClock(this._clock, this.server);

  final Clock _clock;
  final GameServer server;

  static const _dailyResetOffset = Duration(hours: 4);

  /// The current instant, in UTC, from the injected [Clock].
  DateTime nowUtc() => _clock.nowUtc();

  /// The server-local calendar date right now.
  DateTime serverDate() => serverDateFor(_clock.nowUtc());

  /// The server-local calendar date for an arbitrary UTC instant:
  /// `date(t_utc + offset - 4h)`.
  DateTime serverDateFor(DateTime utc) {
    final shifted = utc.add(server.utcOffset).subtract(_dailyResetOffset);
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }
}
