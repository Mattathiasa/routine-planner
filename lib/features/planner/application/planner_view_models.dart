import 'package:freezed_annotation/freezed_annotation.dart';

part 'planner_view_models.freezed.dart';

/// Plain presentation-ready data only — never a raw Drift-generated row
/// type (see `today_view_models.dart`'s doc comment for why). The
/// level+ascension "done" chip-collapse and the talent uniform/non-uniform
/// formatting are display composition, computed from these plain fields
/// in `target_card.dart`, not pre-baked here.
@freezed
abstract class TargetCardData with _$TargetCardData {
  const factory TargetCardData({
    required String id,
    required String name,
    required int rarity,
    required bool isWeapon,

    /// Null for weapons — they get a square tile, not an element-tinted
    /// avatar circle.
    String? element,
    required String subtitle,
    required int percentInHand,
    required int currentLevel,
    required int goalLevel,
    required int currentAscension,
    required int goalAscension,

    /// Null for weapons; exactly 3 entries for characters (one per talent
    /// slot, in catalog order).
    List<({int current, int goal})>? talents,
  }) = _TargetCardData;
}

/// One row of the pooled, domain-farmable-only "Most needed" list.
@freezed
abstract class MostNeededRowData with _$MostNeededRowData {
  const factory MostNeededRowData({
    required String materialId,
    required String label,
    required int have,
    required int need,
    required int missing,

    /// True when today (server date) is a day this material's domain
    /// drops it, or the domain is always open — drives the green vs. gray
    /// availability text color.
    required bool highlightAvailability,
    required String availabilityLabel,
  }) = _MostNeededRowData;
}

@freezed
abstract class PlannerViewData with _$PlannerViewData {
  const factory PlannerViewData({
    required List<TargetCardData> targets,
    required List<MostNeededRowData> mostNeeded,

    /// Every material category short across every active target, pooled —
    /// not the sum of each target's independent 100%-inventory view. Can
    /// legitimately exceed [mostNeeded]'s length: that list is filtered to
    /// domain-farmable materials only, while this count also includes any
    /// short EXP books or currency.
    required int materialsShortCount,
  }) = _PlannerViewData;
}
