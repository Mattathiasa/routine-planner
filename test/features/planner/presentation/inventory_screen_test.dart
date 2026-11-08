import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';
import 'package:routine_planner/features/planner/presentation/inventory_screen.dart';

void main() {
  Future<UserDatabase> pumpInventoryScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
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
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const InventoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return userDb;
  }

  testWidgets('lists every catalog material with its label and a 0 count', (tester) async {
    await pumpInventoryScreen(tester);

    expect(find.text('Dawn books · tier 2', skipOffstage: false), findsOneWidget);
    expect(find.text('Dawn books · tier 3', skipOffstage: false), findsOneWidget);
    expect(find.text('Tidal relics · tier 3', skipOffstage: false), findsOneWidget);
    expect(find.text('Silt shards · tier 4', skipOffstage: false), findsOneWidget);
    expect(find.text('Ember core', skipOffstage: false), findsOneWidget);
    expect(find.text('Stormglass Shard', skipOffstage: false), findsOneWidget);
    expect(find.text('Insight Primer', skipOffstage: false), findsOneWidget);
    expect(find.text('Insight Tome', skipOffstage: false), findsOneWidget);
    expect(find.text('Gleam', skipOffstage: false), findsOneWidget);

    expect(find.byType(TextField), findsNWidgets(9));
    expect(find.text('0', skipOffstage: false), findsNWidgets(9));
  });

  testWidgets('editing a field and submitting persists the new count', (tester) async {
    final userDb = await pumpInventoryScreen(tester);

    final row = find.ancestor(of: find.text('Ember core'), matching: find.byType(Row)).first;
    final field = find.descendant(of: row, matching: find.byType(TextField));

    await tester.enterText(field, '42');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final inventory = await (userDb.select(
      userDb.materialInventory,
    )..where((t) => t.materialId.equals('ember_core'))).getSingle();
    expect(inventory.count, 42);
  });
}
