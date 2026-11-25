import 'dart:io' show Cookie;

import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/data/hoyolab_cookie_capture.dart';

/// Pure Dart — no binding, no platform channel, no real delay.
void main() {
  Cookie cookie(String name, String value) => Cookie(name, value);

  final loggedIn = [
    cookie('ltuid_v2', '800000001'),
    cookie('ltoken_v2', 'token-abc'),
    cookie('account_id_v2', '800000001'),
  ];

  group('hasSessionCookies', () {
    test('is true only when both session cookies are present', () {
      expect(hasSessionCookies(loggedIn), isTrue);
    });

    test('is false with only ltoken_v2', () {
      expect(hasSessionCookies([cookie('ltoken_v2', 'a')]), isFalse);
    });

    test('is false with only ltuid_v2', () {
      expect(hasSessionCookies([cookie('ltuid_v2', '1')]), isFalse);
    });

    test('is false for an empty jar', () {
      expect(hasSessionCookies(const []), isFalse);
    });
  });

  group('toCookieHeader', () {
    // Pins the documented decision to send the whole jar, so nobody trims
    // it back to the two session cookies the API has been seen rejecting.
    test('joins the entire jar in order', () {
      expect(
        toCookieHeader(loggedIn),
        'ltuid_v2=800000001; ltoken_v2=token-abc; account_id_v2=800000001',
      );
    });

    test('is empty for an empty jar', () {
      expect(toCookieHeader(const []), isEmpty);
    });
  });

  group('pollForSessionCookie', () {
    late List<Duration> slept;
    late int reads;

    setUp(() {
      slept = <Duration>[];
      reads = 0;
    });

    Future<void> fakeSleep(Duration duration) async => slept.add(duration);

    // The Android fast path: the first read wins, so the poll costs nothing.
    test('returns immediately when the cookies are already there', () async {
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          return loggedIn;
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
      );

      expect(header, contains('ltoken_v2=token-abc'));
      expect(reads, 1);
      expect(slept, isEmpty);
    });

    // The iOS fix: WKHTTPCookieStore lands the cookies a moment late.
    test('keeps polling until the cookies land', () async {
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          return reads < 3 ? <Cookie>[] : loggedIn;
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
        interval: const Duration(milliseconds: 50),
      );

      expect(header, isNotNull);
      expect(reads, 3);
      expect(slept, [
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 50),
      ]);
    });

    // Pinned so nobody turns the budget into an unbounded loop.
    test('gives up after exactly the attempt budget', () async {
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          return <Cookie>[];
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
        attempts: 4,
      );

      expect(header, isNull);
      expect(reads, 4);
      expect(slept, hasLength(3));
    });

    test('stops when cancelled mid-poll', () async {
      var cancelled = false;
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          if (reads == 2) cancelled = true;
          return <Cookie>[];
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
        isCancelled: () => cancelled,
        attempts: 10,
      );

      expect(header, isNull);
      expect(reads, 2, reason: 'must not keep reading after dispose');
    });

    test('never reads when cancelled before the first attempt', () async {
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          return loggedIn;
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
        isCancelled: () => true,
      );

      expect(header, isNull);
      expect(reads, 0);
    });

    test('survives a transient read failure', () async {
      final header = await pollForSessionCookie(
        read: (_) async {
          reads++;
          if (reads == 1) throw Exception('channel died mid-navigation');
          return loggedIn;
        },
        url: 'https://www.hoyolab.com/home',
        sleep: fakeSleep,
      );

      expect(header, isNotNull);
      expect(reads, 2);
    });
  });
}
