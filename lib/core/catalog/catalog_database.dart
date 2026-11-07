import 'package:drift/drift.dart';

import 'tables/catalog_metadata_table.dart';
import 'tables/characters_table.dart';
import 'tables/domains_table.dart';
import 'tables/exp_curves_table.dart';
import 'tables/game_rules_table.dart';
import 'tables/materials_table.dart';
import 'tables/requirements_tables.dart';
import 'tables/weapons_table.dart';

part 'catalog_database.g.dart';

/// Read-only reference data (materials, domains, characters, game rules),
/// loaded from `catalog.sqlite` in production. No UUID/updatedAt/deletedAt
/// triad — that rule is scoped to the user's own tables.
///
/// Writable at the connection level for now (so a seed function can
/// populate it) — true read-only enforcement plus bundle integrity
/// verification is the future bundle-installer's job, not this layer's.
@DriftDatabase(
  tables: [
    CatalogMetadata,
    GameRules,
    Materials,
    Domains,
    DomainDrops,
    Characters,
    Weapons,
    ExpCurves,
    AscensionRequirements,
    TalentRequirements,
  ],
)
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());
}
