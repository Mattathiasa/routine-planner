import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';
import 'package:routine_planner/core/catalog/catalog_repository.dart';
import 'package:routine_planner/core/catalog/seed/seed_catalog.dart';

void main() {
  late CatalogDatabase db;
  late CatalogRepository repository;

  setUp(() async {
    db = await openSeedCatalogDatabaseInMemory();
    repository = CatalogRepository(db);
  });

  tearDown(() => db.close());

  test('gameRule and intGameRule read seeded values', () async {
    expect(await repository.gameRule('resin_cap'), '200');
    expect(await repository.intGameRule('resin_cap'), 200);
    expect(await repository.intGameRule('nonexistent'), isNull);
  });

  test('materialById and materialsByTierGroup', () async {
    expect((await repository.materialById('ember_core'))!.name, 'Ember core');
    final dawnBooks = await repository.materialsByTierGroup('dawn_books');
    expect(dawnBooks.map((m) => m.tier), [2, 3]);
  });

  test('catalogVersion reads the seeded metadata row', () async {
    expect(await repository.catalogVersion(), '0.1.0-seed');
  });

  group('domainsOpenOn / isDomainOpenOn', () {
    // Nov 3 2026 = Tuesday, Nov 4 = Wednesday, Nov 8 = Sunday, Nov 9 = Monday.
    // Dawn/Tidal are open Tue/Fri/Sun; Mire is open Wed/Sat/Sun; the boss
    // domains are open every day.
    test('a non-Sunday day follows the stored weekday mask', () async {
      final tuesday = DateTime.utc(2026, 11, 3);
      expect(await repository.isDomainOpenOn('dawn', tuesday), isTrue);
      expect(await repository.isDomainOpenOn('tidal', tuesday), isTrue);
      expect(await repository.isDomainOpenOn('mire', tuesday), isFalse);

      final monday = DateTime.utc(2026, 11, 9);
      expect(await repository.isDomainOpenOn('dawn', monday), isFalse);
      expect(await repository.isDomainOpenOn('mire', monday), isFalse);
      expect(await repository.isDomainOpenOn('ember_core_boss', monday), isTrue);

      final openOnTuesday = (await repository.domainsOpenOn(tuesday)).map((d) => d.id).toSet();
      expect(openOnTuesday, containsAll(['dawn', 'tidal', 'ember_core_boss', 'weekly_boss']));
      expect(openOnTuesday.contains('mire'), isFalse);
    });

    test("Sunday is open even for a mask that excludes Sunday's bit", () async {
      // Isolated fixture: a mask with only Tuesday's bit set, no Sunday —
      // isolates the "Sunday opens all" override from any other row that
      // happens to also set Sunday's bit.
      const tuesdayOnlyMask = 1 << 1;
      await db.into(db.domains).insert(
        DomainsCompanion.insert(id: 'no_sunday_bit', name: 'Test', kind: 'talent', costResin: 20),
      );
      await db.into(db.domainDrops).insert(
        DomainDropsCompanion.insert(
          id: 'no_sunday_bit_drop',
          domainId: 'no_sunday_bit',
          materialId: 'dawn_books_t2',
          weekdayMask: tuesdayOnlyMask,
        ),
      );

      expect(
        await repository.isDomainOpenOn('no_sunday_bit', DateTime.utc(2026, 11, 8)), // Sunday
        isTrue,
      );
      expect(
        await repository.isDomainOpenOn('no_sunday_bit', DateTime.utc(2026, 11, 3)), // Tuesday
        isTrue,
      );
      expect(
        await repository.isDomainOpenOn('no_sunday_bit', DateTime.utc(2026, 11, 9)), // Monday
        isFalse,
      );
    });
  });
}
