import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/catalog/seed/seed_catalog.dart';
import 'core/navigation/app_router.dart';
import 'core/providers/database_providers.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalogDb = await openSeedCatalogDatabaseInMemory();
  runApp(
    ProviderScope(
      overrides: [catalogDatabaseProvider.overrideWithValue(catalogDb)],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Routine Planner',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
