/// The wish banners the app tracks, identified by the `gacha_type` code the
/// game's own wish-history endpoint uses.
///
/// Pure Dart, no Flutter/Riverpod/Drift imports, mirroring `ResinEngine`'s
/// purity.
///
/// The character event banner is served under two codes: `301` and `400`
/// ("Character Event Wish-2"). They are one banner from the player's point of
/// view — one shared pity counter — so both map to [WishBanner.character] and
/// the importer queries both. See `docs/ASSUMPTIONS.md`.
enum WishBanner {
  beginner(100),
  standard(200),
  character(301),
  weapon(302),
  chronicled(500);

  const WishBanner(this.gachaType);

  /// The canonical `gacha_type` code, and the value persisted in `wish_pulls`.
  final int gachaType;

  /// The second code the character banner is served under. Records carrying it
  /// belong to [WishBanner.character].
  static const characterSecondGachaType = 400;

  /// Every code the importer must query to see a complete history. Note this
  /// is *not* `values.map(gachaType)` — it includes
  /// [characterSecondGachaType], whose records fold into `character`.
  static const queryableGachaTypes = <int>[100, 200, 301, 302, 400, 500];

  /// Null rather than throwing: an unknown future banner code should be
  /// skipped on import, not crash it.
  static WishBanner? fromGachaType(int gachaType) {
    if (gachaType == characterSecondGachaType) return WishBanner.character;
    for (final banner in values) {
      if (banner.gachaType == gachaType) return banner;
    }
    return null;
  }
}

extension WishBannerDisplay on WishBanner {
  String get label => switch (this) {
    WishBanner.beginner => "Beginners' Wish",
    WishBanner.standard => 'Standard Wish',
    WishBanner.character => 'Character Event',
    WishBanner.weapon => 'Weapon Event',
    WishBanner.chronicled => 'Chronicled Wish',
  };

  /// Short form for tight spaces (account cards, rollups).
  String get shortLabel => switch (this) {
    WishBanner.beginner => 'Beginner',
    WishBanner.standard => 'Standard',
    WishBanner.character => 'Character',
    WishBanner.weapon => 'Weapon',
    WishBanner.chronicled => 'Chronicled',
  };
}
