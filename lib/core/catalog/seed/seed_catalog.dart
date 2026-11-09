import 'package:drift/drift.dart';

import '../catalog_database.dart';
import 'open_catalog_executor.dart';
import 'seed_catalog_data.dart';

/// Populates an already-opened [CatalogDatabase] with the tiny seed
/// dataset. Executor-agnostic: works against an in-memory db (tests), a
/// fresh temp-file db (the dev app, until the real bundle pipeline repo
/// exists), or a future bundle-install dry run — swapping in the real
/// bundle mechanism later changes only how the file gets populated, not
/// this function or any caller of [CatalogDatabase].
Future<void> seedCatalog(CatalogDatabase db) {
  return db.batch((b) {
    b.insertAll(db.catalogMetadata, seedCatalogMetadata);
    b.insertAll(db.gameRules, seedGameRules);
    b.insertAll(db.characters, seedCharacters);
    b.insertAll(db.weapons, seedWeapons);
    b.insertAll(db.domains, seedDomains);
    b.insertAll(db.materials, seedMaterials);
    b.insertAll(db.domainDrops, seedDomainDrops);
    b.insertAll(db.expCurves, seedExpCurves);
    b.insertAll(db.ascensionRequirements, seedAscensionRequirements);
    b.insertAll(db.talentRequirements, seedTalentRequirements);
  });
}

/// Opens a fresh in-memory [CatalogDatabase] and seeds it — the standard
/// entry point for tests and (until the real bundle exists) dev runs.
Future<CatalogDatabase> openSeedCatalogDatabaseInMemory() async {
  final db = CatalogDatabase(createSeedCatalogExecutor());
  final count = await (db.selectOnly(db.catalogMetadata)..addColumns([db.catalogMetadata.version])).get();
  if (count.isEmpty) {
    await seedCatalog(db);
  }
  return db;
}
