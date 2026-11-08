import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/catalog/catalog_database.dart';
import '../../../core/catalog/catalog_repository.dart';
import '../../../core/catalog/weekday_mask.dart';
import '../../../core/database/ids.dart';
import '../../../core/database/user_database.dart';
import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../settings/data/settings_providers.dart';
import '../domain/material_aggregation.dart';
import 'planner_view_models.dart';

part 'planner_controller.g.dart';

/// Builds each target card and the pooled "Most needed" list on top of
/// the pure `material_aggregation.dart` primitives. Two separate
/// aggregation scopes per the architecture doc: each target card's %
/// gauge sees the full shared inventory independently (no cross-target
/// allocation), while "Most needed" pools every active target's raw need
/// first and walks the tier groups once over the pooled totals.
@riverpod
class PlannerController extends _$PlannerController {
  @override
  Future<PlannerViewData> build() async {
    final profileId = (await ref.watch(currentProfileProvider.future)).id;
    final catalog = ref.watch(catalogRepositoryProvider);
    final planner = ref.watch(plannerRepositoryProvider);
    final serverClock = await ref.watch(serverClockProvider.future);
    final now = ref.watch(clockProvider).nowUtc();
    final serverDate = serverClock.serverDateFor(now);

    final settings = await ref.watch(settingsSnapshotProvider.future);
    final targets = await planner.targetsForProfile(profileId);
    // Totals-only mode skips inventory entirely and shows full material
    // totals — the pure aggregation functions already treat a missing key
    // as zero have, so an empty map is all that's needed here.
    final inventory = settings.totalsOnlyMode
        ? <String, int>{}
        : await planner.inventoryForProfile(profileId);

    final currencyMaterials = await catalog.materialsByCategory('currency');
    final currencyMaterialId = currencyMaterials.isEmpty ? null : currencyMaterials.first.id;

    final expBooks = await catalog.materialsByCategory('expBook');
    final booksDescByValue =
        [for (final b in expBooks) (materialId: b.id, expValue: b.expValue ?? 0)]
          ..sort((a, b) => b.expValue.compareTo(a.expValue));

    final targetCards = <TargetCardData>[];
    final pooledFarmableNeed = <String, int>{};
    final pooledOtherNeed = <String, int>{};

    for (final target in targets) {
      final ascensionRows = await catalog.ascensionRequirements(
        target.entityKind,
        target.entityId,
        fromPhaseExclusive: target.currentAscension,
        toPhaseInclusive: target.goalAscension,
      );

      final talentRowsRaw = <TalentRequirement>[];
      if (target.entityKind == 'character') {
        for (final pair in [
          (current: target.talent1Current, goal: target.talent1Goal),
          (current: target.talent2Current, goal: target.talent2Goal),
          (current: target.talent3Current, goal: target.talent3Goal),
        ]) {
          if (pair.current != null && pair.goal != null) {
            talentRowsRaw.addAll(
              await catalog.talentRequirements(
                target.entityId,
                fromLevelExclusive: pair.current,
                toLevelInclusive: pair.goal,
              ),
            );
          }
        }
      }

      final expRows = await catalog.expCurvesInRange(
        target.entityKind,
        fromLevelInclusive: target.currentLevel,
        toLevelExclusive: target.goalLevel,
      );
      final totalExp = expRows.fold<int>(0, (sum, row) => sum + row.expToNext);
      final totalMora = expRows.fold<int>(0, (sum, row) => sum + (row.moraToNext ?? 0));

      final requirementRows = <Quantity>[
        for (final row in ascensionRows) (materialId: row.materialId, quantity: row.quantity),
        for (final row in talentRowsRaw) (materialId: row.materialId, quantity: row.quantity),
        if (currencyMaterialId != null && totalMora > 0)
          (materialId: currencyMaterialId, quantity: totalMora),
      ];
      final rawNeed = accumulateNeed(requirementRows);
      final bookNeed = allocateExpBooks(totalExp, booksDescByValue);

      final farmableNeed = <String, int>{};
      final otherNeed = <String, int>{...bookNeed};
      for (final entry in rawNeed.entries) {
        final material = await catalog.materialById(entry.key);
        final isFarmable =
            material != null &&
            (material.category == 'tieredMaterial' || material.category == 'bossMaterial');
        final bucket = isFarmable ? farmableNeed : otherNeed;
        bucket[entry.key] = (bucket[entry.key] ?? 0) + entry.value;
      }

      farmableNeed.forEach(
        (id, qty) => pooledFarmableNeed[id] = (pooledFarmableNeed[id] ?? 0) + qty,
      );
      otherNeed.forEach((id, qty) => pooledOtherNeed[id] = (pooledOtherNeed[id] ?? 0) + qty);

      final farmableRows = await _walkFarmableNeed(catalog, farmableNeed, inventory);
      final farmableTotalNeed = farmableRows.fold<int>(0, (sum, row) => sum + row.need);
      final farmableTotalHave = farmableRows.fold<int>(0, (sum, row) => sum + row.have);
      final otherClamp = _clampFlat(otherNeed, inventory);

      final totalNeed = farmableTotalNeed + otherClamp.need;
      final totalHave = farmableTotalHave + otherClamp.have;
      final percent = totalNeed == 0 ? 100 : ((100 * totalHave) / totalNeed).round();

      targetCards.add(await _toCardData(catalog, target, percent));
    }

    final pooledFarmableRows = await _walkFarmableNeed(catalog, pooledFarmableNeed, inventory);
    final mostNeeded = <MostNeededRowData>[];
    for (final row in pooledFarmableRows) {
      if (row.missing <= 0) continue;
      mostNeeded.add(await _toMostNeededRow(catalog, row, serverDate));
    }
    mostNeeded.sort((a, b) => b.missing.compareTo(a.missing));

    final farmableShortCount = pooledFarmableRows.where((row) => row.missing > 0).length;
    final otherShortCount = pooledOtherNeed.entries
        .where((entry) => entry.value > (inventory[entry.key] ?? 0))
        .length;

    return PlannerViewData(
      targets: targetCards,
      mostNeeded: mostNeeded.take(5).toList(),
      materialsShortCount: farmableShortCount + otherShortCount,
    );
  }

  /// Builds a new target and persists it. [talents] must have exactly 3
  /// entries for a character, and must be null for a weapon.
  Future<void> addTarget({
    required String entityKind,
    required String entityId,
    String? linkedCharacterId,
    required int currentLevel,
    required int goalLevel,
    required int currentAscension,
    required int goalAscension,
    List<({int current, int goal})>? talents,
  }) async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref
        .read(plannerRepositoryProvider)
        .upsertTarget(
          PlannerTargetsCompanion.insert(
            id: newId(),
            profileId: profileId,
            entityKind: entityKind,
            entityId: entityId,
            linkedCharacterId: Value(linkedCharacterId),
            currentLevel: currentLevel,
            goalLevel: goalLevel,
            currentAscension: currentAscension,
            goalAscension: goalAscension,
            talent1Current: Value(talents?[0].current),
            talent1Goal: Value(talents?[0].goal),
            talent2Current: Value(talents?[1].current),
            talent2Goal: Value(talents?[1].goal),
            talent3Current: Value(talents?[2].current),
            talent3Goal: Value(talents?[2].goal),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    ref.invalidateSelf();
  }
}

/// Walks every tier group touched by [farmableNeed] against the full
/// catalog-wide family for that group (so a zero-need low tier still
/// donates its stock upward), and clamps every tierless (boss) material
/// directly. One call handles either a single target's need or a pooled
/// total — the caller decides which map to pass.
Future<List<MaterialNeedResult>> _walkFarmableNeed(
  CatalogRepository catalog,
  Map<String, int> farmableNeed,
  Map<String, int> inventory,
) async {
  if (farmableNeed.isEmpty) return [];

  final tierGroupsWalked = <String>{};
  final results = <MaterialNeedResult>[];

  for (final materialId in farmableNeed.keys) {
    final material = await catalog.materialById(materialId);
    final tierGroup = material?.tierGroup;

    if (tierGroup == null) {
      final need = farmableNeed[materialId]!;
      final have = inventory[materialId] ?? 0;
      final displayedHave = need < have ? need : have;
      results.add((
        materialId: materialId,
        need: need,
        have: displayedHave,
        missing: need - displayedHave,
      ));
    } else if (tierGroupsWalked.add(tierGroup)) {
      final family = await catalog.materialsByTierGroup(tierGroup);
      final ascendingByTier = [
        for (final m in family) (materialId: m.id, need: farmableNeed[m.id] ?? 0),
      ];
      results.addAll(walkTierGroup(ascendingByTier, inventory));
    }
  }

  return results;
}

({int need, int have}) _clampFlat(Map<String, int> need, Map<String, int> inventory) {
  var totalNeed = 0;
  var totalHave = 0;
  need.forEach((id, qty) {
    totalNeed += qty;
    final have = inventory[id] ?? 0;
    totalHave += qty < have ? qty : have;
  });
  return (need: totalNeed, have: totalHave);
}

Future<TargetCardData> _toCardData(
  CatalogRepository catalog,
  PlannerTarget target,
  int percent,
) async {
  if (target.entityKind == 'character') {
    final character = (await catalog.characterById(target.entityId))!;

    // Talent columns are nullable — a character target can exist with no
    // talent tracking at all, same as a weapon has none.
    List<({int current, int goal})>? talents;
    if (target.talent1Current != null &&
        target.talent1Goal != null &&
        target.talent2Current != null &&
        target.talent2Goal != null &&
        target.talent3Current != null &&
        target.talent3Goal != null) {
      talents = [
        (current: target.talent1Current!, goal: target.talent1Goal!),
        (current: target.talent2Current!, goal: target.talent2Goal!),
        (current: target.talent3Current!, goal: target.talent3Goal!),
      ];
    }

    return TargetCardData(
      id: target.id,
      name: character.name,
      rarity: character.rarity,
      isWeapon: false,
      element: character.element,
      subtitle: '${character.element} · character',
      percentInHand: percent,
      currentLevel: target.currentLevel,
      goalLevel: target.goalLevel,
      currentAscension: target.currentAscension,
      goalAscension: target.goalAscension,
      talents: talents,
    );
  }

  final weapon = (await catalog.weaponById(target.entityId))!;
  String subtitle;
  if (target.linkedCharacterId != null) {
    final linked = await catalog.characterById(target.linkedCharacterId!);
    subtitle = '${_titleCase(weapon.weaponType)} · for ${linked?.name ?? 'Unknown'}';
  } else {
    subtitle = '${_titleCase(weapon.weaponType)} · weapon';
  }

  return TargetCardData(
    id: target.id,
    name: weapon.name,
    rarity: weapon.rarity,
    isWeapon: true,
    element: null,
    subtitle: subtitle,
    percentInHand: percent,
    currentLevel: target.currentLevel,
    goalLevel: target.goalLevel,
    currentAscension: target.currentAscension,
    goalAscension: target.goalAscension,
    talents: null,
  );
}

Future<MostNeededRowData> _toMostNeededRow(
  CatalogRepository catalog,
  MaterialNeedResult row,
  DateTime serverDate,
) async {
  final material = (await catalog.materialById(row.materialId))!;
  final label = material.tierGroup != null
      ? '${_titleCase(material.tierGroup!)} · tier ${material.tier}'
      : material.name;

  var highlightAvailability = false;
  var availabilityLabel = '';
  if (material.domainId != null) {
    final drops = await catalog.dropsForDomain(material.domainId!);
    var mask = 0;
    for (final drop in drops) {
      if (drop.materialId == row.materialId) mask |= drop.weekdayMask;
    }
    final alwaysOpen = isAlwaysOpen(mask);
    final openToday = isOpenOnWeekday(mask, serverDate.weekday);
    highlightAvailability = alwaysOpen || openToday;
    availabilityLabel = alwaysOpen ? 'any day' : (openToday ? 'open today' : formatWeekdayMask(mask));
  }

  return MostNeededRowData(
    materialId: row.materialId,
    label: label,
    have: row.have,
    need: row.need,
    missing: row.missing,
    highlightAvailability: highlightAvailability,
    availabilityLabel: availabilityLabel,
  );
}

String _titleCase(String snakeOrLower) {
  final spaced = snakeOrLower.replaceAll('_', ' ');
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
