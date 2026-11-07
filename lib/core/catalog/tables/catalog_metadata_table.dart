import 'package:drift/drift.dart';

/// Singleton row (fixed id `'catalog'`) describing which game-patch bundle
/// is loaded. `sha256`/`builtAt` are placeholders for the future real
/// bundle-installer's integrity check — unused by the tiny seed catalog.
class CatalogMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  DateTimeColumn get builtAt => dateTime().nullable()();
  TextColumn get sha256 => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
