import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../wishes/data/wish_providers.dart';
import '../data/primogem_providers.dart';
import '../domain/primogem_ledger.dart';
import 'primogem_view_models.dart';

part 'primogems_controller.g.dart';

/// Formats a server date as the diary's month key.
String monthKeyFor(DateTime serverDate) =>
    '${serverDate.year.toString().padLeft(4, '0')}-'
    '${serverDate.month.toString().padLeft(2, '0')}';

@riverpod
class PrimogemsController extends _$PrimogemsController {
  @override
  Future<PrimogemViewData> build() async {
    final profile = await ref.watch(currentProfileProvider.future);
    final repository = ref.watch(primogemRepositoryProvider);
    final settings = await ref
        .watch(settingsRepositoryProvider)
        .getOrCreateSettings(profile.id);
    final credentials = await ref.watch(
      hoyolabCredentialsForProvider(profile.id).future,
    );

    final anchor = await repository.anchorFor(profile.id);
    final monthlyIncome = await repository.monthlyIncomeFor(profile.id);
    final adjustments = await repository.adjustmentsFor(profile.id);
    final incomeLastFetchedAt = await repository.incomeLastFetchedAt(
      profile.id,
    );

    final dailyIncome = projectedDailyIncome(
      welkin: settings.welkinActive,
      battlePass: settings.battlePassActive,
    );

    // Each account's own server decides which month the diary is reporting.
    final serverClock = await ref.watch(serverClockProvider.future);
    final now = ref.watch(clockProvider).nowUtc();
    final thisMonth = monthKeyFor(serverClock.serverDateFor(now));

    if (anchor == null) {
      return PrimogemViewData(
        profileId: profile.id,
        hasAnchor: false,
        balance: 0,
        fates: 0,
        wishesAffordable: 0,
        dailyIncome: dailyIncome,
        welkinActive: settings.welkinActive,
        battlePassActive: settings.battlePassActive,
        incomeState: _incomeStateFor(credentials != null, incomeLastFetchedAt),
        wishesSinceAnchor: 0,
        incomeLastFetchedAt: incomeLastFetchedAt,
        monthIncome: monthlyIncome[thisMonth],
      );
    }

    final wishesSinceAnchor = await ref
        .watch(wishRepositoryProvider)
        .pullCountSince(profile.id, anchor.anchoredAt);

    final balance = balanceAt(
      anchor: (
        balance: anchor.balance,
        fates: anchor.fates,
        anchoredAt: anchor.anchoredAt,
        anchorMonth: anchor.anchorMonth,
        monthIncomeAtAnchor: anchor.anchorMonthIncomeAtAnchor,
      ),
      monthlyIncome: monthlyIncome,
      adjustments: [
        for (final adjustment in adjustments)
          (at: adjustment.occurredAt, delta: adjustment.delta),
      ],
      wishesSinceAnchor: wishesSinceAnchor,
      now: now,
    );

    return PrimogemViewData(
      profileId: profile.id,
      hasAnchor: true,
      balance: balance,
      fates: anchor.fates,
      wishesAffordable: wishesAffordable(balance, fates: anchor.fates),
      dailyIncome: dailyIncome,
      welkinActive: settings.welkinActive,
      battlePassActive: settings.battlePassActive,
      incomeState: _incomeStateFor(credentials != null, incomeLastFetchedAt),
      wishesSinceAnchor: wishesSinceAnchor,
      anchoredAt: anchor.anchoredAt,
      incomeLastFetchedAt: incomeLastFetchedAt,
      monthIncome: monthlyIncome[thisMonth],
    );
  }

  /// Re-anchors the balance.
  ///
  /// Stores the diary's current month-to-date reading alongside it, so the
  /// anchor month's income isn't counted twice. When the diary has never
  /// answered for this account there is no reading to store, and the ledger
  /// then credits none of the anchor month — see `primogem_ledger.dart`.
  Future<void> setAnchor({required int balance, required int fates}) async {
    final profile = await ref.read(currentProfileProvider.future);
    final now = ref.read(clockProvider).nowUtc();
    final serverClock = await ref.read(serverClockProvider.future);
    final month = monthKeyFor(serverClock.serverDateFor(now));
    final repository = ref.read(primogemRepositoryProvider);
    final income = await repository.monthlyIncomeFor(profile.id);

    await repository.setAnchor(
      profile.id,
      balance: balance,
      fates: fates,
      anchoredAt: now,
      anchorMonth: month,
      monthIncomeAtAnchor: income[month],
    );
    ref.invalidateSelf();
  }

  /// Records a manual correction: a top-up, or primogems spent on anything
  /// other than wishes.
  Future<void> addAdjustment({required int delta, String? note}) async {
    final profile = await ref.read(currentProfileProvider.future);
    await ref
        .read(primogemRepositoryProvider)
        .addAdjustment(
          profile.id,
          delta: delta,
          note: note,
          occurredAt: ref.read(clockProvider).nowUtc(),
        );
    ref.invalidateSelf();
  }

  Future<void> setWelkinActive(bool active) async {
    final profile = await ref.read(currentProfileProvider.future);
    await ref
        .read(settingsRepositoryProvider)
        .updateWelkinActive(profile.id, active);
    ref.invalidateSelf();
  }

  Future<void> setBattlePassActive(bool active) async {
    final profile = await ref.read(currentProfileProvider.future);
    await ref
        .read(settingsRepositoryProvider)
        .updateBattlePassActive(profile.id, active);
    ref.invalidateSelf();
  }
}

/// A connected account that has never had a successful diary fetch is the
/// known-fragile case: the diary wants a cookie the login may not have
/// handed back.
PrimogemIncomeState _incomeStateFor(bool connected, DateTime? lastFetchedAt) {
  if (!connected) return PrimogemIncomeState.notConnected;
  return lastFetchedAt == null
      ? PrimogemIncomeState.diaryUnavailable
      : PrimogemIncomeState.live;
}
