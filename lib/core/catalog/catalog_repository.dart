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
