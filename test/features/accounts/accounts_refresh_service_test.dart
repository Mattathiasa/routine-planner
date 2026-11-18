import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/account_status_repository.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/hoyolab/data/hoyolab_client.dart';
import 'package:routine_planner/features/accounts/data/accounts_refresh_service.dart';
import 'package:routine_planner/features/resin/data/resin_repository.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';

/// Builds a `dailyNote` body. Numeric strings on purpose — that's how
/// HoYoLab actually serializes them.
///
/// [secondsUntilFull] defaults to the value consistent with
/// [currentResin] at 480s per resin. That consistency matters: the engine
/// anchors on the countdown, so an arbitrary pairing would project to a
/// different resin value than the one the fixture claims.
String _notesBody({
  int currentResin = 132,
  int? secondsUntilFull,
  int finishedTasks = 3,
}) {
  secondsUntilFull ??= (200 - currentResin) * 480;
  return jsonEncode({
    'retcode': 0,
    'message': 'OK',
    'data': {
      'current_resin': '$currentResin',
      'max_resin': '200',
      'resin_recovery_time': '$secondsUntilFull',
      'finished_task_num': '$finishedTasks',
      'total_task_num': '4',
      'is_extra_task_reward_received': false,
      'remain_resin_discount_num': '2',
      'resin_discount_num_limit': '3',
      'current_expedition_num': '2',
      'max_expedition_num': '5',
      'expeditions': [
        {'status': 'Finished', 'remained_time': '0'},
        {'status': 'Ongoing', 'remained_time': '3600'},
      ],
      'current_home_coin': '1800',
      'max_home_coin': '2400',
      'home_coin_recovery_time': '9000',
    },
  });
}

void main() {
  late UserDatabase userDb;
  late ProfileRepository profiles;
  late ResinRepository resinRepository;
  late AccountStatusRepository statusRepository;
  late FakeHoyolabCredentialsStore credentials;
  late FakeClock clock;

  setUp(() async {
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    profiles = ProfileRepository(userDb);
    resinRepository = ResinRepository(userDb);
    statusRepository = AccountStatusRepository(userDb);
    credentials = FakeHoyolabCredentialsStore();
    clock = FakeClock(DateTime.utc(2026, 11, 3, 12));
  });

  AccountsRefreshService serviceWith(http.Client httpClient) {
    return AccountsRefreshService(
      client: HoyolabClient(httpClient: httpClient),
      credentialsStore: credentials,
      resinRepository: resinRepository,
      accountStatusRepository: statusRepository,
      clock: clock,
    );
  }

  test('writes resin and the snapshot for a connected account', () async {
    final profileId = (await profiles.getActiveProfile()).id;
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

    final service = serviceWith(MockClient((_) async => http.Response(_notesBody(), 200)));
    final outcomes = await service.refreshAll([profileId]);

    expect(outcomes.single.refreshed, isTrue);
    expect(outcomes.single.error, isNull);

    const engine = ResinEngine();
    final state = await resinRepository.loadResinState(profileId);
    expect(engine.v(state, clock.nowUtc()), 132);
    // The anchor is derived from the reported "full in", so the cap time
    // lands exactly where HoYoLab said it would.
    expect(
      engine.timeToThreshold(state, state.cap),
      clock.nowUtc().add(const Duration(seconds: 32640)),
    );

    final snapshot = await statusRepository.snapshotFor(profileId);
    expect(snapshot!.finishedTaskNum, 3);
    expect(snapshot.totalTaskNum, 4);
    expect(snapshot.extraTaskRewardReceived, isFalse);
    expect(snapshot.remainResinDiscountNum, 2);
    expect(snapshot.resinDiscountNumLimit, 3);
    expect(snapshot.finishedExpeditionNum, 1);
    expect(snapshot.currentExpeditionNum, 2);
    expect(snapshot.currentHomeCoin, 1800);
    expect(snapshot.fetchedAt, clock.nowUtc());
  });

  test('skips an account with no HoYoLab login without reporting an error', () async {
    final profileId = (await profiles.getActiveProfile()).id;

    var requests = 0;
    final service = serviceWith(
      MockClient((_) async {
        requests++;
        return http.Response(_notesBody(), 200);
      }),
    );
    final outcomes = await service.refreshAll([profileId]);

    expect(requests, 0);
    expect(outcomes.single.refreshed, isFalse);
    expect(outcomes.single.error, isNull);
    expect(await statusRepository.snapshotFor(profileId), isNull);
  });

  test('each account gets its own credential, resin and snapshot', () async {
    final main = (await profiles.getActiveProfile()).id;
    final alt = (await profiles.createProfile(displayName: 'Alt', server: 'europe')).id;
    await credentials.save(profileId: main, cookie: 'c-main', uid: '800000001');
    await credentials.save(profileId: alt, cookie: 'c-alt', uid: '700000002');

    final seenUids = <String>[];
    final service = serviceWith(
      MockClient((request) async {
        final uid = request.url.queryParameters['role_id']!;
        seenUids.add(uid);
        return http.Response(
          _notesBody(currentResin: uid == '800000001' ? 132 : 48, finishedTasks: uid == '800000001' ? 3 : 1),
          200,
        );
      }),
    );

    await service.refreshAll([main, alt]);

    expect(seenUids, ['800000001', '700000002']);

    const engine = ResinEngine();
    expect(engine.v(await resinRepository.loadResinState(main), clock.nowUtc()), 132);
    expect(engine.v(await resinRepository.loadResinState(alt), clock.nowUtc()), 48);
    expect((await statusRepository.snapshotFor(main))!.finishedTaskNum, 3);
    expect((await statusRepository.snapshotFor(alt))!.finishedTaskNum, 1);
  });

  test('one failing account does not stop the others', () async {
    final main = (await profiles.getActiveProfile()).id;
    final alt = (await profiles.createProfile(displayName: 'Alt', server: 'europe')).id;
    await credentials.save(profileId: main, cookie: 'c', uid: '800000001');
    await credentials.save(profileId: alt, cookie: 'c', uid: '700000002');

    final service = serviceWith(
      MockClient((request) async {
        if (request.url.queryParameters['role_id'] == '800000001') {
          return http.Response(
            jsonEncode({'retcode': 10001, 'message': 'Not logged in', 'data': null}),
            200,
          );
        }
        return http.Response(_notesBody(currentResin: 48), 200);
      }),
    );

    final outcomes = await service.refreshAll([main, alt]);

    final failed = outcomes.firstWhere((o) => o.profileId == main);
    expect(failed.refreshed, isFalse);
    expect(failed.error, 'Not logged in');

    final succeeded = outcomes.firstWhere((o) => o.profileId == alt);
    expect(succeeded.refreshed, isTrue);
    expect(
      const ResinEngine().v(await resinRepository.loadResinState(alt), clock.nowUtc()),
      48,
    );
  });

  test('a network failure reports offline instead of throwing', () async {
    final profileId = (await profiles.getActiveProfile()).id;
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

    final service = serviceWith(
      MockClient((_) async => throw http.ClientException('no route to host')),
    );

    final outcomes = await service.refreshAll([profileId]);
    expect(outcomes.single.refreshed, isFalse);
    expect(outcomes.single.error, contains("Couldn't reach HoYoLab"));
  });

  group('staleness throttle', () {
    test('a fresh snapshot is not refetched', () async {
      final profileId = (await profiles.getActiveProfile()).id;
      await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

      var requests = 0;
      final service = serviceWith(
        MockClient((_) async {
          requests++;
          return http.Response(_notesBody(), 200);
        }),
      );

      await service.refreshAll([profileId]);
      expect(requests, 1);

      clock.advance(accountSnapshotFreshness - const Duration(seconds: 1));
      await service.refreshAll([profileId]);
      expect(requests, 1, reason: 'still fresh, so no second request');
    });

    test('refetches once the snapshot ages out', () async {
      final profileId = (await profiles.getActiveProfile()).id;
      await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

      var requests = 0;
      final service = serviceWith(
        MockClient((_) async {
          requests++;
          return http.Response(_notesBody(), 200);
        }),
      );

      await service.refreshAll([profileId]);
      clock.advance(accountSnapshotFreshness);
      await service.refreshAll([profileId]);

      expect(requests, 2);
    });

    test('force ignores freshness — the pull-to-refresh path', () async {
      final profileId = (await profiles.getActiveProfile()).id;
      await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

      var requests = 0;
      final service = serviceWith(
        MockClient((_) async {
          requests++;
          return http.Response(_notesBody(), 200);
        }),
      );

      await service.refreshAll([profileId]);
      await service.refreshAll([profileId], force: true);

      expect(requests, 2);
    });
  });
}
