import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/gacha_log_client.dart';
import 'package:routine_planner/features/wishes/data/wish_import_service.dart';
import 'package:routine_planner/features/wishes/data/wish_repository.dart';
import 'package:routine_planner/features/wishes/domain/gacha_url.dart';
import 'package:routine_planner/features/wishes/domain/wish_banner.dart';

final now = DateTime.utc(2026, 11, 3, 12);
const asiaOffset = Duration(hours: 8);

final GachaAuth auth = (
  baseUrl: Uri.parse(
    'https://hk4e-api-os.hoyoverse.com/event/gacha_info/api/getGachaLog',
  ),
  authkey: 'key-123',
  authkeyVer: '1',
  signType: '2',
);

String snowflake(int n) => (1700000000000000000 + n).toString();

Map<String, Object?> record(int n, {int gachaType = 301, int rarity = 3}) {
  return {
    'id': snowflake(n),
    'gacha_type': '$gachaType',
    'name': rarity == 5 ? 'Hu Tao' : 'Cool Steel',
    'item_type': rarity == 5 ? 'Character' : 'Weapon',
    'rank_type': '$rarity',
    'time': '2026-11-03 20:00:00',
  };
}

http.Response page(List<Map<String, Object?>> list) {
  return http.Response(
    jsonEncode({
      'retcode': 0,
      'data': {'list': list},
    }),
    200,
  );
}

http.Response errorPage(int retcode, String message) {
  return http.Response(
    jsonEncode({'retcode': retcode, 'message': message}),
    200,
  );
}

void main() {
  late UserDatabase db;
  late WishRepository repository;
  late FakeClock clock;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = WishRepository(db);
    clock = FakeClock(now);
    addTearDown(db.close);

    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: 'profile-1',
            displayName: const Value('Main'),
            server: 'asia',
            updatedAt: now,
          ),
        );
  });

  WishImportService serviceWith(MockClient httpClient) {
    return WishImportService(
      client: GachaLogClient(httpClient: httpClient),
      repository: repository,
      clock: clock,
      // No waiting in tests.
      pageDelay: Duration.zero,
    );
  }

  Future<WishImportOutcome> runImport(MockClient httpClient) {
    return serviceWith(httpClient).importAll(
      profileId: 'profile-1',
      auth: auth,
      serverOffset: asiaOffset,
    );
  }

  test('a first import walks every banner and stores everything', () async {
    final requested = <String>[];
    final outcome = await runImport(
      MockClient((request) async {
        final gachaType = request.url.queryParameters['gacha_type']!;
        requested.add(gachaType);
        // One record for the character banner, nothing anywhere else.
        if (gachaType == '301' &&
            request.url.queryParameters['end_id'] == '0') {
          return page([record(2, rarity: 5), record(1)]);
        }
        return page(const []);
      }),
    );

    expect(outcome.error, isNull);
    expect(outcome.imported, 2);
    expect(outcome.scanned, 2);
    expect(await repository.pullCount('profile-1'), 2);
    // Every queryable code was asked for, including the character banner's
    // second code.
    expect(requested, containsAll(['100', '200', '301', '302', '400', '500']));
  });

  test('pages backwards with the end_id cursor until a page comes back empty', () async {
    final endIds = <String>[];
    final outcome = await runImport(
      MockClient((request) async {
        if (request.url.queryParameters['gacha_type'] != '301') {
          return page(const []);
        }
        final endId = request.url.queryParameters['end_id']!;
        endIds.add(endId);
        if (endId == '0') return page([record(5), record(4)]);
        if (endId == snowflake(4)) return page([record(3), record(2)]);
        return page(const []);
      }),
    );

    expect(endIds, ['0', snowflake(4), snowflake(2)]);
    expect(outcome.imported, 4);
  });

  test('a second import stops at the high-water mark', () async {
    var characterCalls = 0;
    final firstRun = MockClient((request) async {
      if (request.url.queryParameters['gacha_type'] != '301') {
        return page(const []);
      }
      return request.url.queryParameters['end_id'] == '0'
          ? page([record(2), record(1)])
          : page(const []);
    });
    await runImport(firstRun);

    // Upstream now has one newer record (3) on top of the two already stored.
    final secondRun = MockClient((request) async {
      if (request.url.queryParameters['gacha_type'] != '301') {
        return page(const []);
      }
      characterCalls++;
      return page([record(3), record(2), record(1)]);
    });
    final outcome = await runImport(secondRun);

    expect(outcome.imported, 1);
    // Already-known records appeared on the first page, so it stopped there
    // rather than walking the rest of the history again.
    expect(characterCalls, 1);
    expect(await repository.pullCount('profile-1'), 3);
  });

  test('re-importing with nothing new imports nothing and duplicates nothing', () async {
    final client = MockClient((request) async {
      if (request.url.queryParameters['gacha_type'] != '301') {
        return page(const []);
      }
      return request.url.queryParameters['end_id'] == '0'
          ? page([record(2), record(1)])
          : page(const []);
    });

    await runImport(client);
    final second = await runImport(client);

    expect(second.imported, 0);
    expect(await repository.pullCount('profile-1'), 2);
  });

  test('folds the character banner second code into one history', () async {
    final outcome = await runImport(
      MockClient((request) async {
        final gachaType = request.url.queryParameters['gacha_type'];
        if (request.url.queryParameters['end_id'] != '0') {
          return page(const []);
        }
        if (gachaType == '301') return page([record(9, gachaType: 301)]);
        if (gachaType == '400') return page([record(4, gachaType: 400)]);
        return page(const []);
      }),
    );

    expect(outcome.imported, 2);
    final pulls = await repository.pullsFor(
      'profile-1',
      banner: WishBanner.character,
    );
    expect(pulls, hasLength(2));
    // The mark tracks the newest of the two codes.
    expect(
      await repository.lastImportedId('profile-1', WishBanner.character),
      snowflake(9),
    );
  });

  group('failures are reported, never thrown', () {
    test('an expired authkey is returned as an error', () async {
      final outcome = await runImport(
        MockClient((_) async => errorPage(-101, 'authkey timeout')),
      );

      expect(outcome.error, contains('expired'));
      expect(outcome.imported, 0);
    });

    test('a rate limit keeps whatever was already imported', () async {
      var calls = 0;
      final outcome = await runImport(
        MockClient((request) async {
          if (request.url.queryParameters['gacha_type'] != '301') {
            return page(const []);
          }
          calls++;
          if (calls == 1) return page([record(2), record(1)]);
          return errorPage(-110, 'visit too frequently');
        }),
      );

      expect(outcome.error, contains('slow down'));
      // The first page survived.
      expect(outcome.imported, 2);
      expect(await repository.pullCount('profile-1'), 2);
    });

    test('a malformed record is reported as a mismatch', () async {
      final outcome = await runImport(
        MockClient(
          (_) async => page([
            {'gacha_type': '301'}, // no id/name/rarity/time
          ]),
        ),
      );

      expect(outcome.error, contains('did not match'));
    });

    test('a non-JSON response is reported', () async {
      final outcome = await runImport(
        MockClient((_) async => http.Response('<html>502</html>', 502)),
      );

      expect(outcome.error, contains('502'));
    });
  });

  test('an account with no history anywhere imports nothing and succeeds', () async {
    final outcome = await runImport(MockClient((_) async => page(const [])));

    expect(outcome.error, isNull);
    expect(outcome.imported, 0);
    expect(outcome.scanned, 0);
  });
}
