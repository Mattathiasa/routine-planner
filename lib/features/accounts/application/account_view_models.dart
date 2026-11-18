import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_view_models.freezed.dart';

/// Where an account's commission progress came from. The card reads
/// differently for each: live progress is observed, manual progress is
/// tappable.
enum CommissionSource { live, manual }

/// One account's daily commission progress.
@freezed
abstract class CommissionProgress with _$CommissionProgress {
  const factory CommissionProgress({
    required int completed,
    required int total,
    required bool bonusClaimed,
    required CommissionSource source,
  }) = _CommissionProgress;

  const CommissionProgress._();

  bool get isComplete => total > 0 && completed >= total;

  /// 0..100, for the ring gauge. Guards `total == 0`, which a malformed
  /// live response could produce.
  int get percent => total <= 0 ? 0 : ((completed / total) * 100).round().clamp(0, 100);
}

/// Everything one card on the all-accounts strip needs. Plain fields only
/// — never a Drift row type (riverpod #4370).
@freezed
abstract class AccountOverviewData with _$AccountOverviewData {
  const factory AccountOverviewData({
    required String profileId,
    required String displayName,

    /// The account's game server label, e.g. "Asia".
    required String serverLabel,
    required bool isSelected,

    /// True when this account has its own HoYoLab login.
    required bool connected,

    /// Resin as of `now`, projected from the stored anchor.
    required int resin,
    required int resinCap,

    /// When resin reaches the cap; null once already at or above it.
    DateTime? resinFullAt,

    required CommissionProgress commissions,

    /// When this account's live data was last fetched; null for an
    /// account that has never synced.
    DateTime? lastUpdated,

    /// Set when the most recent refresh of this account failed — shown on
    /// the card so one dead account doesn't blank the strip.
    String? refreshError,

    /// Live extras, null when unknown or not connected.
    int? remainBossDiscounts,
    int? bossDiscountLimit,
    int? finishedExpeditions,
    int? totalExpeditions,
    int? realmCurrency,
    int? realmCurrencyCap,
  }) = _AccountOverviewData;
}
