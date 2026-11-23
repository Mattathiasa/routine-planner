/// Pity maths over an account's imported wish history.
///
/// Pure Dart — no Flutter/Riverpod/Drift imports — mirroring
/// `material_aggregation.dart`'s shape: top-level functions over `typedef`'d
/// records, degenerate input returning a degenerate answer rather than
/// throwing.
///
/// Every number here is long-standing community knowledge, not a value read
/// out of the catalog or verified in-game. Each lives behind a named constant
/// so a wrong guess is a one-line fix; see `docs/ASSUMPTIONS.md`.
library;

import 'wish_banner.dart';
import 'wish_pull.dart';

/// Guaranteed 5★ on the character, standard, beginner and chronicled banners.
const hardPityFiveStarCharacter = 90;

/// The weapon banner's shorter guarantee.
const hardPityFiveStarWeapon = 80;

/// Where the 5★ rate starts climbing steeply on a 90-pull banner.
const softPityStartCharacter = 74;

/// Where it starts climbing on the weapon banner.
const softPityStartWeapon = 63;

/// Guaranteed 4★ on every banner.
const hardPityFourStar = 10;

/// One wish costs 160 primogems (or one Fate, bought at that price).
const primogemsPerWish = 160;

/// The 5★ characters in the permanent pool.
///
/// Nothing in the catalog records which 5★ was *featured* on a given banner,
/// and no endpoint reports it either — so a lost 50/50 is inferred instead: a
/// 5★ character off this list was the featured one, and a 5★ on it was not,
/// which means the next 5★ is guaranteed. Names are the catalog's English
/// spellings (all seven verified present in the shipped catalog).
///
/// HoYoverse adds to this pool every few years (Tighnari in 3.0, Dehya in
/// 3.6), so it needs a look whenever the catalog is bumped.
const standardPool5StarCharacters = <String>{
  'Diluc',
  'Jean',
  'Qiqi',
  'Mona',
  'Keqing',
  'Tighnari',
  'Dehya',
};

/// Where one banner's pity stands.
typedef BannerPity = ({
  WishBanner banner,

  /// Wishes made since the last 5★ — i.e. the current pity count.
  int pullsSinceFive,
  int pullsSinceFour,

  /// The guarantee for this banner ([hardPityFiveStarWeapon] on the weapon
  /// banner, [hardPityFiveStarCharacter] everywhere else).
  int hardPity,
  int softPityStart,

  /// True when the next 5★ on the character banner must be the featured one,
  /// because the last 5★ came from the permanent pool.
  ///
  /// Always false on the other banners: the standard and beginner banners have
  /// no 50/50, and the weapon banner's guarantee runs on Epitomized Path fate
  /// points, which no endpoint reports.
  bool guaranteedNextFive,

  /// The most recent 5★ on this banner, or null if there isn't one yet.
  WishPull? lastFive,

  /// How many wishes this banner has in the imported history.
  int totalPulls,
});

/// The guarantee length for [banner].
int hardPityFor(WishBanner banner) => banner == WishBanner.weapon
    ? hardPityFiveStarWeapon
    : hardPityFiveStarCharacter;

/// Where soft pity begins for [banner].
int softPityStartFor(WishBanner banner) => banner == WishBanner.weapon
    ? softPityStartWeapon
    : softPityStartCharacter;

/// Reads [banner]'s pity out of that banner's pulls.
///
/// [pulls] must be that one banner's history ordered oldest-first (by the
/// upstream snowflake id). An empty list yields zero pity and no last 5★,
/// which is exactly right for an account that has never pulled here.
BannerPity pityFor(WishBanner banner, List<WishPull> pulls) {
  var pullsSinceFive = 0;
  var pullsSinceFour = 0;
  WishPull? lastFive;
  var countingFive = true;
  var countingFour = true;

  // Walk newest-first and stop each counter at its first hit.
  for (var i = pulls.length - 1; i >= 0; i--) {
    final pull = pulls[i];
    if (countingFive) {
      if (pull.rarity >= 5) {
        lastFive = pull;
        countingFive = false;
      } else {
        pullsSinceFive++;
      }
    }
    if (countingFour) {
      if (pull.rarity >= 4) {
        countingFour = false;
      } else {
        pullsSinceFour++;
      }
    }
    if (!countingFive && !countingFour) break;
  }

  return (
    banner: banner,
    pullsSinceFive: pullsSinceFive,
    pullsSinceFour: pullsSinceFour,
    hardPity: hardPityFor(banner),
    softPityStart: softPityStartFor(banner),
    guaranteedNextFive: _lostFiftyFifty(banner, lastFive),
    lastFive: lastFive,
    totalPulls: pulls.length,
  );
}

/// Splits a mixed history by banner and reads each one's pity.
///
/// Banners with no pulls are included with zero pity, so the UI can show every
/// banner without special-casing an empty one.
Map<WishBanner, BannerPity> pityForAll(List<WishPull> pulls) {
  final byBanner = <WishBanner, List<WishPull>>{
    for (final banner in WishBanner.values) banner: <WishPull>[],
  };
  for (final pull in pulls) {
    byBanner[pull.banner]!.add(pull);
  }
  return {
    for (final banner in WishBanner.values)
      banner: pityFor(banner, byBanner[banner]!),
  };
}

/// Wishes left until [pity] reaches the guarantee. Never negative.
int pullsToHardPity(BannerPity pity) {
  final remaining = pity.hardPity - pity.pullsSinceFive;
  return remaining < 0 ? 0 : remaining;
}

/// Wishes left until soft pity. Zero once soft pity has been reached.
int pullsToSoftPity(BannerPity pity) {
  final remaining = pity.softPityStart - pity.pullsSinceFive;
  return remaining < 0 ? 0 : remaining;
}

bool _lostFiftyFifty(WishBanner banner, WishPull? lastFive) {
  if (banner != WishBanner.character || lastFive == null) return false;
  if (lastFive.kind != WishItemKind.character) return false;
  return standardPool5StarCharacters.contains(lastFive.itemName);
}
