import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// A character or weapon the user is tracking ascension/level/talent
/// progress for. `entityId` points at a row in the separate catalog
/// database — plain text, app-validated, since SQLite can't enforce FKs
/// across attached DBs. "Done" and "% in hand" are computed at read time,
/// never stored.
class PlannerTargets extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// `'character'` or `'weapon'`.
  TextColumn get entityKind => text()();

  /// Catalog `characters.id` or `weapons.id`.
  TextColumn get entityId => text()();

  /// Weapon targets only: a user-chosen display link to a character target
  /// (e.g. "for Aster"). Many characters can share a weapon type, so this
  /// isn't catalog data.
  TextColumn get linkedCharacterId => text().nullable()();

  IntColumn get currentLevel => integer()();
  IntColumn get goalLevel => integer()();
  IntColumn get currentAscension => integer()();
  IntColumn get goalAscension => integer()();

  // Null for weapons. Always three flat (current, goal) pairs for
  // characters — "uniform across all three talents" is a read-time display
  // choice (check the three pairs for equality), not a stored flag.
  IntColumn get talent1Current => integer().nullable()();
  IntColumn get talent1Goal => integer().nullable()();
  IntColumn get talent2Current => integer().nullable()();
  IntColumn get talent2Goal => integer().nullable()();
  IntColumn get talent3Current => integer().nullable()();
  IntColumn get talent3Goal => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// How many of a given catalog material the user currently owns.
@TableIndex.sql(
  'CREATE UNIQUE INDEX material_inventory_unique ON material_inventory(profile_id, material_id) '
  'WHERE deleted_at IS NULL',
)
class MaterialInventory extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Catalog `materials.id`.
  TextColumn get materialId => text()();

  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
