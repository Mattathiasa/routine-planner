import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/hoyolab/data/hoyolab_client.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/features/accounts/application/account_view_models.dart';
import 'package:routine_planner/features/accounts/application/accounts_overview_controller.dart';
import 'package:routine_planner/features/accounts/data/accounts_refresh_providers.dart';

/// Going offline must degrade, not break: the cards keep showing the last
/// known values with their original "updated" stamp, the failure is
/// reported per account, and manual tracking still works.
void main() {
  test('a failed refresh keeps the cached snapshot and reports the error', () async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final clock = FakeClock(DateTime.utc(2026, 11, 3, 12));
    final credentials = FakeHoyolabCredentialsStore();
    final profileId = (await ProfileRepository(userDb).getActiveProfile()).id;
    await credentials.save(profileId: profileId, cookie: 'c', uid: '800000001');

    // First call succeeds, every later one fails as if the network died.
    var online = true;
    final httpClient = MockClient((_) async {
      if (!online) throw http.ClientException('network is unreachable');
      return http.Response(
        jsonEncode({
          'retcode': 0,
          'message': 'OK',
          'data': {
            'current_resin': '132',
            'max_resin': '200',
            'resin_recovery_time': '${(200 - 132) * 480}',
            'finished_task_num': '3',
            'total_task_num': '4',
            'is_extra_task_reward_received': false,
          },
        }),
        200,
      );
    });

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(clock),
        hoyolabCredentialsStoreProvider.overrideWithValue(credentials),
        hoyolabClientProvider.overrideWithValue(
          HoyolabClient(httpClient: httpClient),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(refreshAllAccountsProvider(force: true).future);
    final fresh = (await container.read(accountsOverviewControllerProvider.future)).single;
    expect(fresh.commissions.completed, 3);
    expect(fresh.commissions.source, CommissionSource.live);
    expect(fresh.lastUpdated, clock.nowUtc());
    expect(fresh.refreshError, isNull);
    final syncedAt = fresh.lastUpdated;

    // Go offline and try again an hour later.
    online = false;
    clock.advance(const Duration(hours: 1));
    container.invalidate(refreshAllAccountsProvider);
    final outcomes = await container.read(
      refreshAllAccountsProvider(force: true).future,
    );
    expect(outcomes.single.refreshed, isFalse);

    container.invalidate(accountsOverviewControllerProvider);
    final stale = (await container.read(accountsOverviewControllerProvider.future)).single;

    // Cached values survive, still stamped with when they were actually
    // fetched — not silently re-dated to now.
    expect(stale.commissions.completed, 3);
    expect(stale.lastUpdated, syncedAt);
    expect(stale.refreshError, contains("Couldn't reach HoYoLab"));
    // Resin keeps ticking from the stored anchor while offline.
    expect(stale.resin, greaterThan(fresh.resin));
  });
}
