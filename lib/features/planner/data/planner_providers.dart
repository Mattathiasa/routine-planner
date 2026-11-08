import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../domain/material_aggregation.dart';

part 'planner_providers.g.dart';

/// Plain records, never a raw Drift-generated row type — see
/// `current_profile_provider.dart`'s doc comment for why.
typedef CharacterOption = ({String id, String name, int rarity, String element, String weaponType});
typedef WeaponOption = ({String id, String name, int rarity, String weaponType});

@riverpod
Future<List<CharacterOption>> allCharacterOptions(Ref ref) async {
  final characters = await ref.watch(catalogRepositoryProvider).allCharacters();
  return [
    for (final c in characters)
      (id: c.id, name: c.name, rarity: c.rarity, element: c.element, weaponType: c.weaponType),
  ];
}

@riverpod
Future<List<WeaponOption>> allWeaponOptions(Ref ref) async {
  final weapons = await ref.watch(catalogRepositoryProvider).allWeapons();
  return [
    for (final w in weapons) (id: w.id, name: w.name, rarity: w.rarity, weaponType: w.weaponType),
  ];
}

typedef InventoryRow = ({String materialId, String label, int count});

@riverpod
Future<List<InventoryRow>> inventoryRows(Ref ref) async {
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  final catalog = ref.watch(catalogRepositoryProvider);
  final planner = ref.watch(plannerRepositoryProvider);

  final materials = await catalog.allMaterials();
  final counts = await planner.inventoryForProfile(profileId);
  return [
    for (final m in materials)
      (
        materialId: m.id,
        label: materialDisplayLabel(name: m.name, tierGroup: m.tierGroup, tier: m.tier),
        count: counts[m.id] ?? 0,
      ),
  ];
}
