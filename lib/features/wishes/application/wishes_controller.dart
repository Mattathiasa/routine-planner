import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/profile_providers.dart';
import '../data/wish_providers.dart';
import '../domain/pity_calculator.dart';
import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';
import '../domain/wish_stats.dart';
import 'wish_item_index.dart';
import 'wish_view_models.dart';

part 'wishes_controller.g.dart';

/// How many pulls the history section shows before "see all".
const wishHistoryPreviewLength = 50;

/// Manually entered pity for one banner, lifted out of its Drift row so the
/// card builder stays free of generated row types.
typedef ManualPity = ({int? pityFive, int? pityFour, bool? guaranteed});

@riverpod
class WishesController extends _$WishesController {
  @override
  Future<WishesViewData> build() async {
    final profile = await ref.watch(currentProfileProvider.future);
    final profiles = await ref.watch(profileListProvider.future);
    final repository = ref.watch(wishRepositoryProvider);
    final index = await ref.watch(wishItemIndexProvider.future);

    final pulls = await repository.pullsFor(profile.id);
    final importState = await repository.importStateFor(profile.id);

    final manualByBanner = <WishBanner, ManualPity>{};
    for (final row in importState) {
      final banner = WishBanner.fromGachaType(row.bannerType);
      if (banner == null) continue;
      manualByBanner[banner] = (
        pityFive: row.manualPityFive,
        pityFour: row.manualPityFour,
        guaranteed: row.manualGuaranteed,
      );
    }

    final pityByBanner = pityForAll(pulls);
    final banners = [
      for (final banner in WishBanner.values)
        _cardFor(banner, pityByBanner[banner]!, manualByBanner[banner]),
    ];

    final stats = statsFor(pulls);
    final pityOfPull = {
      for (final five in stats.fiveStars) five.pull.id: five.pity,
    };

    final history = [
      for (final pull in pulls.reversed.take(wishHistoryPreviewLength))
        _entryFor(pull, index, pityOfPull[pull.id]),
    ];

    final lastImportedAt = importState
        .map((row) => row.lastImportedAt)
        .nonNulls
        .fold<DateTime?>(
          null,
          (newest, at) => newest == null || at.isAfter(newest) ? at : newest,
        );

    final displayName = profiles
        .where((p) => p.id == profile.id)
        .map((p) => p.displayName)
        .firstOrNull;

    return WishesViewData(
      profileId: profile.id,
      accountLabel: displayName ?? 'this account',
      labelAccount: profiles.length > 1,
      banners: banners,
      recentHistory: history,
      stats: WishStatsData(
        totalPulls: stats.totalPulls,
        fiveStarCount: stats.fiveStarCount,
        fourStarCount: stats.fourStarCount,
        primogemsSpent: stats.primogemsSpent,
        averageFivePity: stats.averageFivePity,
        firstPullAt: stats.firstPullAt,
        lastPullAt: stats.lastPullAt,
        fiveStars: [
          for (final five in stats.fiveStars)
            _entryFor(five.pull, index, five.pity),
        ],
      ),
      lastImportedAt: lastImportedAt,
    );
  }

  /// Records manually entered pity for one banner, for an account with no
  /// imported history.
  Future<void> setManualPity(
    WishBanner banner, {
    required int? pityFive,
    required int? pityFour,
    required bool? guaranteed,
  }) async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref.read(wishRepositoryProvider).saveManualPity(
      profileId,
      banner,
      pityFive: pityFive,
      pityFour: pityFour,
      guaranteed: guaranteed,
      now: ref.read(clockProvider).nowUtc(),
    );
    ref.invalidateSelf();
  }

  /// Drops this account's imported history, so a fresh import or manual entry
  /// starts clean.
  Future<void> clearHistory() async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref.read(wishRepositoryProvider).clearPulls(profileId);
    ref.invalidateSelf();
  }
}

/// Imported history wins over manual entry whenever there is any.
///
/// Not a merge: the two are alternatives. Blending a real pull count with a
/// typed-in one would produce a number that is neither.
BannerPityCard _cardFor(
  WishBanner banner,
  BannerPity pity,
  ManualPity? manual,
) {
  final manualFive = manual?.pityFive;
  final manualFour = manual?.pityFour;
  final manualGuaranteed = manual?.guaranteed;

  final hasImported = pity.totalPulls > 0;
  final hasManual = manualFive != null || manualFour != null;

  final source = hasImported
      ? PitySource.imported
      : hasManual
      ? PitySource.manual
      : PitySource.unknown;

  final useManual = source == PitySource.manual;

  return BannerPityCard(
    banner: banner,
    label: banner.label,
    pity: useManual ? (manualFive ?? 0) : pity.pullsSinceFive,
    hardPity: pity.hardPity,
    softPityStart: pity.softPityStart,
    pityFour: useManual ? (manualFour ?? 0) : pity.pullsSinceFour,
    guaranteedNextFive: useManual
        ? (manualGuaranteed ?? false)
        : pity.guaranteedNextFive,
    totalPulls: pity.totalPulls,
    source: source,
    lastFiveName: pity.lastFive?.itemName,
    lastFiveRarity: pity.lastFive?.rarity,
    lastFiveAt: pity.lastFive?.pulledAtUtc,
  );
}

WishHistoryEntry _entryFor(
  WishPull pull,
  Map<String, WishItemInfo> index,
  int? pity,
) {
  final info = wishItemFor(index, pull.itemName);
  return WishHistoryEntry(
    id: pull.id,
    itemName: pull.itemName,
    rarity: pull.rarity,
    kind: pull.kind,
    banner: pull.banner,
    pulledAtUtc: pull.pulledAtUtc,
    pity: pull.rarity >= 5 ? pity : null,
    element: info?.element,
  );
}
