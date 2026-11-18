import 'package:freezed_annotation/freezed_annotation.dart';

part 'hoyolab_notes.freezed.dart';

/// Parses the `data` object of a HoYoLab `dailyNote` response. Field names
/// match the raw JSON HoYoLab returns (verified against
/// `thesadru/genshin.py`'s `chronicle/genshin.py`), not a prettified
/// wrapper.
///
/// Strictness is deliberately split. The three resin fields are required:
/// they feed `ResinEngine.sync`, and their absence means the response
/// isn't what we think it is. Everything else is nullable and degrades to
/// `null` when missing, because those names are community-sourced and
/// unverified (docs/ASSUMPTIONS.md) — a renamed commission field must
/// never break resin sync.
@freezed
abstract class HoyolabNotes with _$HoyolabNotes {
  const factory HoyolabNotes({
    required int currentResin,
    required int maxResin,
    required int secondsUntilFull,

    /// Daily commissions: completed out of the day's total, and whether
    /// the all-four bonus has been claimed.
    int? finishedTaskNum,
    int? totalTaskNum,
    bool? extraTaskRewardReceived,

    /// Discounted weekly-boss runs left this week, out of the weekly
    /// allowance.
    int? remainResinDiscountNum,
    int? resinDiscountNumLimit,

    /// Expeditions currently dispatched, and the per-expedition state.
    int? currentExpeditionNum,
    int? maxExpeditionNum,
    @Default(<HoyolabExpedition>[]) List<HoyolabExpedition> expeditions,

    /// Realm currency ("teapot coins") and the seconds until the jar fills.
    int? currentHomeCoin,
    int? maxHomeCoin,
    int? homeCoinRecoverySeconds,
  }) = _HoyolabNotes;
}

/// One dispatched expedition. `remainedSeconds` is 0 once finished.
@freezed
abstract class HoyolabExpedition with _$HoyolabExpedition {
  const factory HoyolabExpedition({
    required bool finished,
    required int remainedSeconds,
  }) = _HoyolabExpedition;
}

/// Thrown when a `dailyNote` response's `data` object is missing a field
/// this app relies on — a genuinely unexpected API shape, not a normal
/// error path (those come back as a non-zero `retcode`, handled by
/// [HoyolabClient] before this function ever runs).
class HoyolabNotesFormatException implements Exception {
  const HoyolabNotesFormatException(this.message);
  final String message;

  @override
  String toString() => 'HoyolabNotesFormatException: $message';
}

/// HoYoLab serializes numeric fields as JSON strings (e.g. `"128"`), not
/// JSON numbers, even though they're purely numeric — observed on a real
/// `dailyNote` response. [int]'s own `toString()` and a numeric string's
/// are identical, so this only showed up once a real response was logged,
/// not from the field names/shape alone.
int? _asInt(Object? value) => switch (value) {
  int v => v,
  String v => int.tryParse(v),
  _ => null,
};

/// Same tolerance for booleans, which have been observed both as real
/// JSON booleans and as `"true"`/`0`-style values.
bool? _asBool(Object? value) => switch (value) {
  bool v => v,
  int v => v != 0,
  String v => switch (v.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => int.tryParse(v) == null ? null : int.parse(v) != 0,
  },
  _ => null,
};

List<HoyolabExpedition> _parseExpeditions(Object? value) {
  if (value is! List) return const [];
  final out = <HoyolabExpedition>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    out.add(
      HoyolabExpedition(
        // HoYoLab reports status as the string 'Finished'/'Ongoing'.
        finished: '${entry['status']}'.toLowerCase() == 'finished',
        remainedSeconds: _asInt(entry['remained_time']) ?? 0,
      ),
    );
  }
  return out;
}

HoyolabNotes parseHoyolabNotes(Map<String, dynamic> json) {
  final currentResin = _asInt(json['current_resin']);
  final maxResin = _asInt(json['max_resin']);
  final secondsUntilFull = _asInt(json['resin_recovery_time']);
  if (currentResin == null || maxResin == null || secondsUntilFull == null) {
    throw HoyolabNotesFormatException(
      'Expected int (or numeric string) current_resin/max_resin/resin_recovery_time, got: $json',
    );
  }
  return HoyolabNotes(
    currentResin: currentResin,
    maxResin: maxResin,
    secondsUntilFull: secondsUntilFull,
    finishedTaskNum: _asInt(json['finished_task_num']),
    totalTaskNum: _asInt(json['total_task_num']),
    extraTaskRewardReceived: _asBool(json['is_extra_task_reward_received']),
    remainResinDiscountNum: _asInt(json['remain_resin_discount_num']),
    resinDiscountNumLimit: _asInt(json['resin_discount_num_limit']),
    currentExpeditionNum: _asInt(json['current_expedition_num']),
    maxExpeditionNum: _asInt(json['max_expedition_num']),
    expeditions: _parseExpeditions(json['expeditions']),
    currentHomeCoin: _asInt(json['current_home_coin']),
    maxHomeCoin: _asInt(json['max_home_coin']),
    homeCoinRecoverySeconds: _asInt(json['home_coin_recovery_time']),
  );
}
