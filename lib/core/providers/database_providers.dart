import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalog/catalog_database.dart';
import '../database/user_database.dart';

part 'database_providers.g.dart';

/// The seeded catalog database, resolved once (async) before `runApp` and
/// handed in via `ProviderScope(overrides: ...)` in `main.dart`. Kept as a
/// plain, non-generated provider so nothing here depends on async codegen
/// for a resource that's static once loaded.
final catalogDatabaseProvider = Provider<CatalogDatabase>((ref) {
  throw UnimplementedError('catalogDatabaseProvider must be overridden in main.dart.');
});

@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final db = UserDatabase();
  ref.onDispose(db.close);
  return db;
}
