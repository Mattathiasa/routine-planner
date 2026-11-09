import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/hoyolab_notes.dart';
import '../domain/hoyolab_signing.dart';

/// Retcodes HoYoLab uses to signal a Geetest/CAPTCHA challenge — these
/// can't be solved headlessly from this app (no embedded Geetest widget),
/// so they're surfaced as a distinct, actionable message rather than a
/// generic failure.
const _geetestRetcodes = {10035, 5003, 10041, 1034};

/// Returned when the player's Real-Time Notes (the data `dailyNote`
/// reads) are set to private — an account privacy setting, not a login
/// problem. Observed as a plain "not public" message with no clearer
/// hint at the actual fix, so this gets its own actionable message.
const _notPublicRetcode = 10102;

class HoyolabException implements Exception {
  const HoyolabException(this.message);
  final String message;

  @override
  String toString() => 'HoyolabException: $message';
}

/// Talks to HoYoLab's unofficial, reverse-engineered `dailyNote` endpoint
/// — see `hoyolab_signing.dart`'s doc comment for the "no official
/// support" caveat. Takes an injectable [http.Client] so tests never hit
/// the real network (`package:http/testing.dart`'s `MockClient`).
class HoyolabClient {
  HoyolabClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<HoyolabNotes> fetchNotes({
    required String cookie,
    required String uid,
    required String region,
  }) async {
    final uri = Uri.https('sg-public-api.hoyolab.com', '/event/game_record/genshin/api/dailyNote', {
      'server': region,
      'role_id': uid,
    });

    final response = await _http.get(
      uri,
      headers: {
        'Cookie': cookie,
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
      throw const HoyolabException('HoYoLab returned an unexpected response. Try again later.');
    }

    final retcode = body['retcode'];
    if (retcode != 0) {
      throw HoyolabException(_messageFor(retcode, body['message']));
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const HoyolabException('HoYoLab returned an unexpected response. Try again later.');
    }
    try {
      return parseHoyolabNotes(data);
    } on HoyolabNotesFormatException {
      throw const HoyolabException('HoYoLab returned an unexpected response. Try again later.');
    }
  }

  String _messageFor(Object? retcode, Object? message) {
    if (retcode is int && _geetestRetcodes.contains(retcode)) {
      return 'HoYoLab needs you to verify in the browser first — log into hoyolab.com, then try again.';
    }
    if (retcode == _notPublicRetcode) {
      return 'Your Real-Time Notes are private. In the HoYoLab app: open your Genshin '
          'profile → Battle Chronicle → the settings icon on your character card, and '
          'turn on "Real-Time Notes", then try again.';
    }
    if (message is String && message.isNotEmpty) return message;
    return 'HoYoLab request failed (code $retcode).';
  }
}
