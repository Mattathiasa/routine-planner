import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';

part 'wish_view_models.freezed.dart';

/// Where a banner's pity numbers came from. The split mirrors the daily
/// commission tracker's live-or-manual distinction, and for the same reason:
/// an account that can't produce a wish-history link is still worth tracking,
/// it just has to be told the numbers.
enum PitySource { imported, manual, unknown }

/// One banner's card on the Wishes screen.
@freezed
abstract class BannerPityCard with _$BannerPityCard {
  // freezed requires a private constructor on a class that declares its own
  // getters.
  const BannerPityCard._();

  const factory BannerPityCard({
    required WishBanner banner,
    required String label,
    required int pity,
    required int hardPity,
    required int softPityStart,
    required int pityFour,
    required bool guaranteedNextFive,
    required int totalPulls,
    required PitySource source,

    /// The most recent 5★, when there is one in the imported history.
    String? lastFiveName,
    int? lastFiveRarity,
    DateTime? lastFiveAt,
  }) = _BannerPityCard;

  /// How far into the guarantee this banner is, for the ring gauge.
  int get percentToHardPity =>
      hardPity == 0 ? 0 : ((pity / hardPity) * 100).clamp(0, 100).round();

  bool get reachedSoftPity => pity >= softPityStart;

  int get pullsToHardPity => (hardPity - pity).clamp(0, hardPity);
}

/// One row in the history list.
@freezed
abstract class WishHistoryEntry with _$WishHistoryEntry {
  const factory WishHistoryEntry({
    required String id,
    required String itemName,
    required int rarity,
    required WishItemKind kind,
    required WishBanner banner,
    required DateTime pulledAtUtc,

    /// The pity this pull came at, for 5★s. Null for 3★ and 4★ rows, where
    /// it would just be noise.
    int? pity,

    /// From the catalog, when the name matched: lets the row show an element
    /// badge. Null for weapons and for anything the catalog doesn't know.
    String? element,
  }) = _WishHistoryEntry;
}

/// The 5★ list and the aggregate numbers under it.
@freezed
abstract class WishStatsData with _$WishStatsData {
  const factory WishStatsData({
    required int totalPulls,
    required int fiveStarCount,
    required int fourStarCount,
    required int primogemsSpent,
    required List<WishHistoryEntry> fiveStars,
    double? averageFivePity,
    DateTime? firstPullAt,
    DateTime? lastPullAt,
  }) = _WishStatsData;
}

@freezed
abstract class WishesViewData with _$WishesViewData {
  const WishesViewData._();

  const factory WishesViewData({
    required String profileId,
    required String accountLabel,

    /// True once more than one account exists, so the screen only names the
    /// account when naming it means something.
    required bool labelAccount,
    required List<BannerPityCard> banners,
    required List<WishHistoryEntry> recentHistory,
    required WishStatsData stats,
    DateTime? lastImportedAt,
  }) = _WishesViewData;

  bool get hasHistory => stats.totalPulls > 0;
}
