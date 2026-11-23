import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/hoyolab/data/traveler_diary_client.dart';
import 'package:routine_planner/core/hoyolab/domain/diary_month.dart';

http.Response jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode);
}

Map<String, dynamic> okMonth({
  Object? primogems = 3200,
  Object? mora = 1200000,
  Object? today = 60,
}) {
  return {
    'retcode': 0,
    'message': 'OK',
    'data': {
      'month_data': {'current_primogems': primogems, 'current_mora': mora},
      'day_data': {'current_primogems': today},
    },
  };
}

Future<DiaryMonth> fetch(
  MockClient httpClient, {
  String month = '2026-11',
}) {
  return TravelerDiaryClient(httpClient: httpClient).fetchMonth(
    cookie: 'ltoken_v2=x; ltuid_v2=1',
    uid: '800000001',
    region: 'os_asia',
    month: month,
  );
}

void main() {
  group('request', () {
    test('asks for the account, region and month', () async {
      http.Request? captured;
      await fetch(
        MockClient((request) async {
          captured = request;
          return jsonResponse(okMonth());
        }),
      );

      expect(captured!.url.host, 'sg-hk4e-api.hoyolab.com');
      expect(captured!.url.path, '/event/ysledgeros/month_info');
      expect(captured!.url.queryParameters['uid'], '800000001');
      expect(captured!.url.queryParameters['region'], 'os_asia');
      // Upstream wants a bare month number, not YYYY-MM.
      expect(captured!.url.queryParameters['month'], '11');
    });

    test('sends the cookie and the usual HoYoLab headers', () async {
      http.Request? captured;
      await fetch(
        MockClient((request) async {
          captured = request;
          return jsonResponse(okMonth());
        }),
      );

      expect(captured!.headers['Cookie'], contains('ltoken_v2'));
      expect(captured!.headers['ds']?.split(',').length, 3);
      expect(captured!.headers['x-rpc-client_type'], '5');
    });

    test('strips a leading zero from the month', () async {
      http.Request? captured;
      await fetch(
        MockClient((request) async {
          captured = request;
          return jsonResponse(okMonth());
        }),
        month: '2026-07',
      );

      expect(captured!.url.queryParameters['month'], '7');
    });
  });

  group('response', () {
    test('reads the month to date, and keeps the month this app asked for', () async {
      final month = await fetch(
        MockClient((_) async => jsonResponse(okMonth())),
      );

      expect(month.primogems, 3200);
      expect(month.mora, 1200000);
      expect(month.todayPrimogems, 60);
      expect(month.month, '2026-11');
    });

    test('tolerates numbers sent as strings', () async {
      final month = await fetch(
        MockClient(
          (_) async => jsonResponse(okMonth(primogems: '3200', today: '60')),
        ),
      );

      expect(month.primogems, 3200);
      expect(month.todayPrimogems, 60);
    });

    test('degrades a missing optional field to null', () async {
      final month = await fetch(
        MockClient(
          (_) async => jsonResponse({
            'retcode': 0,
            'data': {
              'month_data': {'current_primogems': 500},
            },
          }),
        ),
      );

      expect(month.primogems, 500);
      expect(month.mora, isNull);
      expect(month.todayPrimogems, isNull);
    });
  });

  group('errors', () {
    test('a rejected login raises the unauthorized case on its own', () async {
      // The likeliest failure: the diary needs a cookie the login WebView may
      // not hand back, and the UI has to say so specifically.
      await expectLater(
        fetch(
          MockClient(
            (_) async =>
                jsonResponse({'retcode': -100, 'message': 'Please login'}),
          ),
        ),
        throwsA(
          isA<DiaryUnauthorizedException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Reconnect'), contains('by hand')),
          ),
        ),
      );
    });

    test('retcode 10001 is also treated as a rejected login', () async {
      await expectLater(
        fetch(
          MockClient((_) async => jsonResponse({'retcode': 10001})),
        ),
        throwsA(isA<DiaryUnauthorizedException>()),
      );
    });

    test('any other retcode passes the upstream message through', () async {
      await expectLater(
        fetch(
          MockClient(
            (_) async =>
                jsonResponse({'retcode': -500, 'message': 'server busy'}),
          ),
        ),
        throwsA(
          isA<DiaryException>().having((e) => e.message, 'message', 'server busy'),
        ),
      );
    });

    test('a non-JSON response reports the status code', () async {
      await expectLater(
        fetch(MockClient((_) async => http.Response('<html>', 503))),
        throwsA(
          isA<DiaryException>().having(
            (e) => e.message,
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('a missing month_data is a mismatch, not a crash', () async {
      await expectLater(
        fetch(
          MockClient(
            (_) async => jsonResponse({
              'retcode': 0,
              'data': {'day_data': {}},
            }),
          ),
        ),
        throwsA(
          isA<DiaryException>().having(
            (e) => e.message,
            'message',
            contains('did not match'),
          ),
        ),
      );
    });

    test('a missing primogem total is a mismatch', () async {
      await expectLater(
        fetch(
          MockClient(
            (_) async => jsonResponse({
              'retcode': 0,
              'data': {
                'month_data': {'current_mora': 5},
              },
            }),
          ),
        ),
        throwsA(isA<DiaryException>()),
      );
    });
  });
}
