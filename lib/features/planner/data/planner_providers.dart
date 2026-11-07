import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';

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
