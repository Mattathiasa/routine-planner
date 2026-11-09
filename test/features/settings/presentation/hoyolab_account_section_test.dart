import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_web_login.dart';
import 'package:routine_planner/core/providers/hoyolab_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/settings/presentation/hoyolab_account_section.dart';

void main() {
  Future<FakeHoyolabCredentialsStore> pumpSection(
    WidgetTester tester, {
    String? webLoginCookie = 'ltoken_v2=abc; ltuid_v2=1',
  }) async {
    final store = FakeHoyolabCredentialsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hoyolabCredentialsStoreProvider.overrideWithValue(store),
          hoyolabWebLoginProvider.overrideWithValue(FakeHoyolabWebLogin(cookie: webLoginCookie)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HoyolabAccountSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('starts disconnected, and the form stays hidden until the disclaimer is acknowledged', (
    tester,
  ) async {
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
  });

  testWidgets('acknowledging the disclaimer logs in via the WebView, then saving a UID connects', (
    tester,
  ) async {
    final store = await pumpSection(tester, webLoginCookie: 'ltoken_v2=abc; ltuid_v2=1');

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();

    // The fake web login resolves immediately with a cookie, landing
    // straight on the UID-only form — no cookie field, since the WebView
    // login already captured it.
    expect(find.text('Game UID'), findsOneWidget);
    expect(find.text('HoYoLab cookie'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Game UID'), '800000001');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('UID 800000001'), findsOneWidget);

    final saved = await store.read();
    expect(saved, isNotNull);
    expect(saved!.uid, '800000001');
    expect(saved.cookie, 'ltoken_v2=abc; ltuid_v2=1');
  });

  testWidgets('backing out of the WebView login leaves the account disconnected', (tester) async {
    await pumpSection(tester, webLoginCookie: null);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand, continue'));
    await tester.pumpAndSettle();

    expect(find.text('Game UID'), findsNothing);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('disconnecting clears the stored credentials', (tester) async {
    final store = FakeHoyolabCredentialsStore();
    await store.save(cookie: 'c', uid: 'u');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hoyolabCredentialsStoreProvider.overrideWithValue(store),
          hoyolabWebLoginProvider.overrideWithValue(FakeHoyolabWebLogin()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HoyolabAccountSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(await store.read(), isNull);
  });
}
