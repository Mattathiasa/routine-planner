import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../resin/application/resin_controller.dart';
import 'today_view_models.dart';

part 'today_controller.g.dart';

const _nonSundayBitsMask = 0x3F; // Mon..Sat (bits 0-5); Sunday is always open

const _dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _formatWeekdayMask(int mask) {
  return [
    for (var i = 0; i < _dayAbbreviations.length; i++)
      if (mask & (1 << i) != 0) _dayAbbreviations[i],
  ].join(', ');
}

@riverpod
class TodayController extends _$TodayController {
  @override
  Future<TodayViewData> build() async {
    final serverClock = await ref.watch(serverClockProvider.future);
    final now = ref.watch(clockProvider).nowUtc();
    final serverDate = serverClock.serverDateFor(now);
    final profileId = (await ref.watch(currentProfileProvider.future)).id;

    final catalog = ref.watch(catalogRepositoryProvider);
    final planner = ref.watch(plannerRepositoryProvider);

    final weekStart = serverClock.serverWeekStart(now);
    final week = <WeekDayInfo>[];
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final openCount = (await catalog.domainsOpenOn(date)).length;
      week.add(
        WeekDayInfo(date: date, openDomainCount: openCount, isToday: date == serverDate),
      );
    }

    final openDomains = await catalog.domainsOpenOn(serverDate);
    final farmCards = <FarmDomainCardData>[];
    for (final domain in openDomains) {
      final materials = await catalog.materialsForDomain(domain.id);
      final drops = await catalog.dropsForDomain(domain.id);
      final combinedMask = drops.fold<int>(0, (mask, drop) => mask | drop.weekdayMask);
      final alwaysOpen = (combinedMask & _nonSundayBitsMask) == _nonSundayBitsMask;

      final resetsWeekly = domain.resetCadence == 'weekly';
      final periodAnchor = resetsWeekly ? weekStart : serverDate;

      final rows = <FarmTaskRowData>[];
      for (final material in materials) {
        final task = await planner.ensureTask(
          profileId,
          periodAnchor: periodAnchor,
          domainId: domain.id,
          tierGroup: material.id,
        );
        rows.add(
          FarmTaskRowData(
            taskId: task.id,
            label: material.name,
            checked: task.checked,
            runsDone: task.runsDone,
            maxRunsPerPeriod: domain.maxRunsPerPeriod,
            resetsWeekly: resetsWeekly,
          ),
        );
      }

      farmCards.add(
        FarmDomainCardData(
          domainId: domain.id,
          name: domain.name,
          scheduleLabel: alwaysOpen ? 'Open every day' : _formatWeekdayMask(combinedMask),
          alwaysOpen: alwaysOpen,
          costResin: domain.costResin,
          rows: rows,
        ),
      );
    }

    return TodayViewData(serverDate: serverDate, now: now, week: week, farmCards: farmCards);
  }

  Future<void> toggleTask(String taskId, bool checked) async {
    await ref.read(plannerRepositoryProvider).setChecked(taskId, checked);
    ref.invalidateSelf();
  }

  /// Matches the architecture doc's "+1 run calls Spend(domain cost) and
  /// increments runs_done" ordering exactly. Known, accepted limitation:
  /// these are two separately-transactioned repository calls, not one
  /// atomic cross-table transaction — a crash between them is a narrow,
  /// unlikely gap left unfixed here (fixing it means teaching both
  /// repositories to accept an externally-passed transaction).
  Future<void> logRun({required String taskId, required int costResin}) async {
    await ref.read(resinControllerProvider.notifier).spend(costResin);
    await ref.read(plannerRepositoryProvider).incrementRunsDone(taskId);
    ref.invalidateSelf();
  }
}
