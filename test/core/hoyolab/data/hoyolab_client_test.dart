import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/hoyolab/data/hoyolab_client.dart';

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

void main() {
  group('HoyolabClient.fetchNotes', () {
    test('builds a well-formed request: URL, region/uid params, and required headers', () async {
      late http.Request captured;
      final client = HoyolabClient(
        httpClient: MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'retcode': 0,
            'data': {'current_resin': 100, 'max_resin': 200, 'resin_recovery_time': 1000},
          });
        }),
      );

      await client.fetchNotes(cookie: 'ltoken_v2=abc; ltuid_v2=1', uid: '800000001', region: 'os_asia');

      expect(captured.method, 'GET');
      expect(captured.url.host, 'sg-public-api.hoyolab.com');
      expect(captured.url.path, '/event/game_record/genshin/api/dailyNote');
      expect(captured.url.queryParameters['server'], 'os_asia');
      expect(captured.url.queryParameters['role_id'], '800000001');
      expect(captured.headers['Cookie'], 'ltoken_v2=abc; ltuid_v2=1');
      expect(captured.headers['ds'], isNotNull);
      expect(captured.headers['ds']!.split(',').length, 3);
    });

    test('a retcode: 0 response parses into HoyolabNotes', () async {
      final client = HoyolabClient(
        httpClient: MockClient(
          (request) async => _jsonResponse({
            'retcode': 0,
            'data': {'current_resin': 142, 'max_resin': 200, 'resin_recovery_time': 27840},
          }),
        ),
      );

      final notes = await client.fetchNotes(cookie: 'c', uid: '1', region: 'os_asia');
      expect(notes.currentResin, 142);
      expect(notes.maxResin, 200);
      expect(notes.secondsUntilFull, 27840);
    });

    test('a non-zero retcode throws HoyolabException with the server message', () async {
      final client = HoyolabClient(
        httpClient: MockClient(
          (request) async =>
              _jsonResponse({'retcode': -100, 'message': 'Not logged in', 'data': null}),
        ),
      );

      await expectLater(
        client.fetchNotes(cookie: 'c', uid: '1', region: 'os_asia'),
        throwsA(isA<HoyolabException>().having((e) => e.message, 'message', 'Not logged in')),
      );
    });

    test('a geetest retcode throws HoyolabException with the "verify in browser" message', () async {
      final client = HoyolabClient(
        httpClient: MockClient(
          (request) async => _jsonResponse({
            'retcode': 10035,
            'message': 'risk control',
            'data': null,
          }),
        ),
      );

      await expectLater(
        client.fetchNotes(cookie: 'c', uid: '1', region: 'os_asia'),
        throwsA(
          isA<HoyolabException>().having(
            (e) => e.message,
            'message',
            contains('verify in the browser'),
          ),
        ),
      );
    });
  });
}
