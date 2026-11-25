import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary_month.freezed.dart';

/// One month of the Traveler's Diary — primogems *earned*, not held.
///
/// The diary is the only live source of primogem movement there is: no
/// endpoint reports a balance. Field names are community-sourced and
/// unverified (docs/ASSUMPTIONS.md), so only [primogems] is required and
/// everything else degrades to null.
@freezed
abstract class DiaryMonth with _$DiaryMonth {
  const factory DiaryMonth({
    /// `YYYY-MM` as this app asked for it, not as upstream echoes it — the
    /// response reports the month as a bare integer.
    required String month,

    /// Primogems earned this month so far.
    required int primogems,
    int? mora,

    /// Primogems earned today. Shown as "today's income", never added to the
    /// balance — it is already inside [primogems].
    int? todayPrimogems,
  }) = _DiaryMonth;
}

class DiaryMonthFormatException implements Exception {
  const DiaryMonthFormatException(this.message);

  final String message;

  @override
  String toString() => 'DiaryMonthFormatException: $message';
}

/// Parses the `data` object of a `month_info` response.
DiaryMonth parseDiaryMonth(Map<String, dynamic> json, {required String month}) {
  final monthData = json['month_data'];
  if (monthData is! Map) {
    throw const DiaryMonthFormatException(
      'Expected a month_data object in the diary response.',
    );
  }

  final primogems = _asInt(monthData['current_primogems']);
  if (primogems == null) {
    throw DiaryMonthFormatException(
      'Expected int (or numeric string) current_primogems, got: $monthData',
    );
  }

  final dayData = json['day_data'];

  return DiaryMonth(
    month: month,
    primogems: primogems,
    mora: _asInt(monthData['current_mora']),
    todayPrimogems: dayData is Map
        ? _asInt(dayData['current_primogems'])
        : null,
  );
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}
