import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/domain/hoyolab_signing.dart';

void main() {
  group('dynamicSecret', () {
    test('matches a hand-computed MD5 hash for fixed inputs', () {
      // echo -n "salt=testsalt&t=1700000000&r=abcdef" | md5sum
      final result = dynamicSecret(salt: 'testsalt', unixSeconds: 1700000000, random: 'abcdef');
      expect(result, '1700000000,abcdef,82f4c682cc6ae97184fb65e513722f63');
    });

    test('is deterministic for the same inputs', () {
      final a = dynamicSecret(salt: 's', unixSeconds: 1, random: 'r');
      final b = dynamicSecret(salt: 's', unixSeconds: 1, random: 'r');
      expect(a, b);
    });

    test('is "t,r,32-hex-char-hash" shaped', () {
      final result = dynamicSecret(salt: overseasDsSalt, unixSeconds: 123, random: 'abcxyz');
      final parts = result.split(',');
      expect(parts, hasLength(3));
      expect(parts[0], '123');
      expect(parts[1], 'abcxyz');
      expect(parts[2], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('a different salt, t, or r each produce a different hash', () {
      final base = dynamicSecret(salt: 's', unixSeconds: 1, random: 'rrrrrr');
      expect(dynamicSecret(salt: 's2', unixSeconds: 1, random: 'rrrrrr'), isNot(base));
      expect(dynamicSecret(salt: 's', unixSeconds: 2, random: 'rrrrrr'), isNot(base));
      expect(dynamicSecret(salt: 's', unixSeconds: 1, random: 'qqqqqq'), isNot(base));
    });
  });

  group('dynamicSecretForNow', () {
    test('produces a well-formed secret using the real clock', () {
      final result = dynamicSecretForNow(overseasDsSalt);
      final parts = result.split(',');
      expect(parts, hasLength(3));
      expect(int.parse(parts[0]), greaterThan(0));
      expect(parts[1], hasLength(6));
      expect(parts[2], matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });
}
