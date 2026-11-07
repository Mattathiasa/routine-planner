import 'package:drift/drift.dart';

import '../catalog_database.dart';

/// A tiny, illustrative catalog dataset — enough to exercise every table
/// and support two complete planner targets end-to-end, not a full game
/// dataset. Reuses this project's established placeholder names (Aster,
/// Wren, Corvin, Larkspur Spear, Dawn, Tidal). Weekday masks: bit0 = Monday
/// ... bit5 = Saturday; Sunday is handled as "always open" by the read
/// layer rather than needing bit6 set everywhere.
const _monday = 1 << 0;
const _tuesday = 1 << 1;
const _wednesday = 1 << 2;
const _friday = 1 << 4;
const _saturday = 1 << 5;
const _sunday = 1 << 6;
const _allDays = _monday | _tuesday | _wednesday | (1 << 3) | _friday | _saturday | _sunday;

final seedCatalogMetadata = [
  CatalogMetadataCompanion.insert(id: 'catalog', version: '0.1.0-seed'),
];

final seedGameRules = [
  GameRulesCompanion.insert(key: 'resin_cap', value: '200'),
  GameRulesCompanion.insert(key: 'resin_regen_interval_seconds', value: '480'),
  GameRulesCompanion.insert(key: 'condensed_resin_value', value: '40'),
  GameRulesCompanion.insert(key: 'fragile_or_transient_resin_value', value: '60'),
  GameRulesCompanion.insert(key: 'level_farm_cap', value: '90'),
];

final seedCharacters = [
  CharactersCompanion.insert(
    id: 'aster',
    name: 'Aster',
    rarity: 5,
    element: 'Pyro',
    weaponType: 'polearm',
  ),
  CharactersCompanion.insert(
    id: 'wren',
    name: 'Wren',
    rarity: 4,
    element: 'Hydro',
    weaponType: 'bow',
  ),
  CharactersCompanion.insert(
    id: 'corvin',
    name: 'Corvin',
    rarity: 4,
    element: 'Electro',
    weaponType: 'sword',
  ),
];

final seedWeapons = [
  WeaponsCompanion.insert(
    id: 'larkspur_spear',
    name: 'Larkspur Spear',
    rarity: 5,
    weaponType: 'polearm',
  ),
];

final seedDomains = [
  DomainsCompanion.insert(id: 'dawn', name: 'Dawn', kind: 'talent', costResin: 20),
  DomainsCompanion.insert(id: 'tidal', name: 'Tidal', kind: 'weapon', costResin: 20),
  DomainsCompanion.insert(id: 'mire', name: 'Mire', kind: 'weapon', costResin: 20),
  DomainsCompanion.insert(
    id: 'ember_core_boss',
    name: 'Ember Lair',
    kind: 'boss',
    costResin: 40,
  ),
  DomainsCompanion.insert(
    id: 'weekly_boss',
    name: 'Sundering Rift',
    kind: 'boss',
    resetCadence: Value('weekly'),
    maxRunsPerPeriod: Value(3),
    costResin: 40,
  ),
];

final seedMaterials = [
  MaterialsCompanion.insert(
    id: 'dawn_books_t2',
    name: 'Dawn Tier 2 Book',
    category: 'tieredMaterial',
    tier: Value(2),
    tierGroup: Value('dawn_books'),
    domainId: Value('dawn'),
  ),
  MaterialsCompanion.insert(
    id: 'dawn_books_t3',
    name: 'Dawn Tier 3 Book',
    category: 'tieredMaterial',
    tier: Value(3),
    tierGroup: Value('dawn_books'),
    domainId: Value('dawn'),
  ),
  MaterialsCompanion.insert(
    id: 'tidal_relics_t3',
    name: 'Tidal Tier 3 Relic',
    category: 'tieredMaterial',
    tier: Value(3),
    tierGroup: Value('tidal_relics'),
    domainId: Value('tidal'),
  ),
  MaterialsCompanion.insert(
    id: 'silt_shards',
    name: 'Silt shards',
    category: 'tieredMaterial',
    tier: Value(4),
    tierGroup: Value('silt_shards'),
    domainId: Value('mire'),
  ),
  MaterialsCompanion.insert(
    id: 'ember_core',
    name: 'Ember core',
    category: 'bossMaterial',
    domainId: Value('ember_core_boss'),
  ),
  MaterialsCompanion.insert(
    id: 'stormglass_shard',
    name: 'Stormglass Shard',
    category: 'bossMaterial',
    domainId: Value('weekly_boss'),
  ),
  MaterialsCompanion.insert(
    id: 'insight_primer',
    name: 'Insight Primer',
    category: 'expBook',
    expValue: Value(1000),
  ),
  MaterialsCompanion.insert(
    id: 'insight_tome',
    name: 'Insight Tome',
    category: 'expBook',
    expValue: Value(3000),
  ),
  MaterialsCompanion.insert(id: 'gleam', name: 'Gleam', category: 'currency'),
];

final seedDomainDrops = [
  DomainDropsCompanion.insert(
    id: 'drop_dawn_t2',
    domainId: 'dawn',
    materialId: 'dawn_books_t2',
    weekdayMask: _tuesday | _friday | _sunday,
  ),
  DomainDropsCompanion.insert(
    id: 'drop_dawn_t3',
    domainId: 'dawn',
    materialId: 'dawn_books_t3',
    weekdayMask: _tuesday | _friday | _sunday,
  ),
  DomainDropsCompanion.insert(
    id: 'drop_tidal_t3',
    domainId: 'tidal',
    materialId: 'tidal_relics_t3',
    weekdayMask: _tuesday | _friday | _sunday,
  ),
  DomainDropsCompanion.insert(
    id: 'drop_mire_silt',
    domainId: 'mire',
    materialId: 'silt_shards',
    weekdayMask: _wednesday | _saturday | _sunday,
  ),
  DomainDropsCompanion.insert(
    id: 'drop_ember_core',
    domainId: 'ember_core_boss',
    materialId: 'ember_core',
    weekdayMask: _allDays,
  ),
  DomainDropsCompanion.insert(
    id: 'drop_weekly_token',
    domainId: 'weekly_boss',
    materialId: 'stormglass_shard',
    weekdayMask: _allDays,
  ),
];

final seedExpCurves = [
  ExpCurvesCompanion.insert(
    entityKind: 'character',
    level: 70,
    expToNext: 500000,
    moraToNext: Value(100000),
  ),
  ExpCurvesCompanion.insert(
    entityKind: 'character',
    level: 80,
    expToNext: 800000,
    moraToNext: Value(160000),
  ),
  ExpCurvesCompanion.insert(
    entityKind: 'weapon',
    level: 70,
    expToNext: 200000,
    moraToNext: Value(40000),
  ),
];

final seedAscensionRequirements = [
  AscensionRequirementsCompanion.insert(
    entityKind: 'character',
    entityId: 'aster',
    phase: 6,
    materialId: 'ember_core',
    quantity: 2,
  ),
  AscensionRequirementsCompanion.insert(
    entityKind: 'character',
    entityId: 'aster',
    phase: 6,
    materialId: 'silt_shards',
    quantity: 1,
  ),
  AscensionRequirementsCompanion.insert(
    entityKind: 'weapon',
    entityId: 'larkspur_spear',
    phase: 6,
    materialId: 'tidal_relics_t3',
    quantity: 3,
  ),
  AscensionRequirementsCompanion.insert(
    entityKind: 'weapon',
    entityId: 'larkspur_spear',
    phase: 6,
    materialId: 'silt_shards',
    quantity: 2,
  ),
];

final seedTalentRequirements = [
  TalentRequirementsCompanion.insert(
    entityId: 'aster',
    level: 9,
    materialId: 'dawn_books_t3',
    quantity: 4,
  ),
  TalentRequirementsCompanion.insert(
    entityId: 'aster',
    level: 9,
    materialId: 'dawn_books_t2',
    quantity: 2,
  ),
  TalentRequirementsCompanion.insert(
    entityId: 'aster',
    level: 9,
    materialId: 'insight_tome',
    quantity: 3,
  ),
  TalentRequirementsCompanion.insert(
    entityId: 'aster',
    level: 9,
    materialId: 'gleam',
    quantity: 100000,
  ),
];
