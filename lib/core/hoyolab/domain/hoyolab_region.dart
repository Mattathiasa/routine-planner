/// HoYoLab's `dailyNote` `server` parameter must match the region encoded
/// in the player's own UID — it is not the same thing as this app's
/// Settings → "Game server" choice (used for server-day reset math), and
/// the two can disagree. Sending a mismatched `server` doesn't come back
/// as a clear "wrong server" error: HoYoLab answers with a generic
/// "missing information" rejection (retcode 1005) that reads like a
/// broken account rather than a bad parameter. Deriving `server` from the
/// UID itself, the way HoYoLab's own clients do, avoids the mismatch
/// entirely.
library;

class UnknownHoyolabUidException implements Exception {
  const UnknownHoyolabUidException(this.uid);
  final String uid;

  String get message =>
      "UID $uid doesn't match a known overseas Genshin server. Expected a UID "
      'starting with 6 (America), 7 (Europe), 8 or 18 (Asia), or 9 (TW, HK, MO).';

  @override
  String toString() => 'UnknownHoyolabUidException: $message';
}

String hoyolabRegionForUid(String uid) {
  final trimmed = uid.trim();
  if (trimmed.length <= 8) throw UnknownHoyolabUidException(uid);

  final prefix = trimmed.substring(0, trimmed.length - 8);
  return switch (prefix) {
    '6' => 'os_usa',
    '7' => 'os_euro',
    '8' || '18' => 'os_asia',
    '9' => 'os_cht',
    _ => throw UnknownHoyolabUidException(uid),
  };
}
