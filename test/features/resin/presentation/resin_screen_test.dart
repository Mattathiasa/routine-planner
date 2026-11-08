import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/hoyolab/data/hoyolab_client.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/resin/presentation/resin_screen.dart';

void main() {
  late UserDatabase userDb;

  Future<void> pumpResinScreen(WidgetTester tester, {required FakeClock clock}) async {
    // The screen is taller than the default test viewport; without this,
    // the outer ListView's sliver virtualization never builds the
    // below-the-fold action/activity sections.
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ResinScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Like [pumpResinScreen], but with a HoYoLab account connected — a
  /// separate helper (rather than an overrides parameter on the one
  /// above) since `Override` isn't part of `flutter_riverpod`'s public
  /// export surface in this Riverpod version to type a parameter with.
  Future<void> pumpResinScreenWithHoyolab(
    WidgetTester tester, {
    required FakeClock clock,
    required HoyolabClient hoyolabClient,
  }) async {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final credentialsStore = FakeHoyolabCredentialsStore();
    await credentialsStore.save(cookie: 'ltoken_v2=abc', uid: '800000001');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(clock),
          hoyolabCredentialsStoreProvider.overrideWithValue(credentialsStore),
          hoyolabClientProvider.overrideWithValue(hoyolabClient),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ResinScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the ring and stat tiles for a fresh (full) profile', (tester) async {
    await pumpResinScreen(tester, clock: FakeClock(DateTime.utc(2026, 1, 1, 12)));

    expect(find.text('200'), findsOneWidget); // ring number
    expect(find.text('of 200'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2)); // "Next +1 in" / "Full at": null at cap
  });

  testWidgets('spending decreases resin and adds an Activity row; undo restores it', (
    tester,
  ) async {
    await pumpResinScreen(tester, clock: FakeClock(DateTime.utc(2026, 1, 1, 12)));

    await tester.tap(find.text('Spend 20'));
    await tester.pumpAndSettle();

    // Ring number and the new Activity row's resultingV both correctly
    // show "180".
    expect(find.text('180'), findsNWidgets(2));
    expect(find.text('Spent 20 · Domain run'), findsOneWidget);

    await tester.tap(find.text('Undo last'));
    await tester.pumpAndSettle();

    // Ring number and the undo Activity row's resultingV both show "200".
    expect(find.text('200'), findsNWidgets(2));
    expect(find.text('Undo: Spent 20 · Domain run'), findsOneWidget);
  });

  testWidgets('using fragile resin on a fresh profile shows a SnackBar instead of crashing', (
    tester,
  ) async {
    await pumpResinScreen(tester, clock: FakeClock(DateTime.utc(2026, 1, 1, 12)));

    await tester.tap(find.text('Use Fragile'));
    await tester.pump(); // let the SnackBar animate in

    expect(find.textContaining('Only 0 fragile resin available'), findsOneWidget);
  });

  testWidgets('tapping "Sync from HoYoLab" updates the ring to the fetched value', (tester) async {
    final hoyolabClient = HoyolabClient(
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'retcode': 0,
            'data': {'current_resin': 142, 'max_resin': 200, 'resin_recovery_time': 1000},
          }),
          200,
        ),
      ),
    );

    await pumpResinScreenWithHoyolab(
      tester,
      clock: FakeClock(DateTime.utc(2026, 1, 1, 12)),
      hoyolabClient: hoyolabClient,
    );

    expect(find.text('Sync from HoYoLab'), findsOneWidget);

    await tester.tap(find.text('Sync from HoYoLab'));
    await tester.pumpAndSettle();

    expect(find.text('142'), findsOneWidget); // ring number
  });

  testWidgets('a HoyolabException from the client shows a SnackBar instead of crashing', (
    tester,
  ) async {
    final hoyolabClient = HoyolabClient(
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'retcode': -100, 'message': 'Not logged in', 'data': null}),
          200,
        ),
      ),
    );

    await pumpResinScreenWithHoyolab(
      tester,
      clock: FakeClock(DateTime.utc(2026, 1, 1, 12)),
      hoyolabClient: hoyolabClient,
    );

    await tester.tap(find.text('Sync from HoYoLab'));
    await tester.pump();

    expect(find.text('Not logged in'), findsOneWidget);
  });
}
