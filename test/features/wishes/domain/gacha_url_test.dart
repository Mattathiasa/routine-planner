import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/wishes/domain/gacha_url.dart';

void main() {
  group('parseGachaUrl', () {
    test('reads the authkey and keeps the link own host and path', () {
      final auth = parseGachaUrl(
        'https://public-operation-hk4e-sg.hoyoverse.com/gacha_info/api/getGachaLog'
        '?authkey_ver=1&sign_type=2&auth_appid=webview_gacha'
        '&authkey=abc123%3D%3D&lang=en&gacha_type=301',
      );

      expect(auth.authkey, 'abc123==');
      expect(auth.authkeyVer, '1');
      expect(auth.signType, '2');
      expect(
        auth.baseUrl.toString(),
        'https://public-operation-hk4e-sg.hoyoverse.com/gacha_info/api/getGachaLog',
      );
      // The query is the client's business; the base URL carries none of it.
      expect(auth.baseUrl.hasQuery, isFalse);
    });

    test('keeps the older host and path spelling when that is what was pasted', () {
      final auth = parseGachaUrl(
        'https://hk4e-api-os.hoyoverse.com/event/gacha_info/api/getGachaLog'
        '?authkey=k&authkey_ver=1&sign_type=2',
      );

      expect(
        auth.baseUrl.toString(),
        'https://hk4e-api-os.hoyoverse.com/event/gacha_info/api/getGachaLog',
      );
    });

    test('reads parameters out of the URL fragment', () {
      // Some client versions hand out …/index.html?x#/log?authkey=…
      final auth = parseGachaUrl(
        'https://webstatic-sea.hoyoverse.com/genshin/event/e20190909gacha/index.html'
        '?win_mode=fullscreen#/log?authkey_ver=1&sign_type=2&authkey=fragkey',
      );

      expect(auth.authkey, 'fragkey');
      expect(auth.authkeyVer, '1');
      expect(
        auth.baseUrl.toString(),
        'https://webstatic-sea.hoyoverse.com/genshin/event/e20190909gacha/index.html',
      );
    });

    test('query parameters win over fragment parameters', () {
      final auth = parseGachaUrl(
        'https://example.com/getGachaLog?authkey=fromquery#/log?authkey=fromfragment',
      );

      expect(auth.authkey, 'fromquery');
    });

    test('trims surrounding whitespace from a hand-copied link', () {
      final auth = parseGachaUrl(
        '  https://example.com/getGachaLog?authkey=padded \n',
      );

      expect(auth.authkey, 'padded');
    });

    test('defaults authkey_ver and sign_type when the link omits them', () {
      final auth = parseGachaUrl('https://example.com/getGachaLog?authkey=k');

      expect(auth.authkeyVer, '1');
      expect(auth.signType, '2');
    });

    test('keeps an explicit port', () {
      final auth = parseGachaUrl('https://example.com:8443/api?authkey=k');

      expect(auth.baseUrl.toString(), 'https://example.com:8443/api');
    });

    group('rejects', () {
      test('an empty string', () {
        expect(
          () => parseGachaUrl('   '),
          throwsA(isA<InvalidGachaUrlException>()),
        );
      });

      test('a link with no authkey', () {
        expect(
          () => parseGachaUrl('https://example.com/getGachaLog?gacha_type=301'),
          throwsA(
            isA<InvalidGachaUrlException>().having(
              (e) => e.message,
              'message',
              contains('authkey'),
            ),
          ),
        );
      });

      test('a blank authkey', () {
        expect(
          () => parseGachaUrl('https://example.com/getGachaLog?authkey=%20'),
          throwsA(isA<InvalidGachaUrlException>()),
        );
      });

      test('something that is not a URL at all', () {
        expect(
          () => parseGachaUrl('authkey=abc'),
          throwsA(
            isA<InvalidGachaUrlException>().having(
              (e) => e.input,
              'input',
              'authkey=abc',
            ),
          ),
        );
      });
    });
  });
}
