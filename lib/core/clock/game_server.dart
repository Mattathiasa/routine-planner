/// The game's regional servers, each with a fixed UTC offset used to compute
/// the server-local calendar day.
enum GameServer {
  asia(Duration(hours: 8)),
  europe(Duration(hours: 1)),
  america(Duration(hours: -5)),
  twHkMo(Duration(hours: 8));

  const GameServer(this.utcOffset);

  /// Fixed offset from UTC for this server (no daylight saving changes).
  final Duration utcOffset;
}
