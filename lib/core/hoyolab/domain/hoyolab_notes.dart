/// Parses the `data` object of a HoYoLab `dailyNote` response. Field names
/// match the raw JSON HoYoLab returns (verified against
/// `thesadru/genshin.py`'s `chronicle/genshin.py`), not a prettified
/// wrapper — this app only reads the 3 fields `ResinEngine.sync` needs.
library;

typedef HoyolabNotes = ({int currentResin, int maxResin, int secondsUntilFull});

/// Thrown when a `dailyNote` response's `data` object is missing a field
/// this app relies on — a genuinely unexpected API shape, not a normal
/// error path (those come back as a non-zero `retcode`, handled by
/// [HoyolabClient] before this function ever runs).
class HoyolabNotesFormatException implements Exception {
  const HoyolabNotesFormatException(this.message);
  final String message;

  @override
  String toString() => 'HoyolabNotesFormatException: $message';
}

HoyolabNotes parseHoyolabNotes(Map<String, dynamic> json) {
  final currentResin = json['current_resin'];
  final maxResin = json['max_resin'];
  final secondsUntilFull = json['resin_recovery_time'];
  if (currentResin is! int || maxResin is! int || secondsUntilFull is! int) {
    throw HoyolabNotesFormatException(
      'Expected int current_resin/max_resin/resin_recovery_time, got: $json',
    );
  }
  return (currentResin: currentResin, maxResin: maxResin, secondsUntilFull: secondsUntilFull);
}
