/// `"5:12"`-style countdown — no leading zero on minutes.
String formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  return '${clamped.inMinutes}:${(clamped.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// `"18:03"`-style 24h clock time. Every `DateTime` in this app is UTC
/// (see `core/clock`) — this reads the hour/minute as-is, no conversion.
String formatTime(DateTime utc) {
  return '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}
