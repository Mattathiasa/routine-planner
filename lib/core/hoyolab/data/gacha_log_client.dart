import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../features/wishes/domain/gacha_url.dart';

/// The authkey has aged out. They last around a day, so this is the common
/// failure and gets the clearest instruction.
const _expiredAuthkeyRetcode = -101;

/// The authkey is malformed or wasn't accepted at all.
const _invalidAuthkeyRetcode = -100;

/// Paging too fast. The importer already spaces its requests, but a second
/// import started by hand can still trip this.
const _tooFrequentRetcode = -110;

/// Upstream's own page ceiling. 20 is the largest page it will serve.
const gachaLogMaxPageSize = 20;

class GachaLogException implements Exception {
  const GachaLogException(this.message, {this.retryable = false});

  final String message;

  /// True when waiting and trying again is the right response (rate limits),
  /// as opposed to needing a fresh link.
  final bool retryable;

  @override
  String toString() => 'GachaLogException: $message';
}

/// Reads a player's wish history from the game's own `getGachaLog` endpoint.
///
/// This is the only source of wish history that exists: no HoYoLab cookie
/// endpoint exposes it. Authentication is the short-lived `authkey` carried in
/// the link the game's wish-history webview hands out — never a login
/// credential, and deliberately never persisted (see
/// `wish_import_service.dart`).
///
/// Unofficial and reverse-engineered, exactly like `dailyNote`; see
/// `docs/ARCHITECTURE.md` for the caveat and the disclaimer gate in front of
/// it. No DS signing is involved — that's a HoYoLab-API mechanism, and this
/// endpoint doesn't use it.
///
/// Takes an injectable [http.Client] so tests never hit the real network.
class GachaLogClient {
  GachaLogClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// One page of history for one `gacha_type`, newest first.
  ///
  /// Pages are walked backwards with [endId]: pass the id of the oldest record
  /// seen so far, or `'0'` to start at the newest. An empty list means the end
  /// of that banner's history.
  ///
  /// [auth] carries the endpoint's own host and path (taken from the pasted
  /// link, never hardcoded — see `parseGachaUrl`); only the query is built
  /// here.
  Future<List<Map<String, Object?>>> fetchPage({
    required GachaAuth auth,
    required int gachaType,
    int page = 1,
    String endId = '0',
    int size = gachaLogMaxPageSize,
  }) async {
    final uri = auth.baseUrl.replace(
      queryParameters: {
        'authkey_ver': auth.authkeyVer,
        'sign_type': auth.signType,
        'auth_appid': 'webview_gacha',
        // Forced, not taken from the link: the catalog's names are English,
        // and matching them is what lets a pull show its rarity and element.
        'lang': 'en',
        'authkey': auth.authkey,
        'gacha_type': '$gachaType',
        'page': '$page',
        'size': '$size',
        'end_id': endId,
      },
    );

    final response = await _http.get(uri);

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw GachaLogException(
        'The wish history service returned a non-JSON response '
        '(HTTP ${response.statusCode}): ${_truncate(response.body)}',
      );
    }

    final retcode = body['retcode'];
    if (retcode != 0) {
      throw GachaLogException(
        _messageFor(retcode, body['message']),
        retryable: retcode == _tooFrequentRetcode,
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw GachaLogException(
        'The wish history service returned no usable data '
        '(retcode 0, data: $data).',
      );
    }

    final list = data['list'];
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map) entry.cast<String, Object?>(),
    ];
  }

  String _truncate(String text, {int maxLength = 200}) =>
      text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

  String _messageFor(Object? retcode, Object? message) {
    if (retcode == _expiredAuthkeyRetcode) {
      return 'That wish history link has expired. Open wish history in the game '
          'again, copy the link and paste it here.';
    }
    if (retcode == _invalidAuthkeyRetcode) {
      return "That link wasn't accepted. Make sure you copied the whole wish "
          'history link, straight from the game.';
    }
    if (retcode == _tooFrequentRetcode) {
      return 'The wish history service is asking us to slow down. Wait a minute, '
          'then try again.';
    }
    if (message is String && message.isNotEmpty) return message;
    return 'Wish history request failed (code $retcode).';
  }
}
