import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/core/navigation/app_router.dart';
import 'package:routine_planner/core/providers/database_providers.dart';
import 'package:routine_planner/core/theme/app_theme.dart';

void main() {
  testWidgets('bottom nav switches tabs; gear reaches Settings; back returns', (tester) async {
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
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original Resin'), findsOneWidget);

    await tester.tap(find.text('Resin'));
    await tester.pumpAndSettle();
    expect(find.text('Resin — coming soon'), findsOneWidget);

    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    expect(find.text('Planner — coming soon'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Original Resin'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings — coming soon'), findsOneWidget);

    await tester.tap(find.text('Today')); // the "‹ Today" back-link
    await tester.pumpAndSettle();
    expect(find.text('Original Resin'), findsOneWidget);
  });
}
