import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';

void main() {
  late CatalogDatabase db;

  setUp(() async {
    db = await openSeedCatalogDatabaseInMemory();
  });

  tearDown(() => db.close());

  test('catalog metadata and game rules are seeded', () async {
    final metadata = await (db.select(
      db.catalogMetadata,
    )..where((t) => t.id.equals('catalog'))).getSingle();
    expect(metadata.version, '0.1.0-seed');

    final rules = await db.select(db.gameRules).get();
    expect(rules.map((r) => r.key), contains('resin_cap'));
  });

  test('characters, weapons, domains and materials are queryable', () async {
    expect(
      (await (db.select(db.characters)..where((t) => t.id.equals('aster'))).getSingle()).name,
      'Aster',
    );
    expect(
      (await (db.select(
        db.weapons,
      )..where((t) => t.id.equals('larkspur_spear'))).getSingle()).name,
      'Larkspur Spear',
    );
    expect(await db.select(db.domains).get(), hasLength(5));
    expect(await db.select(db.materials).get(), isNotEmpty);
  });

  test('domain_drops, exp_curves and requirements are queryable', () async {
    expect(await db.select(db.domainDrops).get(), isNotEmpty);
    expect(
      (await (db.select(
        db.expCurves,
      )..where((t) => t.entityKind.equals('character') & t.level.equals(70))).getSingle()).expToNext,
      500000,
    );
    expect(
      await (db.select(db.ascensionRequirements)..where(
        (t) => t.entityKind.equals('character') & t.entityId.equals('aster'),
      )).get(),
      isNotEmpty,
    );
    expect(
      await (db.select(
        db.talentRequirements,
      )..where((t) => t.entityId.equals('aster'))).get(),
      isNotEmpty,
    );
  });
}
