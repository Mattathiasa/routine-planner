import 'package:freezed_annotation/freezed_annotation.dart';

part 'primogem_view_models.freezed.dart';

/// Why the balance might not be trustworthy, so the card can say so instead
/// of quietly showing a stale number.
enum PrimogemIncomeState {
  /// No HoYoLab login on this account: income has to be entered by hand.
  notConnected,

  /// Connected and the diary is answering.
  live,

  /// Connected, but the diary rejected the login — the known-fragile case.
  diaryUnavailable,
}

@freezed
abstract class PrimogemViewData with _$PrimogemViewData {
  const PrimogemViewData._();

  const factory PrimogemViewData({
    required String profileId,

    /// Null until the player sets one. Everything else here is meaningless
    /// without it, which is why the card asks for it first.
    required bool hasAnchor,
    required int balance,
    required int fates,
    required int wishesAffordable,
    required int dailyIncome,
    required bool welkinActive,
    required bool battlePassActive,
    required PrimogemIncomeState incomeState,

    /// Wishes made since the anchor, each charged 160 primogems.
    required int wishesSinceAnchor,
    DateTime? anchoredAt,
    DateTime? incomeLastFetchedAt,

    /// Primogems earned this month, as the diary reports it.
    int? monthIncome,
    String? incomeError,
  }) = _PrimogemViewData;

  /// Primogems spent on wishes since the anchor.
  int get spentOnWishes => wishesSinceAnchor * 160;
}
