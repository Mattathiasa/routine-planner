// Dart forbids named parameters that start with an underscore, so private
// fields fed by named constructor params must go through an initializer list;
// the lint's suggested fix doesn't compile here.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/clock/clock.dart';
import '../../../core/hoyolab/data/gacha_log_client.dart';
import '../domain/gacha_url.dart';
import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';
import 'wish_repository.dart';

/// How long to wait between pages.
///
/// The endpoint rate-limits (retcode -110) and this is an unofficial API, so
/// the importer stays deliberately unhurried — a first import of a full
/// history is a handful of seconds either way.
const gachaLogPageDelay = Duration(milliseconds: 400);

/// A ceiling on pages per banner, so a misbehaving upstream (a cursor that
/// never advances) can't spin forever. 400 pages is 8000 wishes on one
/// banner — far more than the ~6-month window upstream keeps.
const gachaLogMaxPagesPerBanner = 400;

/// What an import did. No exceptions escape: a failure is reported so the UI
/// can show it alongside whatever did get imported, the same contract as
/// `AccountRefreshOutcome`.
typedef WishImportOutcome = ({
  /// Pulls stored that weren't already known.
  int imported,

  /// Records read from upstream, including ones already stored.
  int scanned,
  String? error,
});

/// Imports an account's wish history, newest first, stopping as soon as it
/// reaches what's already stored.
///
/// The authkey is never persisted. It expires in about a day, so storing it
/// would buy nothing and add a credential to protect — it lives only for the
/// duration of one [importAll] call. See `docs/ARCHITECTURE.md`.
class WishImportService {
  WishImportService({
    required GachaLogClient client,
    required WishRepository repository,
    required Clock clock,
    Duration pageDelay = gachaLogPageDelay,
  }) : _client = client,
       _repository = repository,
       _clock = clock,
       _pageDelay = pageDelay;

  final GachaLogClient _client;
  final WishRepository _repository;
  final Clock _clock;
  final Duration _pageDelay;

  /// Walks every banner for one account.
  ///
  /// [serverOffset] is that account's `GameServer.utcOffset`, used to turn the
  /// endpoint's server-local timestamps into UTC.
  ///
  /// Each page is persisted as it arrives, so a failure halfway through keeps
  /// everything read up to that point rather than discarding the lot.
  Future<WishImportOutcome> importAll({
    required String profileId,
    required GachaAuth auth,
    required Duration serverOffset,
  }) async {
    // Progress lives outside the try so a failure part-way through still
    // reports everything already stored — each page is persisted as it
    // arrives, so that work is real.
    final progress = _Progress();

    // Marks are read once, up front, for the whole run. Reading them per
    // banner inside the loop would break the character banner's second code
    // (400): importing 301 first advances the shared character mark, and the
    // older 400 records would then look already-known on a very first
    // import.
    final marks = <WishBanner, String?>{};
    try {
      for (final banner in WishBanner.values) {
        marks[banner] = await _repository.lastImportedId(profileId, banner);
      }

      for (final gachaType in WishBanner.queryableGachaTypes) {
        final banner = WishBanner.fromGachaType(gachaType);
        if (banner == null) continue;

        await _importBanner(
          profileId: profileId,
          auth: auth,
          gachaType: gachaType,
          // The character banner's two codes share one mark: ids are
          // monotonic in time across codes, so "newer than the newest
          // character pull we already have" is exactly the set of new
          // character pulls, whichever code served them.
          highWaterMark: marks[banner],
          serverOffset: serverOffset,
          progress: progress,
        );
      }
      return (
        imported: progress.imported,
        scanned: progress.scanned,
        error: null,
      );
    } on GachaLogException catch (e) {
      return progress.failed(e.message);
    } on WishPullFormatException catch (e) {
      return progress.failed(
        'The wish history response did not match what this app expects: '
        '${e.message}',
      );
    } on SocketException {
      return progress.failed(_offlineMessage);
    } on http.ClientException {
      return progress.failed(_offlineMessage);
    } on TimeoutException {
      return progress.failed(_offlineMessage);
    }
  }

  Future<void> _importBanner({
    required String profileId,
    required GachaAuth auth,
    required int gachaType,
    required String? highWaterMark,
    required Duration serverOffset,
    required _Progress progress,
  }) async {
    var endId = '0';
    var page = 1;

    while (page <= gachaLogMaxPagesPerBanner) {
      if (page > 1) await Future<void>.delayed(_pageDelay);

      final records = await _client.fetchPage(
        auth: auth,
        gachaType: gachaType,
        page: page,
        endId: endId,
      );
      if (records.isEmpty) break;
      progress.scanned += records.length;

      final pulls = parseWishPulls(records, serverOffset: serverOffset);
      // Records arrive newest first, so the last one is the oldest and
      // becomes the cursor for the next page.
      endId = '${records.last['id']}';

      final fresh = highWaterMark == null
          ? pulls
          : [
              for (final pull in pulls)
                if (_idIsNewer(pull.id, highWaterMark)) pull,
            ];

      if (fresh.isNotEmpty) {
        progress.imported += await _repository.insertPulls(
          profileId,
          fresh,
          now: _clock.nowUtc(),
        );
      }

      // Reached history we already have: everything older is known too.
      if (fresh.length < pulls.length) break;

      page++;
    }
  }

  static const _offlineMessage =
      "Couldn't reach the wish history service — nothing was imported.";
}

/// Mutable running totals, so partial progress survives a mid-import failure.
class _Progress {
  int imported = 0;
  int scanned = 0;

  WishImportOutcome failed(String error) =>
      (imported: imported, scanned: scanned, error: error);
}

/// Snowflake ids are decimal numbers too long for an int, but fixed-width in
/// practice, so length-then-lexicographic ordering is correct and cheap.
bool _idIsNewer(String candidate, String current) {
  if (candidate.length != current.length) {
    return candidate.length > current.length;
  }
  return candidate.compareTo(current) > 0;
}
