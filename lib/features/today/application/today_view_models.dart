import 'package:freezed_annotation/freezed_annotation.dart';

part 'today_view_models.freezed.dart';

/// Plain presentation-ready data only — deliberately never holds a raw
/// Drift-generated row type (a field like that can trip up `freezed`'s own
/// generator the same way `riverpod_generator` tripped on one; see
/// `current_profile_provider.dart`'s doc comment for the general issue).
@freezed
abstract class WeekDayInfo with _$WeekDayInfo {
  const factory WeekDayInfo({
    required DateTime date,
    required int openDomainCount,
    required bool isToday,
  }) = _WeekDayInfo;
}

/// One checklist row — keyed by an individual catalog material, not the
/// catalog's broader `tierGroup` family: true tier-group-level rollup
/// (combining multiple tiers into fewer rows via the ratio-3 walk) is the
/// Planner screen's future aggregation algorithm, out of scope here.
@freezed
abstract class FarmTaskRowData with _$FarmTaskRowData {
  const factory FarmTaskRowData({
    required String taskId,
    required String label,
    required bool checked,
    required int runsDone,
    int? maxRunsPerPeriod,
    @Default(false) bool resetsWeekly,
  }) = _FarmTaskRowData;
}

@freezed
abstract class FarmDomainCardData with _$FarmDomainCardData {
  const factory FarmDomainCardData({
    required String domainId,
    required String name,
    required String scheduleLabel,
    required bool alwaysOpen,
    required int costResin,
    required List<FarmTaskRowData> rows,
  }) = _FarmDomainCardData;
}

@freezed
abstract class TodayViewData with _$TodayViewData {
  const factory TodayViewData({
    required DateTime serverDate,
    required DateTime now,
    required List<WeekDayInfo> week,
    required List<FarmDomainCardData> farmCards,
  }) = _TodayViewData;
}
