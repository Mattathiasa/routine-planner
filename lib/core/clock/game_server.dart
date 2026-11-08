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

/// Human-readable labels matching the approved design (`.name` alone gives
/// e.g. `'twHkMo'`, not display-ready).
extension GameServerDisplay on GameServer {
  String get label => switch (this) {
    GameServer.asia => 'Asia',
    GameServer.europe => 'Europe',
    GameServer.america => 'America',
    GameServer.twHkMo => 'TW, HK, MO',
  };
}

/// HoYoLab's `region` query parameter values for each server.
extension GameServerHoyolab on GameServer {
  String get hoyolabRegion => switch (this) {
    GameServer.asia => 'os_asia',
    GameServer.europe => 'os_euro',
    GameServer.america => 'os_usa',
    GameServer.twHkMo => 'os_cht',
  };
}
