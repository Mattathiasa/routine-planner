import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/clock/fake_clock.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/clock_providers.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/planner/presentation/planner_screen.dart';
import 'package:routine_planner/features/planner/presentation/target_card.dart';

/// Tapping a target card opens the prefilled edit form (the list↔detail
/// pair behind the shared-element Hero); saving updates in place; the
/// delete action is undoable via snackbar rather than guarded by a
/// confirm dialog.
void main() {
  Future<void> pumpPlanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 3, 12))),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Create one target through the real add flow.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aster').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a card opens the prefilled edit form and saves in place', (tester) async {
    await pumpPlanner(tester);
    expect(find.text('Lv 1 → 90', skipOffstage: false), findsOneWidget);

    await tester.tap(find.byType(TargetCard));
    await tester.pumpAndSettle();

    expect(find.text('Edit target'), findsOneWidget);
    expect(find.widgetWithText(TextField, '90'), findsOneWidget); // prefilled goal level

    await tester.enterText(
      find.widgetWithText(TextField, '1').first, // current level field
      '50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit target'), findsNothing);
    expect(find.text('Lv 50 → 90', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('1 targets ·'), findsOneWidget);
  });

  testWidgets('removing a target shows an undo snackbar that restores it', (tester) async {
    await pumpPlanner(tester);

    await tester.tap(find.byType(TargetCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove target'));
    await tester.pumpAndSettle();

    expect(find.byType(TargetCard), findsNothing);
    expect(find.text('0 targets · 0 materials short'), findsOneWidget);
    expect(find.text('Aster removed from plan'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.byType(TargetCard), findsOneWidget);
    expect(find.textContaining('1 targets ·'), findsOneWidget);
  });
}
