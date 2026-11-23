/// Summary statistics over an account's imported wish history.
///
/// Pure Dart — no Flutter/Riverpod/Drift imports. Takes any list of pulls, so
/// the caller decides whether it is looking at one banner or all of them.
library;

import 'pity_calculator.dart';
import 'wish_pull.dart';

/// A 5★ and the pity it came at — the number every player actually wants to
/// see next to the name.
typedef FiveStarPull = ({WishPull pull, int pity});

typedef WishStats = ({
  int totalPulls,
  int fiveStarCount,
  int fourStarCount,

  /// `totalPulls * primogemsPerWish`. What the history cost, whether it was
  /// paid in primogems or in Fates bought at the same price.
  int primogemsSpent,

  /// Mean pity across the 5★s whose pity is actually known, or null when none
  /// are. See [FiveStarPull] and the note in [statsFor] about the first 5★.
  double? averageFivePity,

  /// Newest first, which is the order they're shown in.
  List<FiveStarPull> fiveStars,
  DateTime? firstPullAt,
  DateTime? lastPullAt,
});

/// Reads [pulls] (oldest-first, by the upstream snowflake id) into a summary.
///
/// One honest limitation: the pity of the *earliest* 5★ in the history is
/// counted from the start of the imported window, not from the player's real
/// previous 5★ — upstream only keeps about six months, so anything before that
/// is unknowable. It is still reported (the count is right far more often than
/// not), but it is excluded from [WishStats.averageFivePity] so one truncated
/// number can't skew the average.
WishStats statsFor(List<WishPull> pulls) {
  if (pulls.isEmpty) {
    return (
      totalPulls: 0,
      fiveStarCount: 0,
      fourStarCount: 0,
      primogemsSpent: 0,
      averageFivePity: null,
      fiveStars: const <FiveStarPull>[],
      firstPullAt: null,
      lastPullAt: null,
    );
  }

  final fiveStars = <FiveStarPull>[];
  var fourStarCount = 0;
  var sinceFive = 0;
  var isFirstFive = true;
  var knownPitySum = 0;
  var knownPityCount = 0;

  for (final pull in pulls) {
    sinceFive++;
    if (pull.rarity >= 5) {
      fiveStars.add((pull: pull, pity: sinceFive));
      if (!isFirstFive) {
        knownPitySum += sinceFive;
        knownPityCount++;
      }
      isFirstFive = false;
      sinceFive = 0;
    } else if (pull.rarity == 4) {
      fourStarCount++;
    }
  }

  return (
    totalPulls: pulls.length,
    fiveStarCount: fiveStars.length,
    fourStarCount: fourStarCount,
    primogemsSpent: pulls.length * primogemsPerWish,
    averageFivePity: knownPityCount == 0
        ? null
        : knownPitySum / knownPityCount,
    fiveStars: fiveStars.reversed.toList(growable: false),
    firstPullAt: pulls.first.pulledAtUtc,
    lastPullAt: pulls.last.pulledAtUtc,
  );
}
