import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod does not re-export Override; riverpod_annotation does,
// and it is already a direct dependency used across lib/core/providers.
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import 'core/catalog/bundled/bundled_catalog.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/database_providers.dart';
import 'core/theme/app_theme.dart';
import 'demo_seed.dart';

/// Builds the real app container: bundled catalog in memory, demo seed
/// applied if the build asked for it.
///
/// [overrides] exists for `integration_test`, which runs the real app
/// against the real on-device database but swaps the notification
/// scheduler — a real one raises the system permission dialog, which sits
/// outside the Flutter view and intermittently eats taps.
Future<ProviderContainer> createAppContainer({
  List<Override> overrides = const [],
}) async {
  final catalogDb = await openBundledCatalogDatabaseInMemory();
  final container = ProviderContainer(
    overrides: [
      catalogDatabaseProvider.overrideWithValue(catalogDb),
      ...overrides,
    ],
  );
  await maybeApplyDemoSeed(container);
  return container;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await createAppContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const MainApp()),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Routine Planner',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
