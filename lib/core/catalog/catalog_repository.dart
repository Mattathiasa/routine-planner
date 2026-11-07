import 'package:drift/drift.dart';

import 'catalog_database.dart';

/// Thin read-only wrapper over [CatalogDatabase]. No aggregation logic —
/// that's a future Planner-screen feature built on top of these queries.
class CatalogRepository {
  CatalogRepository(this._db);

  final CatalogDatabase _db;

  Future<String?> gameRule(String key) async {
    final row = await (_db.select(
      _db.gameRules,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<int?> intGameRule(String key) async {
    final value = await gameRule(key);
    return value == null ? null : int.parse(value);
  }

  Future<Material?> materialById(String id) {
    return (_db.select(_db.materials)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Material>> materialsByTierGroup(String tierGroup) {
    return (_db.select(_db.materials)
          ..where((t) => t.tierGroup.equals(tierGroup))
          ..orderBy([(t) => OrderingTerm.asc(t.tier)]))
        .get();
  }

  Future<List<Domain>> allDomains() => _db.select(_db.domains).get();

  Future<List<Character>> allCharacters() {
    return (_db.select(_db.characters)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<List<Weapon>> allWeapons() {
    return (_db.select(_db.weapons)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  /// Materials of one [category] (`'tieredMaterial'|'bossMaterial'|
  /// 'expBook'|'currency'`), ordered by id for deterministic results. Used
  /// to find "the" currency material for derived Mora need — if the
  /// catalog ever grows a second `'currency'` row, callers that want a
  /// single material currently just take the first result, which is a
  /// guess, not a real resolution (nothing in the schema marks which
  /// currency material is canonical).
  Future<List<Material>> materialsByCategory(String category) {
    return (_db.select(_db.materials)
          ..where((t) => t.category.equals(category))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<List<Material>> materialsForDomain(String domainId) {
    return (_db.select(_db.materials)..where((t) => t.domainId.equals(domainId))).get();
  }

  Future<List<DomainDrop>> dropsForDomain(String domainId) {
    return (_db.select(_db.domainDrops)..where((t) => t.domainId.equals(domainId))).get();
  }

  /// Every domain with at least one [DomainDrops] row open on [serverDate]
  /// (per [isoWeekday] of that date — never the phone's local clock).
  Future<List<Domain>> domainsOpenOn(DateTime serverDate) async {
    final drops = await _db.select(_db.domainDrops).get();
    final openDomainIds = <String>{
      for (final drop in drops)
        if (_isOpenOnWeekday(drop.weekdayMask, serverDate.weekday)) drop.domainId,
    };
    if (openDomainIds.isEmpty) return [];
    return (_db.select(_db.domains)..where((t) => t.id.isIn(openDomainIds))).get();
  }

  Future<bool> isDomainOpenOn(String domainId, DateTime serverDate) async {
    final drops = await (_db.select(
      _db.domainDrops,
    )..where((t) => t.domainId.equals(domainId))).get();
    return drops.any((drop) => _isOpenOnWeekday(drop.weekdayMask, serverDate.weekday));
  }

  /// Bit0 = Monday. Sunday is always open, regardless of the stored mask.
  bool _isOpenOnWeekday(int weekdayMask, int isoWeekday) {
    if (isoWeekday == DateTime.sunday) return true;
    final bitIndex = isoWeekday - DateTime.monday;
    return (weekdayMask & (1 << bitIndex)) != 0;
  }

  Future<List<AscensionRequirement>> ascensionRequirements(
    String entityKind,
    String entityId, {
    int? fromPhaseExclusive,
    int? toPhaseInclusive,
  }) {
    return (_db.select(_db.ascensionRequirements)..where((t) {
      var predicate = t.entityKind.equals(entityKind) & t.entityId.equals(entityId);
      if (fromPhaseExclusive != null) {
        predicate = predicate & t.phase.isBiggerThanValue(fromPhaseExclusive);
      }
      if (toPhaseInclusive != null) {
        predicate = predicate & t.phase.isSmallerOrEqualValue(toPhaseInclusive);
      }
      return predicate;
    })).get();
  }

  Future<List<TalentRequirement>> talentRequirements(
    String entityId, {
    int? fromLevelExclusive,
    int? toLevelInclusive,
  }) {
    return (_db.select(_db.talentRequirements)..where((t) {
      var predicate = t.entityId.equals(entityId);
      if (fromLevelExclusive != null) {
        predicate = predicate & t.level.isBiggerThanValue(fromLevelExclusive);
      }
      if (toLevelInclusive != null) {
        predicate = predicate & t.level.isSmallerOrEqualValue(toLevelInclusive);
      }
      return predicate;
    })).get();
  }

  Future<ExpCurve?> expCurve(String entityKind, int level) {
    return (_db.select(
      _db.expCurves,
    )..where((t) => t.entityKind.equals(entityKind) & t.level.equals(level))).getSingleOrNull();
  }

  /// Every seeded EXP-curve row for `fromLevelInclusive <= level <
  /// toLevelExclusive` — the row at `level = L` is the cost of the step
  /// *leaving* L, so going `current -> goal` needs levels
  /// `[current, goal)`, not `(current, goal]`. Sparse seed data means most
  /// levels in a real range won't have a row; callers sum whatever comes
  /// back and treat the rest as contributing 0, not an error.
  Future<List<ExpCurve>> expCurvesInRange(
    String entityKind, {
    required int fromLevelInclusive,
    required int toLevelExclusive,
  }) {
    return (_db.select(_db.expCurves)..where(
      (t) =>
          t.entityKind.equals(entityKind) &
          t.level.isBiggerOrEqualValue(fromLevelInclusive) &
          t.level.isSmallerThanValue(toLevelExclusive),
    )).get();
  }

  Future<Character?> characterById(String id) {
    return (_db.select(_db.characters)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Weapon?> weaponById(String id) {
    return (_db.select(_db.weapons)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<String> catalogVersion() async {
    final row = await (_db.select(
      _db.catalogMetadata,
    )..where((t) => t.id.equals('catalog'))).getSingle();
    return row.version;
  }
}
