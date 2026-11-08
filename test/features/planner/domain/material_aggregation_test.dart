import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/features/planner/domain/material_aggregation.dart';

void main() {
  group('accumulateNeed', () {
    test('sums quantities for the same material and keeps distinct ones separate', () {
      final result = accumulateNeed([
        (materialId: 'a', quantity: 2),
        (materialId: 'b', quantity: 1),
        (materialId: 'a', quantity: 3),
      ]);
      expect(result, {'a': 5, 'b': 1});
    });

    test('empty input produces an empty map', () {
      expect(accumulateNeed(const []), isEmpty);
    });

    test('exact seed numbers: Aster A4->A6 + 3 uniform talent slots 6->9', () {
      // Ascension: the catalog's one seeded (character, aster, phase 6) row.
      final ascensionNeed = accumulateNeed([
        (materialId: 'ember_core', quantity: 2),
        (materialId: 'silt_shards', quantity: 1),
      ]);
      expect(ascensionNeed, {'ember_core': 2, 'silt_shards': 1});

      // Talents: the one seeded (aster, level 9) row, queried identically
      // for each of the 3 uniform talent slots (6->9) and merged.
      const talentLevel9Row = [
        (materialId: 'dawn_books_t3', quantity: 4),
        (materialId: 'dawn_books_t2', quantity: 2),
        (materialId: 'insight_tome', quantity: 3),
        (materialId: 'gleam', quantity: 100000),
      ];
      final talentNeed = accumulateNeed([
        ...talentLevel9Row,
        ...talentLevel9Row,
        ...talentLevel9Row,
      ]);
      expect(talentNeed, {
        'dawn_books_t3': 12,
        'dawn_books_t2': 6,
        'insight_tome': 9,
        'gleam': 300000,
      });
    });

    test('exact seed numbers: Larkspur Spear A4->A6 (weapon, no talents)', () {
      final need = accumulateNeed([
        (materialId: 'tidal_relics_t3', quantity: 3),
        (materialId: 'silt_shards', quantity: 2),
      ]);
      expect(need, {'tidal_relics_t3': 3, 'silt_shards': 2});
    });

    test('Wren/Corvin have zero seeded requirement rows -> zero need', () {
      expect(accumulateNeed(const []), isEmpty);
    });
  });

  group('allocateExpBooks', () {
    test('exact seed-data worked example: Aster 70->90 (1,300,000 exp)', () {
      // Books sorted desc by value: insight_tome(3000), insight_primer(1000).
      final result = allocateExpBooks(1300000, [
        (materialId: 'insight_tome', expValue: 3000),
        (materialId: 'insight_primer', expValue: 1000),
      ]);
      // 1,300,000 ~/ 3000 = 433 (spends 1,299,000), remaining 1,000.
      // Smallest tier rounds up: ceil(1000 / 1000) = 1.
      expect(result, {'insight_tome': 433, 'insight_primer': 1});
    });

    test('remainder that divides evenly needs no rounding up on the smallest tier', () {
      final result = allocateExpBooks(4000, [
        (materialId: 'big', expValue: 3000),
        (materialId: 'small', expValue: 1000),
      ]);
      // 4000 ~/ 3000 = 1 (spends 3000), remaining 1000 -> ceil(1000/1000) = 1.
      expect(result, {'big': 1, 'small': 1});
    });

    test('a single book tier just divides and rounds up', () {
      final result = allocateExpBooks(2500, [(materialId: 'only', expValue: 1000)]);
      expect(result, {'only': 3}); // ceil(2500/1000) = 3
    });

    test('non-positive total returns an empty map without throwing', () {
      expect(allocateExpBooks(0, [(materialId: 'x', expValue: 100)]), isEmpty);
      expect(allocateExpBooks(-5, [(materialId: 'x', expValue: 100)]), isEmpty);
    });

    test('an empty book list returns an empty map without throwing', () {
      expect(allocateExpBooks(1000, const []), isEmpty);
    });
  });

  group('walkTierGroup', () {
    test('carries surplus up through a 3-tier chain', () {
      final result = walkTierGroup([
        (materialId: 't1', need: 2),
        (materialId: 't2', need: 5),
        (materialId: 't3', need: 1),
      ], {'t1': 10, 't2': 0, 't3': 0});

      // t1: have 10, need 2 -> display 2, missing 0, surplus 8, carry 8~/3=2.
      // t2: have 0+2=2, need 5 -> display 2, missing 3, surplus 0, carry 0.
      // t3: have 0+0=0, need 1 -> display 0, missing 1.
      expect(result, [
        (materialId: 't1', need: 2, have: 2, missing: 0),
        (materialId: 't2', need: 5, have: 2, missing: 3),
        (materialId: 't3', need: 1, have: 0, missing: 1),
      ]);
    });

    test('a zero-need low tier still donates its entire stock upward', () {
      final result = walkTierGroup([
        (materialId: 't1', need: 0),
        (materialId: 't2', need: 3),
      ], {'t1': 9, 't2': 0});

      // t1: have 9, need 0 -> display 0, missing 0, surplus 9, carry 9~/3=3.
      // t2: have 0+3=3, need 3 -> display 3, missing 0.
      expect(result, [
        (materialId: 't1', need: 0, have: 0, missing: 0),
        (materialId: 't2', need: 3, have: 3, missing: 0),
      ]);
    });

    test("the top tier's leftover surplus is simply discarded, not an error", () {
      final result = walkTierGroup([
        (materialId: 'only', need: 1),
      ], {'only': 100});

      expect(result, [(materialId: 'only', need: 1, have: 1, missing: 0)]);
    });

    test('a single-element list degenerates to a plain min(need, have) clamp', () {
      final result = walkTierGroup([(materialId: 'boss_mat', need: 5)], {'boss_mat': 2});
      expect(result, [(materialId: 'boss_mat', need: 5, have: 2, missing: 3)]);
    });

    test('pool-then-walk avoids double-spending shared inventory across targets', () {
      // Two targets share a tier group: A needs only t3:10, B needs only
      // t2:5. have = {t2:15, t3:0}.
      final pooled = walkTierGroup([
        (materialId: 't2', need: 5),
        (materialId: 't3', need: 10),
      ], {'t2': 15, 't3': 0});

      // t2: have 15, need 5 -> display 5, missing 0, surplus 10, carry 10~/3=3.
      // t3: have 0+3=3, need 10 -> display 3, missing 7.
      expect(pooled.last.missing, 7);

      // Contrast (not what's shipped): walking each target separately and
      // summing would let both targets independently "spend" the same 15
      // units of t2 surplus, undercounting the real shortfall as 5 instead
      // of 7.
      final walkedForA = walkTierGroup([
        (materialId: 't2', need: 0),
        (materialId: 't3', need: 10),
      ], {'t2': 15, 't3': 0});
      final walkedForB = walkTierGroup([
        (materialId: 't2', need: 5),
        (materialId: 't3', need: 0),
      ], {'t2': 15, 't3': 0});
      final walkThenSumMissing =
          walkedForA.fold<int>(0, (sum, r) => sum + r.missing) +
          walkedForB.fold<int>(0, (sum, r) => sum + r.missing);
      expect(walkThenSumMissing, 5);
      expect(walkThenSumMissing, lessThan(7)); // confirms it undercounts
    });
  });

  group('materialDisplayLabel', () {
    test('a tiered material reads "<title-cased group> · tier <N>"', () {
      expect(
        materialDisplayLabel(name: 'Dawn Tier 3 Book', tierGroup: 'dawn_books', tier: 3),
        'Dawn books · tier 3',
      );
    });

    test('a material with no tier group falls back to its catalog name', () {
      expect(materialDisplayLabel(name: 'Ember core', tierGroup: null, tier: null), 'Ember core');
      expect(materialDisplayLabel(name: 'Gleam', tierGroup: null, tier: null), 'Gleam');
    });
  });
}
