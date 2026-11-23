import 'package:freezed_annotation/freezed_annotation.dart';

import 'wish_banner.dart';

part 'wish_pull.freezed.dart';

/// One wish, as the game's wish-history endpoint reports it.
///
/// Pure Dart apart from freezed; no Flutter/Riverpod/Drift imports.
///
/// Field names in the raw JSON are community-sourced and unverified
/// (docs/ASSUMPTIONS.md), so parsing is tolerant everywhere it can be: the
/// endpoint serialises numbers as strings (`rank_type: "5"`,
/// `gacha_type: "301"`), and a record whose banner code we don't recognise is
/// skipped rather than fatal.
@freezed
abstract class WishPull with _$WishPull {
  const factory WishPull({
    /// The upstream snowflake id. Monotonically increasing, so it is both the
    /// ordering key and the dedupe key for re-imports — which is why it, and
    /// not a generated uuid, is the primary key in `wish_pulls`.
    required String id,
    required WishBanner banner,
    required String itemName,
    required WishItemKind kind,
    required int rarity,

    /// Converted to UTC on parse. The endpoint reports wall-clock time on the
    /// account's own server with no offset attached, so the caller supplies
    /// that offset — the same reason nothing in this app uses the phone clock
    /// for day logic.
    required DateTime pulledAtUtc,
  }) = _WishPull;
}

enum WishItemKind { character, weapon }

/// Thrown when a record is structurally unusable — missing the id, name or
/// rarity that every row must have.
class WishPullFormatException implements Exception {
  const WishPullFormatException(this.message);

  final String message;

  @override
  String toString() => 'WishPullFormatException: $message';
}

/// Parses the `data.list` array of a `getGachaLog` response.
///
/// [serverOffset] is the account's server offset (`GameServer.utcOffset`),
/// used to turn the endpoint's server-local timestamps into UTC.
///
/// Records with an unrecognised `gacha_type` are skipped: a banner added
/// upstream in a future patch must not break the import. Records missing a
/// required field throw, because that means the response isn't what we think
/// it is.
List<WishPull> parseWishPulls(
  List<Object?> list, {
  required Duration serverOffset,
}) {
  final out = <WishPull>[];
  for (final entry in list) {
    if (entry is! Map) continue;

    final gachaType = _asInt(entry['gacha_type']);
    if (gachaType == null) {
      throw WishPullFormatException(
        'Expected int (or numeric string) gacha_type, got: $entry',
      );
    }
    final banner = WishBanner.fromGachaType(gachaType);
    if (banner == null) continue;

    final id = _asString(entry['id']);
    final name = _asString(entry['name']);
    final rarity = _asInt(entry['rank_type']);
    final time = _asString(entry['time']);
    if (id == null || name == null || rarity == null || time == null) {
      throw WishPullFormatException(
        'Expected id/name/rank_type/time on every record, got: $entry',
      );
    }

    out.add(
      WishPull(
        id: id,
        banner: banner,
        itemName: name,
        kind: _kindOf(entry['item_type']),
        rarity: rarity,
        pulledAtUtc: _serverLocalToUtc(time, serverOffset),
      ),
    );
  }
  return out;
}

/// `item_type` is a localised string ('Character'/'Weapon'). The import forces
/// `lang=en`, so matching the English word is safe; anything else is treated
/// as a weapon only after the character check fails, and a rarity-aware
/// caller can still render it.
WishItemKind _kindOf(Object? raw) {
  return '$raw'.toLowerCase().contains('character')
      ? WishItemKind.character
      : WishItemKind.weapon;
}

/// `time` is `YYYY-MM-DD HH:mm:ss` on the account's own server, with no zone.
DateTime _serverLocalToUtc(String raw, Duration serverOffset) {
  final normalised = raw.trim().replaceFirst(' ', 'T');
  final DateTime wallClock;
  try {
    // Parsed as UTC so no device timezone can touch it, then shifted by the
    // server's offset to get the real instant.
    wallClock = DateTime.parse('${normalised}Z');
  } on FormatException {
    throw WishPullFormatException('Unparseable time: $raw');
  }
  return wallClock.subtract(serverOffset);
}

String? _asString(Object? raw) {
  if (raw == null) return null;
  final text = raw is String ? raw.trim() : '$raw';
  return text.isEmpty ? null : text;
}

/// HoYoverse endpoints serialise numbers as JSON strings about half the time.
int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}
