import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_web_login.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/settings/presentation/hoyolab_account_section.dart';

void main() {
  /// Credentials are keyed by profile id now, so tests need the id the
  /// lazily-bootstrapped profile actually got.
  Future<
    ({
      FakeHoyolabCredentialsStore store,
      FakeHoyolabWebLogin webLogin,
      String profileId,
    })
  >
  pumpSection(
    WidgetTester tester, {
    String? webLoginCookie = 'ltoken_v2=abc; ltuid_v2=1',
    bool connected = false,
  }) async {
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    final profileId = (await ProfileRepository(userDb).getActiveProfile()).id;

    final store = FakeHoyolabCredentialsStore();
    if (connected) {
      await store.save(profileId: profileId, cookie: 'c', uid: 'u');
    }
    final webLogin = FakeHoyolabWebLogin(cookie: webLoginCookie);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userDatabaseProvider.overrideWithValue(userDb),
          hoyolabCredentialsStoreProvider.overrideWithValue(store),
          hoyolabWebLoginProvider.overrideWithValue(webLogin),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HoyolabAccountSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (store: store, webLogin: webLogin, profileId: profileId);
  }

  testWidgets(
    'starts disconnected, and the form stays hidden until the disclaimer is acknowledged',
    (tester) async {
      await pumpSection(tester);

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Connect HoYoLab account?'), findsOneWidget);
      expect(find.text('Game UID'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Game UID'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
    },
  );

  testWidgets(
    'acknowledging the disclaimer logs in via the WebView, then saving a UID connects',
    (tester) async {
      final session = await pumpSection(
        tester,
        webLoginCookie: 'ltoken_v2=abc; ltuid_v2=1',
      );

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand, continue'));
      await tester.pumpAndSettle();

      // The fake web login resolves immediately with a cookie, landing
      // straight on the UID-only form — no cookie field, since the WebView
      // login already captured it.
      expect(find.text('Game UID'), findsOneWidget);
      expect(find.text('HoYoLab cookie'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Game UID'),
        '800000001',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('UID 800000001'), findsOneWidget);

      final saved = await session.store.read(session.profileId);
      expect(saved, isNotNull);
      expect(saved!.uid, '800000001');
      expect(saved.cookie, 'ltoken_v2=abc; ltuid_v2=1');
    },
  );

  testWidgets(
    'backing out of the WebView login leaves the account disconnected',
    (tester) async {
      await pumpSection(tester, webLoginCookie: null);

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand, continue'));
      await tester.pumpAndSettle();

      expect(find.text('Game UID'), findsNothing);
      expect(find.text('Not connected'), findsOneWidget);
    },
  );

  testWidgets('disconnecting clears the stored credentials', (tester) async {
    final session = await pumpSection(tester, connected: true);

    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(await session.store.read(session.profileId), isNull);
  });

  testWidgets('signs out of HoYoLab before showing the login, not after', (
    tester,
  ) async {
    final session = await pumpSection(tester);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();

    // Order matters: clearing afterwards would still hand back the old
    // account's session on this very connect.
    expect(session.webLogin.calls, ['clearSession', 'captureCookie']);
  });

  testWidgets('two profiles can hold two different HoYoLab logins', (
    tester,
  ) async {
    // The regression this guards: with one shared cookie jar and no
    // sign-out, connecting a second profile silently re-captured the first
    // account's session, so every profile pointed at one HoYoLab account.
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);
    final profiles = ProfileRepository(userDb);
    final first = (await profiles.getActiveProfile()).id;
    final second = (await profiles.createProfile(
      displayName: 'Second',
      server: 'europe',
    )).id;

    final store = FakeHoyolabCredentialsStore();
    final webLogin = FakeHoyolabWebLogin();
    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(userDb),
        hoyolabCredentialsStoreProvider.overrideWithValue(store),
        hoyolabWebLoginProvider.overrideWithValue(webLogin),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HoyolabAccountSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> connectAs(String cookie, String uid) async {
      webLogin.cookie = cookie;
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand, continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Game UID'), uid);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await connectAs('ltoken_v2=account-one', '800000001');

    // Switch accounts exactly the way the Accounts section does.
    await profiles.selectProfile(second);
    container.invalidate(currentProfileProvider);
    await tester.pumpAndSettle();

    await connectAs('ltoken_v2=account-two', '700000002');

    final one = await store.read(first);
    final two = await store.read(second);
    expect(one!.cookie, 'ltoken_v2=account-one');
    expect(one.uid, '800000001');
    expect(two!.cookie, 'ltoken_v2=account-two');
    expect(two.uid, '700000002');
  });
}
