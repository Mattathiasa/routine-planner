import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/diary_month.dart';
import '../domain/hoyolab_signing.dart';

/// Retcodes that mean "this login isn't good enough for the diary".
///
/// The diary needs a different cookie from the one `dailyNote` runs on, and
/// the login WebView may not hand one back — this is the single most likely
/// way this feature fails, so it gets its own exception type rather than a
/// generic message. See [DiaryUnauthorizedException].
const _unauthorizedRetcodes = {-100, 10001};

class DiaryException implements Exception {
  const DiaryException(this.message);

  final String message;

  @override
  String toString() => 'DiaryException: $message';
}

/// The diary rejected the stored login.
///
/// Separate from [DiaryException] so callers can degrade cleanly: primogem
/// tracking keeps working on the manual anchor and projection, and resin sync
/// — which uses a different endpoint and a cookie that does work — is never
/// affected.
class DiaryUnauthorizedException implements Exception {
  const DiaryUnauthorizedException(this.message);

  final String message;

  @override
  String toString() => 'DiaryUnauthorizedException: $message';
}

/// Reads one month of the Traveler's Diary for one account.
///
/// Unofficial and reverse-engineered, like the rest of the HoYoLab
/// integration, and behind the same per-account opt-in. See
/// `docs/ARCHITECTURE.md`.
class TravelerDiaryClient {
  TravelerDiaryClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<DiaryMonth> fetchMonth({
    required String cookie,
    required String uid,
    required String region,
    required String month,
  }) async {
    final uri = Uri.https('sg-hk4e-api.hoyolab.com', '/event/ysledgeros/month_info', {
      'region': region,
      'uid': uid,
      // Upstream wants the month as a bare number, not YYYY-MM.
      'month': _monthNumberOf(month),
      'lang': 'en-us',
    });

    final response = await _http.get(
      uri,
      headers: {
        'Cookie': cookie,
        // Sent for parity with the notes client. The diary has not been seen
        // to require a signature, and an extra header it ignores is harmless.
        'ds': dynamicSecretForNow(overseasDsSalt),
        'x-rpc-app_version': '1.5.0',
        'x-rpc-client_type': '5',
        'x-rpc-language': 'en-us',
      },
    );

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw DiaryException(
        "The Traveler's Diary returned a non-JSON response "
        '(HTTP ${response.statusCode}): ${_truncate(response.body)}',
      );
    }

    final retcode = body['retcode'];
    if (retcode != 0) {
      if (retcode is int && _unauthorizedRetcodes.contains(retcode)) {
        throw const DiaryUnauthorizedException(
          "HoYoLab didn't accept this login for the Traveler's Diary. "
          'Reconnect the account, or top your balance up by hand.',
        );
      }
      throw DiaryException(_messageFor(retcode, body['message']));
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw DiaryException(
        "The Traveler's Diary returned no usable data "
        '(retcode 0, data: $data).',
      );
    }

    try {
      return parseDiaryMonth(data, month: month);
    } on DiaryMonthFormatException catch (e) {
      throw DiaryException(
        "The Traveler's Diary response did not match what this app expects: "
        '${_truncate(e.message)}',
      );
    }
  }

  /// `'2026-11'` to `'11'`.
  String _monthNumberOf(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    return int.tryParse(parts[1])?.toString() ?? month;
  }

  String _truncate(String text, {int maxLength = 200}) =>
      text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

  String _messageFor(Object? retcode, Object? message) {
    if (message is String && message.isNotEmpty) return message;
    return "Traveler's Diary request failed (code $retcode).";
  }
}
