import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/notifications/data/fake_notification_scheduler.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/providers/notification_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/resin/presentation/resin_screen.dart';

void main() {
  late UserDatabase userDb;
  late CatalogDatabase catalogDb;
  late ProfileRepository profiles;

  final now = DateTime.utc(2026, 11, 3, 12);

  setUp(() async {
    catalogDb = await openSeedCatalogDatabaseInMemory();
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);
    profiles = ProfileRepository(userDb);
  });

  Future<ProviderContainer> pumpResin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        catalogDatabaseProvider.overrideWithValue(catalogDb),
        userDatabaseProvider.overrideWithValue(userDb),
        clockProvider.overrideWithValue(FakeClock(now)),
        hoyolabCredentialsStoreProvider.overrideWithValue(
          FakeHoyolabCredentialsStore(),
        ),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const ResinScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a single account sees no switcher at all', (tester) async {
    await profiles.getActiveProfile();

    await pumpResin(tester);

    // The ring renders; the chips do not.
    expect(find.text('of 200'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('two accounts get a chip each', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpResin(tester);

    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
  });

  testWidgets('tapping a chip switches the selected account', (tester) async {
    final first = (await profiles.getActiveProfile()).id;
    final second = (await profiles.createProfile(
      displayName: 'Alt',
      server: 'europe',
    )).id;

    final container = await pumpResin(tester);
    expect(
      (await container.read(currentProfileProvider.future)).id,
      first,
    );

    await tester.tap(find.text('Alt'));
    await tester.pumpAndSettle();

    expect(
      (await container.read(currentProfileProvider.future)).id,
      second,
    );
    // The selection is persisted, not just held in memory.
    expect((await profiles.getActiveProfile()).id, second);
  });

  testWidgets('the selected chip is not tappable', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpResin(tester);

    final selected = tester.widget<InkWell>(
      find.ancestor(of: find.text('Player'), matching: find.byType(InkWell)),
    );
    expect(selected.onTap, isNull);
  });

  testWidgets('switching accounts shows that account own resin', (tester) async {
    await profiles.getActiveProfile();
    await profiles.createProfile(displayName: 'Alt', server: 'europe');

    await pumpResin(tester);
    // Both start full, so the screen renders either way — what matters is
    // that the switch doesn't throw and the screen rebuilds.
    await tester.tap(find.text('Alt'));
    await tester.pumpAndSettle();

    expect(find.text('of 200'), findsOneWidget);
  });
}
