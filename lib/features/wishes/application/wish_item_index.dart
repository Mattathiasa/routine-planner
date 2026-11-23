import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/repository_providers.dart';

part 'wish_item_index.g.dart';

/// What the catalog knows about one wishable item, looked up by name.
///
/// Plain fields rather than the Drift-generated `Character`/`Weapon` rows, for
/// the usual reason — see `current_profile_provider.dart`.
typedef WishItemInfo = ({String id, int rarity, String? element});

/// Name-to-item index over the whole catalog.
///
/// Wish records carry a name and a rarity but no id, and `CatalogRepository`
/// has no lookup by name, so this builds one once and keeps it: 122 characters
/// and 256 weapons, used to attach an element badge to an imported pull.
///
/// Names are matched case-insensitively and whitespace-trimmed, which is
/// enough because the import forces `lang=en` and the catalog's names are
/// English. Anything unmatched simply renders without a badge.
@Riverpod(keepAlive: true)
Future<Map<String, WishItemInfo>> wishItemIndex(Ref ref) async {
  final catalog = ref.watch(catalogRepositoryProvider);
  final characters = await catalog.allCharacters();
  final weapons = await catalog.allWeapons();

  return {
    for (final weapon in weapons)
      _key(weapon.name): (id: weapon.id, rarity: weapon.rarity, element: null),
    // Characters last so a name shared with a weapon resolves to the
    // character, which is what a wish record for a character means.
    for (final character in characters)
      _key(character.name): (
        id: character.id,
        rarity: character.rarity,
        element: character.element,
      ),
  };
}

String _key(String name) => name.trim().toLowerCase();

/// Looks [name] up in an index built by [wishItemIndex].
WishItemInfo? wishItemFor(Map<String, WishItemInfo> index, String name) =>
    index[_key(name)];
