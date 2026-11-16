import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/catalog/bundled/bundled_catalog.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/database_providers.dart';
import 'core/theme/app_theme.dart';
import 'demo_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalogDb = await openBundledCatalogDatabaseInMemory();
  final container = ProviderContainer(
    overrides: [catalogDatabaseProvider.overrideWithValue(catalogDb)],
  );
  await maybeApplyDemoSeed(container);
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
