import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/bundled/bundled_catalog.dart';
import 'package:routine_planner/core/catalog/bundled/bundled_catalog_data.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/catalog_repository.dart';
import 'package:routine_planner/features/planner/domain/material_aggregation.dart';

/// Integrity checks over the generated real-data catalog. These verify the
/// *build output's internal consistency* (references resolve, tiers
/// ascend, every entity is plannable) — they deliberately never assert
/// specific game numbers, which are community-sourced and unverified
/// (docs/ASSUMPTIONS.md).
void main() {
  late CatalogDatabase db;
  late CatalogRepository repo;

  setUpAll(() async {
    db = await openBundledCatalogDatabaseInMemory();
    repo = CatalogRepository(db);
  });

  tearDownAll(() => db.close());

  test('metadata carries the dataset version stamp and source hash', () async {
    expect(await repo.catalogVersion(), bundledCatalogVersion);
    expect(bundledCatalogVersion, startsWith('genshin-db-'));
    final row = await db.select(db.catalogMetadata).getSingle();
    expect(row.sha256, hasLength(64));
  });

  test('exactly one currency material exists (the planner takes .first)', () async {
    final currencies = await repo.materialsByCategory('currency');
    expect(currencies.map((m) => m.id), ['mora']);
  });

  test('every EXP book has a positive parsed EXP value', () async {
    final books = await repo.materialsByCategory('expBook');
    expect(books, isNotEmpty);
    for (final book in books) {
      expect(book.expValue, isNotNull, reason: book.id);
      expect(book.expValue!, greaterThan(0), reason: book.id);
    }
  });

  test('all requirement rows reference existing materials', () async {
    final materialIds = {for (final m in await repo.allMaterials()) m.id};
    for (final r in await db.select(db.ascensionRequirements).get()) {
      expect(materialIds, contains(r.materialId));
    }
    for (final r in await db.select(db.talentRequirements).get()) {
      expect(materialIds, contains(r.materialId));
    }
  });

  test('all drop rows reference existing domains and materials, with open days', () async {
    final materialIds = {for (final m in await repo.allMaterials()) m.id};
    final domainIds = {for (final d in await repo.allDomains()) d.id};
    final drops = await db.select(db.domainDrops).get();
    expect(drops, isNotEmpty);
    for (final drop in drops) {
      expect(domainIds, contains(drop.domainId));
      expect(materialIds, contains(drop.materialId));
      expect(drop.weekdayMask, greaterThan(0));
    }
  });

  test('every talent/weapon domain has at least one drop row', () async {
    final drops = await db.select(db.domainDrops).get();
    final domainsWithDrops = {for (final d in drops) d.domainId};
    for (final domain in await repo.allDomains()) {
      if (domain.kind == 'boss') continue;
      expect(domainsWithDrops, contains(domain.id), reason: domain.id);
    }
  });

  test('every character is fully plannable: 6 ascension phases, talents 2..10', () async {
    final characters = await repo.allCharacters();
    expect(characters, isNotEmpty);
    for (final character in characters) {
      final ascension = await repo.ascensionRequirements('character', character.id);
      expect({for (final r in ascension) r.phase}, {1, 2, 3, 4, 5, 6}, reason: character.id);
      final talents = await repo.talentRequirements(character.id);
      expect({for (final r in talents) r.level}, {2, 3, 4, 5, 6, 7, 8, 9, 10},
          reason: character.id);
    }
  });

  test('weapons have every ascension phase their rarity allows', () async {
    final weapons = await repo.allWeapons();
    expect(weapons, isNotEmpty);
    for (final weapon in weapons) {
      final ascension = await repo.ascensionRequirements('weapon', weapon.id);
      // 1- and 2-star weapons stop at the 4th ascension (they cap at a
      // lower level than the rest); everything 3-star and up has all 6.
      final expected = weapon.rarity <= 2 ? {1, 2, 3, 4} : {1, 2, 3, 4, 5, 6};
      expect(
        {for (final r in ascension) r.phase},
        expected,
        reason: '${weapon.id} (rarity ${weapon.rarity})',
      );
    }
  });

  test('tier groups have distinct, ascending tiers', () async {
    final materials = await repo.allMaterials();
    final groups = {for (final m in materials) if (m.tierGroup != null) m.tierGroup!};
    expect(groups, isNotEmpty);
    for (final group in groups) {
      final members = await repo.materialsByTierGroup(group);
      expect(members.length, greaterThan(1), reason: group);
      final tiers = [for (final m in members) m.tier!];
      expect(tiers.toSet().length, tiers.length, reason: '$group has duplicate tiers');
      final sorted = [...tiers]..sort();
      expect(tiers, sorted, reason: '$group not returned ascending');
    }
  });

  test('a real tier group feeds walkTierGroup end-to-end', () async {
    final materials = await repo.allMaterials();
    final group =
        materials.firstWhere((m) => m.tierGroup != null && m.domainId != null).tierGroup!;
    final family = await repo.materialsByTierGroup(group);
    final results = walkTierGroup(
      [for (final m in family) (materialId: m.id, need: 6)],
      {family.first.id: 9}, // surplus at the lowest tier carries up 3:1
    );
    expect(results.first.missing, 0);
    expect(results[1].have, 1, reason: '3 surplus low-tier units carry up as 1');
  });
}
