import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/current_profile_provider.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/settings/presentation/accounts_section.dart';

// PopupMenuButton/PopupMenuItem are instantiated with a private enum type
// in accounts_section.dart, so `find.byType` (which needs an exact runtime
// type match) can't be used from here — these predicates use the raw,
// type-argument-free `is` check instead, which matches any instantiation.
final _popupMenuButtonFinder = find.byWidgetPredicate((w) => w is PopupMenuButton);

void main() {
  late UserDatabase userDb;

  Future<void> pumpSection(WidgetTester tester) async {
    userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userDatabaseProvider.overrideWithValue(userDb)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer pumpSectionWithContainer(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: [userDatabaseProvider.overrideWithValue(UserDatabase(NativeDatabase.memory()))],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> addProfile(WidgetTester tester, String name) async {
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with exactly one profile, selected', (tester) async {
    await pumpSection(tester);

    expect(find.text('Player'), findsOneWidget);
    expect(find.byType(Radio<String>), findsOneWidget);
  });

  testWidgets('adding a profile shows it and switches to it', (tester) async {
    final container = pumpSectionWithContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final original = await container.read(currentProfileProvider.future);
    await addProfile(tester, 'Alt');

    expect(find.text('Alt'), findsOneWidget);
    final active = await container.read(currentProfileProvider.future);
    expect(active.id, isNot(original.id));
  });

  testWidgets('tapping another profile row switches the active profile', (tester) async {
    final container = pumpSectionWithContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final original = await container.read(currentProfileProvider.future);
    await addProfile(tester, 'Alt');

    final playerRow = find.ancestor(of: find.text('Player'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: playerRow, matching: find.byType(Radio<String>)));
    await tester.pumpAndSettle();

    final active = await container.read(currentProfileProvider.future);
    expect(active.id, original.id);
  });

  testWidgets('renaming updates the displayed name', (tester) async {
    await pumpSection(tester);

    await tester.tap(_popupMenuButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Main');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('delete is disabled when exactly one profile remains', (tester) async {
    await pumpSection(tester);

    await tester.tap(_popupMenuButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Delete (last account)'), findsOneWidget);
  });

  testWidgets('deleting a non-selected profile removes it from the list', (tester) async {
    final container = pumpSectionWithContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await addProfile(tester, 'Alt');

    // Alt is now selected; delete "Player" (not selected).
    final playerRow = find.ancestor(of: find.text('Player'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: playerRow, matching: _popupMenuButtonFinder));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Player'), findsNothing);
    expect(find.text('Alt'), findsOneWidget);
  });

  testWidgets('deleting the selected profile falls back correctly', (tester) async {
    final container = pumpSectionWithContainer(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: AccountsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final original = await container.read(currentProfileProvider.future);
    await addProfile(tester, 'Alt');

    // Alt is selected now; delete it.
    final altRow = find.ancestor(of: find.text('Alt'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: altRow, matching: _popupMenuButtonFinder));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Alt'), findsNothing);
    final active = await container.read(currentProfileProvider.future);
    expect(active.id, original.id);
  });
}
