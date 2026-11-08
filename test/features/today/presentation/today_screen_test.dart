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
import 'package:routine_planner/features/today/presentation/today_screen.dart';

void main() {
  testWidgets('renders open domains and logging a run mutates the DB', (tester) async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    // 2026-11-03 is a Tuesday — Dawn (talent) and the two boss domains are
    // open; Tidal and Mire also open/closed per their own masks.
    final fakeClock = FakeClock(DateTime.utc(2026, 11, 3, 12));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(fakeClock),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dawn'), findsOneWidget);
    expect(find.text('Dawn Tier 2 Book'), findsOneWidget);
    expect(find.text('Original Resin'), findsOneWidget);

    // Dawn's cost is 20; confirm the hero card's resin count decreases by
    // exactly that after tapping "Log a run" on the first Dawn row.
    expect(find.text('200'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('180'), findsOneWidget);

    final rows = await userDb.select(userDb.dailyTasks).get();
    expect(rows.any((r) => r.runsDone == 1), isTrue);
  });

  testWidgets('logging a run with insufficient resin shows a SnackBar instead of crashing', (
    tester,
  ) async {
    final catalogDb = await openSeedCatalogDatabaseInMemory();
    final userDb = UserDatabase(NativeDatabase.memory());
    addTearDown(catalogDb.close);
    addTearDown(userDb.close);

    final fakeClock = FakeClock(DateTime.utc(2026, 11, 3, 12));

    // Default test viewport is too small for the tap offset to stay
    // on-screen across repeated taps/rebuilds below the fold.
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDatabaseProvider.overrideWithValue(catalogDb),
          userDatabaseProvider.overrideWithValue(userDb),
          clockProvider.overrideWithValue(fakeClock),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Dawn's cost is 20; a fresh profile starts at 200, so exactly 10 runs
    // exhausts it to 0 — the 11th must throw, not crash.
    final logButton = find.byIcon(Icons.add).first;
    for (var i = 0; i < 10; i++) {
      await tester.tap(logButton);
      await tester.pumpAndSettle();
    }
    final resinRow = await userDb.select(userDb.resinStateTable).getSingle();
    expect(resinRow.v, 0);

    await tester.tap(logButton);
    await tester.pump();

    expect(find.textContaining('Need 20 resin'), findsOneWidget);
  });
}
