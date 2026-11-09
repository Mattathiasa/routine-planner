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

/// HoYoLab serializes these 3 fields as JSON strings (e.g. `"128"`), not
/// JSON numbers, even though they're purely numeric — observed on a real
/// `dailyNote` response. [int]'s own `toString()` and a numeric string's
/// are identical, so this only showed up once a real response was logged,
/// not from the field names/shape alone.
int? _asInt(Object? value) => switch (value) {
  int v => v,
  String v => int.tryParse(v),
  _ => null,
};

HoyolabNotes parseHoyolabNotes(Map<String, dynamic> json) {
  final currentResin = _asInt(json['current_resin']);
  final maxResin = _asInt(json['max_resin']);
  final secondsUntilFull = _asInt(json['resin_recovery_time']);
  if (currentResin == null || maxResin == null || secondsUntilFull == null) {
    throw HoyolabNotesFormatException(
      'Expected int (or numeric string) current_resin/max_resin/resin_recovery_time, got: $json',
    );
  }
  return (currentResin: currentResin, maxResin: maxResin, secondsUntilFull: secondsUntilFull);
}
