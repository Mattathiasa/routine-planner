// Builds the read-only catalog from the vendored genshin-db extract.
//
//   dart run tool/build_catalog.dart [--scope narrow|full]
//
// Emits:
//   1. lib/core/catalog/bundled/bundled_catalog_data.dart  (generated rows)
//   2. build/catalog/catalog.sqlite + manifest.json        (version-stamped)
//
// Every mapping here is mechanical — names, numbers, weekday schedules and
// tier chains come straight from the dataset (tier chains via the game's
// own 3:1 crafting recipes). A material the rules can't classify fails the
// build; nothing is ever guessed. See docs/ASSUMPTIONS.md for the few
// constants (resin costs per run, game rules) that are community knowledge
// rather than dataset fields.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:routine_planner/core/catalog/catalog_database.dart';

const _vendorPath = 'tool/data/vendor/genshin_db_extract.json';
const _scopePath = 'tool/data/scope_narrow.json';
const _dartOutPath = 'lib/core/catalog/bundled/bundled_catalog_data.dart';
const _sqliteOutDir = 'build/catalog';

// Community-documented constants not present as dataset fields
// (docs/ASSUMPTIONS.md): resin cost per run by farm kind.
const _domainRunCost = 20;
const _normalBossRunCost = 40;
const _weeklyBossRunCost = 60;
const _weeklyBossDiscountedRunsPerWeek = 3;

const _dayBits = {
  'Monday': 1 << 0,
  'Tuesday': 1 << 1,
  'Wednesday': 1 << 2,
  'Thursday': 1 << 3,
  'Friday': 1 << 4,
  'Saturday': 1 << 5,
  'Sunday': 1 << 6,
};
final _allDaysMask = _dayBits.values.reduce((a, b) => a | b);

String slug(String name) =>
    name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

typedef Json = Map<String, dynamic>;

class MaterialRow {
  MaterialRow({
    required this.id,
    required this.name,
    required this.category,
    this.tier,
    this.tierGroup,
    this.domainId,
    this.expValue,
  });
  final String id;
  final String name;
  final String category;
  final int? tier;
  final String? tierGroup;
  final String? domainId;
  final int? expValue;
}

class DomainRow {
  DomainRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.costResin,
    this.resetCadence = 'daily',
    this.maxRunsPerPeriod,
  });
  final String id;
  final String name;
  final String kind;
  final int costResin;
  final String resetCadence;
  final int? maxRunsPerPeriod;
}

class Catalog {
  final materials = <String, MaterialRow>{};
  final domains = <String, DomainRow>{};
  final drops = <String, ({String domainId, String materialId, int mask})>{};
  final characters = <({String id, String name, int rarity, String element, String weaponType})>[];
  final weapons = <({String id, String name, int rarity, String weaponType})>[];
  final ascension =
      <({String entityKind, String entityId, int phase, String materialId, int quantity})>[];
  final talents = <({String entityId, int level, String materialId, int quantity})>[];
}

class Builder {
  Builder(this.vendor) {
    final materials = vendor['materials'] as Json;
    for (final entry in materials.values) {
      _materialsByName[(entry as Json)['name'] as String] = entry;
    }
    final crafts = vendor['crafts'] as Json;
    for (final craft in crafts.values) {
      final recipe = (craft as Json)['recipe'] as List?;
      if (recipe == null || recipe.length != 1 || (craft['resultCount'] ?? 1) != 1) continue;
      final input = recipe.single as Json;
      if (input['count'] != 3) continue;
      final inputName = input['name'] as String;
      final outputName = craft['name'] as String;
      if (_materialsByName.containsKey(inputName) && _materialsByName.containsKey(outputName)) {
        _craftedFrom[outputName] = inputName;
      }
    }
  }

  final Json vendor;
  final catalog = Catalog();
  final _materialsByName = <String, Json>{};
  // output material name -> its 3:1 craft input's name (the tier below).
  final _craftedFrom = <String, String>{};

  void addCharacter(String key) {
    final char = (vendor['characters'] as Json)[key] as Json?;
    if (char == null) throw StateError('Character "$key" not in vendored dataset.');
    catalog.characters.add((
      id: key,
      name: char['name'] as String,
      rarity: char['rarity'] as int,
      element: char['elementText'] as String,
      weaponType: (char['weaponText'] as String).toLowerCase(),
    ));
    _addCosts('character', key, char['costs'] as Json?, phasePrefix: 'ascend');
    final talents = (vendor['talents'] as Json)[key] as Json?;
    _addTalentCosts(key, talents?['costs'] as Json?);
  }

  void addWeapon(String key) {
    final weapon = (vendor['weapons'] as Json)[key] as Json?;
    if (weapon == null) throw StateError('Weapon "$key" not in vendored dataset.');
    catalog.weapons.add((
      id: key,
      name: weapon['name'] as String,
      rarity: weapon['rarity'] as int,
      weaponType: (weapon['weaponText'] as String).toLowerCase(),
    ));
    _addCosts('weapon', key, weapon['costs'] as Json?, phasePrefix: 'ascend');
  }

  void _addCosts(String entityKind, String entityId, Json? costs, {required String phasePrefix}) {
    if (costs == null) return;
    for (final entry in costs.entries) {
      final phase = int.tryParse(entry.key.replaceFirst(phasePrefix, ''));
      if (phase == null) continue;
      for (final item in entry.value as List) {
        final materialId = _ensureMaterial((item as Json)['name'] as String);
        catalog.ascension.add((
          entityKind: entityKind,
          entityId: entityId,
          phase: phase,
          materialId: materialId,
          quantity: item['count'] as int,
        ));
      }
    }
  }

  void _addTalentCosts(String entityId, Json? costs) {
    if (costs == null) return;
    for (final entry in costs.entries) {
      final level = int.tryParse(entry.key.replaceFirst('lvl', ''));
      if (level == null) continue;
      for (final item in entry.value as List) {
        final materialId = _ensureMaterial((item as Json)['name'] as String);
        catalog.talents.add((
          entityId: entityId,
          level: level,
          materialId: materialId,
          quantity: item['count'] as int,
        ));
      }
    }
  }

  /// Adds the standard EXP items (3 character EXP books, 3 weapon ores)
  /// even though ascend/talent costs never reference them — the planner's
  /// book allocation and the inventory screen want them present.
  void addExpItems() {
    for (final entry in (vendor['materials'] as Json).values) {
      final material = entry as Json;
      if (material['category'] == 'EXP_FRUIT' || material['category'] == 'WEAPON_EXP_STONE') {
        _ensureMaterial(material['name'] as String);
      }
    }
  }

  String _ensureMaterial(String name) {
    final entry = _materialsByName[name];
    if (entry == null) throw StateError('Material "$name" not in vendored dataset.');
    final id = slug(name);
    if (catalog.materials.containsKey(id)) return id;

    final typeText = (entry['typeText'] as String?) ?? '';
    final category = entry['category'] as String?;
    final rarity = entry['rarity'] as int?;

    if (name == 'Mora') {
      catalog.materials['mora'] = MaterialRow(id: 'mora', name: name, category: 'currency');
      return 'mora';
    }
    if (category == 'EXP_FRUIT' || category == 'WEAPON_EXP_STONE') {
      final match =
          RegExp(r'Gives ([\d,]+) EXP').firstMatch((entry['description'] as String?) ?? '');
      if (match == null) throw StateError('No EXP value parseable for "$name".');
      catalog.materials[id] = MaterialRow(
        id: id,
        name: name,
        category: 'expBook',
        expValue: int.parse(match.group(1)!.replaceAll(',', '')),
      );
      return id;
    }
    final chain = _chainFor(name);
    if (chain.length > 1) {
      // Every tiered family — talent books, weapon-domain materials, gems,
      // common enemy drops — is linked by the game's own 3:1 crafting
      // recipes. Members that carry a drop domain + weekday schedule
      // (books, weapon mats) also get their domain and per-tier drop rows;
      // gems and common drops have neither and stay domain-less.
      final group = _tierGroupName(chain);
      for (final memberName in chain) {
        final memberId = slug(memberName);
        if (catalog.materials.containsKey(memberId)) continue;
        final member = _materialsByName[memberName]!;
        final domainId = _farmDomainFor(member);
        catalog.materials[memberId] = MaterialRow(
          id: memberId,
          name: memberName,
          category: 'tieredMaterial',
          tier: member['rarity'] as int?,
          tierGroup: group,
          domainId: domainId,
        );
        if (domainId != null) {
          final mask = (member['daysOfWeek'] as List)
              .fold<int>(0, (m, d) => m | _dayBits[d as String]!);
          catalog.drops['drop_${domainId}_$memberId'] =
              (domainId: domainId, materialId: memberId, mask: mask);
        }
      }
      return id;
    }
    if (typeText == 'Character Level-Up Material') {
      // Boss drops: rarity 5 = weekly challenge, rarity 4 = open-world boss.
      final weekly = rarity == 5;
      final domainId = _bossDomainFor(entry, weekly: weekly);
      catalog.materials[id] =
          MaterialRow(id: id, name: name, category: 'bossMaterial', domainId: domainId);
      if (domainId != null) {
        catalog.drops['drop_${domainId}_$id'] =
            (domainId: domainId, materialId: id, mask: _allDaysMask);
      }
      return id;
    }
    if (typeText.startsWith('Local Specialty') ||
        typeText == 'Character Talent Material' ||
        typeText == 'Character Ascension Material') {
      // Untiered, no farmable resin location (gathered specialties, event
      // items like Crown of Insight). Stored with the untiered
      // "bossMaterial" category — the closed category set's bucket for
      // standalone materials — and no domain.
      catalog.materials[id] = MaterialRow(id: id, name: name, category: 'bossMaterial');
      return id;
    }
    throw StateError('Unclassifiable material "$name" (typeText: "$typeText").');
  }

  /// The farm domain for a tiered material that drops in one — i.e. it
  /// has both a `dropDomainName` ("Domain of Mastery: X" for talent books,
  /// "Domain of Forgery: Y" for weapon materials) and a weekday schedule.
  /// Registers the domain row on first sight. Returns null for tiered
  /// materials without a farm location (gems, common drops).
  String? _farmDomainFor(Json entry) {
    final dropDomainName = entry['dropDomainName'] as String?;
    if (dropDomainName == null || entry['daysOfWeek'] == null) return null;
    final String kind;
    var name = dropDomainName;
    if (dropDomainName.startsWith('Domain of Mastery: ')) {
      kind = 'talent';
      name = dropDomainName.substring('Domain of Mastery: '.length);
    } else if (dropDomainName.startsWith('Domain of Forgery: ')) {
      kind = 'weapon';
      name = dropDomainName.substring('Domain of Forgery: '.length);
    } else {
      kind = (entry['typeText'] as String?) == 'Weapon Ascension Material' ? 'weapon' : 'talent';
    }
    final domainId = slug(name);
    catalog.domains.putIfAbsent(
      domainId,
      () => DomainRow(id: domainId, name: name, kind: kind, costResin: _domainRunCost),
    );
    return domainId;
  }

  String? _bossDomainFor(Json entry, {required bool weekly}) {
    final sources = (entry['sources'] as List?)?.cast<String>() ?? const [];
    String? label;
    for (final source in sources) {
      if (source.startsWith('Dropped by') || source.contains('Challenge Reward')) {
        label = source
            .replaceFirst(RegExp(r'^Dropped by '), '')
            .replaceFirst(RegExp(r'^Lv\.\s?\d+\+\s?'), '')
            .replaceFirst(RegExp(r' Challenge Reward$'), '');
        break;
      }
    }
    if (label == null) return null;
    final domainId = slug(label);
    catalog.domains.putIfAbsent(
      domainId,
      () => DomainRow(
        id: domainId,
        name: label!,
        kind: 'boss',
        costResin: weekly ? _weeklyBossRunCost : _normalBossRunCost,
        resetCadence: weekly ? 'weekly' : 'daily',
        maxRunsPerPeriod: weekly ? _weeklyBossDiscountedRunsPerWeek : null,
      ),
    );
    return domainId;
  }

  /// The full craft chain containing [name], lowest tier first; `[name]`
  /// alone when it is not part of any 3:1 chain.
  List<String> _chainFor(String name) {
    var root = name;
    while (_craftedFrom.containsKey(root)) {
      root = _craftedFrom[root]!;
    }
    final upgradesTo = <String, String>{
      for (final e in _craftedFrom.entries) e.value: e.key,
    };
    final chain = [root];
    while (upgradesTo.containsKey(chain.last)) {
      chain.add(upgradesTo[chain.last]!);
    }
    return chain.contains(name) ? chain : [name];
  }

  /// Mechanical group name for a craft chain: the words all member names
  /// share (prefix first, else suffix), falling back to the root name.
  String _tierGroupName(List<String> chain) {
    final wordLists = [for (final n in chain) n.split(' ')];
    final minLen = wordLists.map((w) => w.length).reduce((a, b) => a < b ? a : b);
    var prefix = 0;
    while (prefix < minLen && wordLists.every((w) => w[prefix] == wordLists.first[prefix])) {
      prefix++;
    }
    if (prefix > 0) {
      return slug(wordLists.first.sublist(0, prefix).join(' '));
    }
    var suffix = 0;
    while (suffix < minLen &&
        wordLists.every(
            (w) => w[w.length - 1 - suffix] == wordLists.first[wordLists.first.length - 1 - suffix])) {
      suffix++;
    }
    if (suffix > 0) {
      final first = wordLists.first;
      var shared = first.sublist(first.length - suffix);
      // "Teachings/Guide/Philosophies of X" shares "of X" — drop the
      // connective so the group reads as just "X".
      if (shared.length > 1 && shared.first.toLowerCase() == 'of') shared = shared.sublist(1);
      return slug(shared.join(' '));
    }
    return slug(chain.first);
  }
}

String _dartString(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String generateDart(Catalog c, String versionStamp, String vendorSha256) {
  final b = StringBuffer()
    ..writeln('// GENERATED by tool/build_catalog.dart — do not edit by hand.')
    ..writeln('// Source: genshin-db (MIT) — see tool/data/vendor/. All values are')
    ..writeln('// community-sourced and unverified in-game (docs/ASSUMPTIONS.md).')
    ..writeln("import 'package:drift/drift.dart';")
    ..writeln()
    ..writeln("import '../catalog_database.dart';")
    ..writeln()
    ..writeln('const bundledCatalogVersion = ${_dartString(versionStamp)};')
    ..writeln()
    ..writeln('final bundledCatalogMetadata = [')
    ..writeln('  CatalogMetadataCompanion.insert(')
    ..writeln("    id: 'catalog',")
    ..writeln('    version: bundledCatalogVersion,')
    ..writeln('    sha256: const Value(${_dartString(vendorSha256)}),')
    ..writeln('  ),')
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledGameRules = [')
    ..writeln("  GameRulesCompanion.insert(key: 'resin_cap', value: '200'),")
    ..writeln("  GameRulesCompanion.insert(key: 'resin_regen_interval_seconds', value: '480'),")
    ..writeln("  GameRulesCompanion.insert(key: 'condensed_resin_value', value: '40'),")
    ..writeln("  GameRulesCompanion.insert(key: 'fragile_or_transient_resin_value', value: '60'),")
    ..writeln("  GameRulesCompanion.insert(key: 'level_farm_cap', value: '90'),")
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledCharacters = [');
  for (final ch in c.characters.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    b.writeln('  CharactersCompanion.insert(');
    b.writeln('    id: ${_dartString(ch.id)},');
    b.writeln('    name: ${_dartString(ch.name)},');
    b.writeln('    rarity: ${ch.rarity},');
    b.writeln('    element: ${_dartString(ch.element)},');
    b.writeln('    weaponType: ${_dartString(ch.weaponType)},');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledWeapons = [');
  for (final w in c.weapons.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    b.writeln('  WeaponsCompanion.insert(');
    b.writeln('    id: ${_dartString(w.id)},');
    b.writeln('    name: ${_dartString(w.name)},');
    b.writeln('    rarity: ${w.rarity},');
    b.writeln('    weaponType: ${_dartString(w.weaponType)},');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledDomains = [');
  for (final d in c.domains.values.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    b.writeln('  DomainsCompanion.insert(');
    b.writeln('    id: ${_dartString(d.id)},');
    b.writeln('    name: ${_dartString(d.name)},');
    b.writeln('    kind: ${_dartString(d.kind)},');
    if (d.resetCadence != 'daily') {
      b.writeln('    resetCadence: const Value(${_dartString(d.resetCadence)}),');
    }
    if (d.maxRunsPerPeriod != null) {
      b.writeln('    maxRunsPerPeriod: const Value(${d.maxRunsPerPeriod}),');
    }
    b.writeln('    costResin: ${d.costResin},');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledMaterials = [');
  for (final m in c.materials.values.toList()..sort((a, b) => a.id.compareTo(b.id))) {
    b.writeln('  MaterialsCompanion.insert(');
    b.writeln('    id: ${_dartString(m.id)},');
    b.writeln('    name: ${_dartString(m.name)},');
    b.writeln('    category: ${_dartString(m.category)},');
    if (m.tier != null) b.writeln('    tier: const Value(${m.tier}),');
    if (m.tierGroup != null) b.writeln('    tierGroup: const Value(${_dartString(m.tierGroup!)}),');
    if (m.domainId != null) b.writeln('    domainId: const Value(${_dartString(m.domainId!)}),');
    if (m.expValue != null) b.writeln('    expValue: const Value(${m.expValue}),');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledDomainDrops = [');
  for (final e in c.drops.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    b.writeln('  DomainDropsCompanion.insert(');
    b.writeln('    id: ${_dartString(e.key)},');
    b.writeln('    domainId: ${_dartString(e.value.domainId)},');
    b.writeln('    materialId: ${_dartString(e.value.materialId)},');
    b.writeln('    weekdayMask: 0x${e.value.mask.toRadixString(16)},');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('// Level EXP/Mora ladders are not present in the vendored dataset;')
    ..writeln('// shipping none is the documented honest gap (docs/ASSUMPTIONS.md).')
    ..writeln('final bundledExpCurves = <ExpCurvesCompanion>[];')
    ..writeln()
    ..writeln('final bundledAscensionRequirements = [');
  final ascSorted = c.ascension.toList()
    ..sort((a, b) => ('${a.entityKind}|${a.entityId}|${a.phase}|${a.materialId}')
        .compareTo('${b.entityKind}|${b.entityId}|${b.phase}|${b.materialId}'));
  for (final r in ascSorted) {
    b.writeln('  AscensionRequirementsCompanion.insert(');
    b.writeln('    entityKind: ${_dartString(r.entityKind)},');
    b.writeln('    entityId: ${_dartString(r.entityId)},');
    b.writeln('    phase: ${r.phase},');
    b.writeln('    materialId: ${_dartString(r.materialId)},');
    b.writeln('    quantity: ${r.quantity},');
    b.writeln('  ),');
  }
  b
    ..writeln('];')
    ..writeln()
    ..writeln('final bundledTalentRequirements = [');
  final talSorted = c.talents.toList()
    ..sort((a, b) => ('${a.entityId}|${a.level}|${a.materialId}')
        .compareTo('${b.entityId}|${b.level}|${b.materialId}'));
  for (final r in talSorted) {
    b.writeln('  TalentRequirementsCompanion.insert(');
    b.writeln('    entityId: ${_dartString(r.entityId)},');
    b.writeln('    level: ${r.level},');
    b.writeln('    materialId: ${_dartString(r.materialId)},');
    b.writeln('    quantity: ${r.quantity},');
    b.writeln('  ),');
  }
  b.writeln('];');
  return b.toString();
}

Future<void> populateDatabase(CatalogDatabase db, Catalog c, String versionStamp,
    String vendorSha256, DateTime builtAt) async {
  await db.batch((batch) {
    batch.insert(
      db.catalogMetadata,
      CatalogMetadataCompanion.insert(
        id: 'catalog',
        version: versionStamp,
        builtAt: Value(builtAt),
        sha256: Value(vendorSha256),
      ),
    );
    batch.insertAll(db.gameRules, [
      GameRulesCompanion.insert(key: 'resin_cap', value: '200'),
      GameRulesCompanion.insert(key: 'resin_regen_interval_seconds', value: '480'),
      GameRulesCompanion.insert(key: 'condensed_resin_value', value: '40'),
      GameRulesCompanion.insert(key: 'fragile_or_transient_resin_value', value: '60'),
      GameRulesCompanion.insert(key: 'level_farm_cap', value: '90'),
    ]);
    batch.insertAll(db.characters, [
      for (final ch in c.characters)
        CharactersCompanion.insert(
            id: ch.id,
            name: ch.name,
            rarity: ch.rarity,
            element: ch.element,
            weaponType: ch.weaponType),
    ]);
    batch.insertAll(db.weapons, [
      for (final w in c.weapons)
        WeaponsCompanion.insert(id: w.id, name: w.name, rarity: w.rarity, weaponType: w.weaponType),
    ]);
    batch.insertAll(db.domains, [
      for (final d in c.domains.values)
        DomainsCompanion.insert(
          id: d.id,
          name: d.name,
          kind: d.kind,
          resetCadence: Value(d.resetCadence),
          maxRunsPerPeriod: Value(d.maxRunsPerPeriod),
          costResin: d.costResin,
        ),
    ]);
    batch.insertAll(db.materials, [
      for (final m in c.materials.values)
        MaterialsCompanion.insert(
          id: m.id,
          name: m.name,
          category: m.category,
          tier: Value(m.tier),
          tierGroup: Value(m.tierGroup),
          domainId: Value(m.domainId),
          expValue: Value(m.expValue),
        ),
    ]);
    batch.insertAll(db.domainDrops, [
      for (final e in c.drops.entries)
        DomainDropsCompanion.insert(
          id: e.key,
          domainId: e.value.domainId,
          materialId: e.value.materialId,
          weekdayMask: e.value.mask,
        ),
    ]);
    batch.insertAll(db.ascensionRequirements, [
      for (final r in c.ascension)
        AscensionRequirementsCompanion.insert(
          entityKind: r.entityKind,
          entityId: r.entityId,
          phase: r.phase,
          materialId: r.materialId,
          quantity: r.quantity,
        ),
    ]);
    batch.insertAll(db.talentRequirements, [
      for (final r in c.talents)
        TalentRequirementsCompanion.insert(
          entityId: r.entityId,
          level: r.level,
          materialId: r.materialId,
          quantity: r.quantity,
        ),
    ]);
  });
}

Future<void> main(List<String> args) async {
  var scope = 'narrow';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--scope' && i + 1 < args.length) scope = args[i + 1];
  }
  if (scope != 'narrow' && scope != 'full') {
    stderr.writeln('Unknown --scope "$scope" (expected narrow|full).');
    exit(64);
  }

  final vendorFile = File(_vendorPath);
  if (!vendorFile.existsSync()) {
    stderr.writeln('Missing $_vendorPath — run tool/fetch_catalog_source.sh first.');
    exit(66);
  }
  final vendorBytes = vendorFile.readAsBytesSync();
  final vendorSha256 = sha256.convert(vendorBytes).toString();
  final vendor = jsonDecode(utf8.decode(vendorBytes)) as Json;
  final provenance = vendor['provenance'] as Json;
  final versionStamp = '${provenance['package']}-${provenance['version']}+$scope';

  final builder = Builder(vendor);
  final List<String> characterKeys;
  final List<String> weaponKeys;
  if (scope == 'narrow') {
    final scopeJson = jsonDecode(File(_scopePath).readAsStringSync()) as Json;
    characterKeys = (scopeJson['characters'] as List).cast<String>();
    weaponKeys = (scopeJson['weapons'] as List).cast<String>();
  } else {
    characterKeys = (vendor['characters'] as Json).keys.toList()..sort();
    weaponKeys = (vendor['weapons'] as Json).keys.toList()..sort();
  }
  for (final key in characterKeys) {
    builder.addCharacter(key);
  }
  for (final key in weaponKeys) {
    builder.addWeapon(key);
  }
  builder.addExpItems();
  final catalog = builder.catalog;

  final builtAt = DateTime.now().toUtc();

  File(_dartOutPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generateDart(catalog, versionStamp, vendorSha256));

  Directory(_sqliteOutDir).createSync(recursive: true);
  final sqlitePath = '$_sqliteOutDir/catalog.sqlite';
  final sqliteFile = File(sqlitePath);
  if (sqliteFile.existsSync()) sqliteFile.deleteSync();
  final db = CatalogDatabase(NativeDatabase(sqliteFile));
  await populateDatabase(db, catalog, versionStamp, vendorSha256, builtAt);
  await db.close();

  final sqliteSha256 = sha256.convert(sqliteFile.readAsBytesSync()).toString();
  final manifest = const JsonEncoder.withIndent(' ').convert({
    'version': versionStamp,
    'scope': scope,
    'builtAt': builtAt.toIso8601String(),
    'source': provenance,
    'sqlite': {'file': 'catalog.sqlite', 'sha256': sqliteSha256},
    'counts': {
      'characters': catalog.characters.length,
      'weapons': catalog.weapons.length,
      'domains': catalog.domains.length,
      'materials': catalog.materials.length,
      'domainDrops': catalog.drops.length,
      'ascensionRequirements': catalog.ascension.length,
      'talentRequirements': catalog.talents.length,
    },
  });
  File('$_sqliteOutDir/manifest.json').writeAsStringSync('$manifest\n');

  stdout.writeln('Built catalog "$versionStamp":');
  stdout.writeln('  $_dartOutPath');
  stdout.writeln('  $sqlitePath + manifest.json');
  stdout.writeln(manifest);
}
