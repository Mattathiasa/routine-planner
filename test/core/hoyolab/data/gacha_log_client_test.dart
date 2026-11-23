import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/hoyolab/data/gacha_log_client.dart';
import 'package:routine_planner/features/wishes/domain/gacha_url.dart';

GachaAuth authFor([String url = 'https://hk4e-api-os.hoyoverse.com/event/gacha_info/api/getGachaLog']) {
  return (
    baseUrl: Uri.parse(url),
    authkey: 'key-123',
    authkeyVer: '1',
    signType: '2',
  );
}

http.Response jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, dynamic> okPage(List<Map<String, Object?>> list) {
  return {
    'retcode': 0,
    'message': 'OK',
    'data': {'page': '1', 'size': '20', 'list': list},
  };
}

void main() {
  group('fetchPage request', () {
    test('calls the host and path from the pasted link, with the full query', () async {
      http.Request? captured;
      final client = GachaLogClient(
        httpClient: MockClient((request) async {
          captured = request;
          return jsonResponse(okPage(const []));
        }),
      );

      await client.fetchPage(
        auth: authFor(),
        gachaType: 301,
        page: 3,
        endId: '1700000000000000123',
      );

      expect(captured!.url.host, 'hk4e-api-os.hoyoverse.com');
      expect(captured!.url.path, '/event/gacha_info/api/getGachaLog');
      final query = captured!.url.queryParameters;
      expect(query['authkey'], 'key-123');
      expect(query['authkey_ver'], '1');
      expect(query['sign_type'], '2');
      expect(query['auth_appid'], 'webview_gacha');
      expect(query['gacha_type'], '301');
      expect(query['page'], '3');
      expect(query['end_id'], '1700000000000000123');
      expect(query['size'], '$gachaLogMaxPageSize');
    });

    test('forces lang=en so item names match the catalog', () async {
      http.Request? captured;
      final client = GachaLogClient(
        httpClient: MockClient((request) async {
          captured = request;
          return jsonResponse(okPage(const []));
        }),
      );

      await client.fetchPage(auth: authFor(), gachaType: 301);

      expect(captured!.url.queryParameters['lang'], 'en');
    });

    test('honours the newer host and path spelling when that is what was pasted', () async {
      http.Request? captured;
      final client = GachaLogClient(
        httpClient: MockClient((request) async {
          captured = request;
          return jsonResponse(okPage(const []));
        }),
      );

      await client.fetchPage(
        auth: authFor(
          'https://public-operation-hk4e-sg.hoyoverse.com/gacha_info/api/getGachaLog',
        ),
        gachaType: 301,
      );

      expect(captured!.url.host, 'public-operation-hk4e-sg.hoyoverse.com');
      expect(captured!.url.path, '/gacha_info/api/getGachaLog');
    });

    test('starts at the newest record by default', () async {
      http.Request? captured;
      final client = GachaLogClient(
        httpClient: MockClient((request) async {
          captured = request;
          return jsonResponse(okPage(const []));
        }),
      );

      await client.fetchPage(auth: authFor(), gachaType: 301);

      expect(captured!.url.queryParameters['end_id'], '0');
      expect(captured!.url.queryParameters['page'], '1');
    });
  });

  group('fetchPage response', () {
    test('returns the raw records', () async {
      final client = GachaLogClient(
        httpClient: MockClient((_) async {
          return jsonResponse(
            okPage([
              {
                'id': '1700000000000000001',
                'gacha_type': '301',
                'name': 'Hu Tao',
                'item_type': 'Character',
                'rank_type': '5',
                'time': '2026-11-03 20:00:00',
              },
            ]),
          );
        }),
      );

      final page = await client.fetchPage(auth: authFor(), gachaType: 301);

      expect(page, hasLength(1));
      expect(page.single['name'], 'Hu Tao');
    });

    test('an empty list marks the end of history', () async {
      final client = GachaLogClient(
        httpClient: MockClient((_) async => jsonResponse(okPage(const []))),
      );

      expect(await client.fetchPage(auth: authFor(), gachaType: 301), isEmpty);
    });

    test('a missing list reads as empty rather than throwing', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({
            'retcode': 0,
            'data': {'page': '1'},
          }),
        ),
      );

      expect(await client.fetchPage(auth: authFor(), gachaType: 301), isEmpty);
    });

    test('skips non-map entries', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({
            'retcode': 0,
            'data': {
              'list': [
                'nonsense',
                {'id': '1'},
              ],
            },
          }),
        ),
      );

      expect(await client.fetchPage(auth: authFor(), gachaType: 301), hasLength(1));
    });
  });

  group('fetchPage errors', () {
    test('an expired authkey asks for a fresh link', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({'retcode': -101, 'message': 'authkey timeout'}),
        ),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>()
              .having((e) => e.message, 'message', contains('expired'))
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('an invalid authkey says to copy the whole link', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({'retcode': -100, 'message': 'authkey error'}),
        ),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>().having(
            (e) => e.message,
            'message',
            contains('whole wish'),
          ),
        ),
      );
    });

    test('a rate limit is marked retryable', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async =>
              jsonResponse({'retcode': -110, 'message': 'visit too frequently'}),
        ),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>()
              .having((e) => e.message, 'message', contains('slow down'))
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('an unknown retcode passes the upstream message through', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({'retcode': -1, 'message': 'something odd'}),
        ),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>().having(
            (e) => e.message,
            'message',
            'something odd',
          ),
        ),
      );
    });

    test('an unknown retcode with no message still says something useful', () async {
      final client = GachaLogClient(
        httpClient: MockClient((_) async => jsonResponse({'retcode': -7})),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>().having(
            (e) => e.message,
            'message',
            contains('code -7'),
          ),
        ),
      );
    });

    test('a non-JSON response reports the status code', () async {
      final client = GachaLogClient(
        httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(
          isA<GachaLogException>().having(
            (e) => e.message,
            'message',
            contains('502'),
          ),
        ),
      );
    });

    test('retcode 0 with no data object is an error', () async {
      final client = GachaLogClient(
        httpClient: MockClient(
          (_) async => jsonResponse({'retcode': 0, 'data': null}),
        ),
      );

      await expectLater(
        client.fetchPage(auth: authFor(), gachaType: 301),
        throwsA(isA<GachaLogException>()),
      );
    });
  });
}
