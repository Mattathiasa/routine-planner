/// HoYoLab's "dynamic secret" (`ds`) request-signing scheme, reverse
/// engineered by the community and verified here against
/// `thesadru/genshin.py` (an actively-maintained open-source client) —
/// not an officially documented API. No Flutter/network imports: the
/// signing math itself is pure, mirroring every other domain module in
/// this app; [dynamicSecretForNow] is the one thin, impure edge that
/// supplies real time/randomness, the same Clock-injection split used
/// everywhere else.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The overseas (non-mainland-China) salt HoYoverse's web/app clients use
/// to sign `dailyNote` and similar `game_record` requests. Confirmed
/// current as of a Nov 2026 commit to `thesadru/genshin.py` — if HoYoverse
/// ever rotates it, every unofficial client (this one included) breaks
/// until someone finds the new value; there is no graceful fallback for
/// that, by the nature of reverse-engineered signing.
const overseasDsSalt = '6s25p5ox5y14umn1p61aqyyvbvvl3lrt';

const _asciiLetters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// `"{t},{r},{md5("salt={salt}&t={t}&r={r}")}"` — the exact format
/// HoYoLab's own clients send as the `ds` header.
String dynamicSecret({required String salt, required int unixSeconds, required String random}) {
  final hash = md5.convert(utf8.encode('salt=$salt&t=$unixSeconds&r=$random')).toString();
  return '$unixSeconds,$random,$hash';
}

/// [dynamicSecret] using the real clock and a fresh 6-letter random
/// string, the way every real request needs it. Not unit-tested itself
/// (there's nothing to assert beyond "calls the pure function," the same
/// reasoning `SystemClock` is never tested beyond what `FakeClock`-based
/// tests already cover) — [dynamicSecret] carries the real logic.
String dynamicSecretForNow(String salt) {
  final random = Random();
  final letters = String.fromCharCodes(
    List.generate(6, (_) => _asciiLetters.codeUnitAt(random.nextInt(_asciiLetters.length))),
  );
  return dynamicSecret(
    salt: salt,
    unixSeconds: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    random: letters,
  );
}
