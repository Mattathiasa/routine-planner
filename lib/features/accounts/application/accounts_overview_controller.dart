import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/clock/game_server.dart';
import '../../../core/clock/server_clock.dart';
import '../../../core/database/repositories/account_status_repository.dart';
import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../resin/application/resin_controller.dart';
import '../../resin/data/resin_providers.dart';
import '../../resin/data/resin_repository.dart';
import '../../primogems/data/primogem_providers.dart';
import '../../primogems/data/primogem_repository.dart';
import '../../primogems/domain/primogem_ledger.dart';
import '../../resin/domain/resin_engine.dart';
import '../../wishes/data/wish_providers.dart';
import '../../wishes/data/wish_repository.dart';
import '../../wishes/domain/pity_calculator.dart';
import '../../wishes/domain/wish_banner.dart';
import '../data/accounts_refresh_providers.dart';
import 'account_view_models.dart';

part 'accounts_overview_controller.g.dart';

/// Assembles one card per local account: live resin for *every* account
/// (not just the selected one, which is all `ResinController` covers),
/// plus commission progress from the account's live snapshot when it has
/// a HoYoLab login, or its manual counter when it doesn't.
@riverpod
class AccountsOverviewController extends _$AccountsOverviewController {
  static const _engine = ResinEngine();

  @override
  Future<List<AccountOverviewData>> build() async {
    final profiles = await ref.watch(profileListProvider.future);
    final currentId = (await ref.watch(currentProfileProvider.future)).id;
    final now = ref.watch(clockProvider).nowUtc();

    final resinRepository = ref.watch(resinRepositoryProvider);
    final statusRepository = ref.watch(accountStatusRepositoryProvider);
    final wishRepository = ref.watch(wishRepositoryProvider);
    final primogemRepository = ref.watch(primogemRepositoryProvider);
    final errors = ref.watch(accountRefreshErrorsProvider);

    // Resin for other accounts is read straight from the repository, but
    // the *selected* account's can change under us (logging a run, Sync,
    // undo). Watching the controller keeps this card in step with the
    // hero card instead of showing a stale number until the next refresh
    // — same reason `resinRecentEventsProvider` watches it.
    await ref.watch(resinControllerProvider.future);

    // One card at a time would mean four awaits per account in series, and
    // every account's reads are independent of every other's — so they run
    // together and the list is assembled in profile order afterwards.
    return Future.wait([
      for (final profile in profiles)
        _cardFor(
          profile: profile,
          currentId: currentId,
          now: now,
          resinRepository: resinRepository,
          statusRepository: statusRepository,
          wishRepository: wishRepository,
          primogemRepository: primogemRepository,
          errors: errors,
        ),
    ]);
  }

  Future<AccountOverviewData> _cardFor({
    required ({String id, String displayName, String server}) profile,
    required String currentId,
    required DateTime now,
    required ResinRepository resinRepository,
    required AccountStatusRepository statusRepository,
    required WishRepository wishRepository,
    required PrimogemRepository primogemRepository,
    required Map<String, String> errors,
  }) async {
    final (credentials, resinState, snapshot, pity, primogems) = await (
      ref.watch(hoyolabCredentialsForProvider(profile.id).future),
      resinRepository.loadResinState(profile.id),
      statusRepository.snapshotFor(profile.id),
      _pityFor(wishRepository, profile.id),
      _primogemsFor(primogemRepository, wishRepository, profile.id, now),
    ).wait;
    final connected = credentials != null;

    // Each account's day rolls over on its own server, so the manual
    // counter is keyed by that account's server date, not the selected
    // account's.
    final server = GameServer.values.byName(profile.server);
    final serverDate = ServerClock(
      ref.watch(clockProvider),
      server,
    ).serverDateFor(now);

    final CommissionProgress commissions;
    if (connected && snapshot?.totalTaskNum != null) {
      commissions = CommissionProgress(
        completed: snapshot!.finishedTaskNum ?? 0,
        total: snapshot.totalTaskNum!,
        bonusClaimed: snapshot.extraTaskRewardReceived ?? false,
        source: CommissionSource.live,
      );
    } else {
      final row = await statusRepository.ensureCommissionRow(
        profile.id,
        periodAnchor: serverDate,
        now: now,
      );
      commissions = CommissionProgress(
        completed: row.completed,
        total: defaultDailyCommissionCount,
        bonusClaimed: row.bonusClaimed,
        source: CommissionSource.manual,
      );
    }

    return AccountOverviewData(
      profileId: profile.id,
      displayName: profile.displayName,
      serverLabel: server.label,
      isSelected: profile.id == currentId,
      connected: connected,
      resin: _engine.v(resinState, now),
      resinCap: resinState.cap,
      resinFullAt: _engine.timeToThreshold(resinState, resinState.cap),
      commissions: commissions,
      lastUpdated: snapshot?.fetchedAt,
      refreshError: errors[profile.id],
      remainBossDiscounts: connected ? snapshot?.remainResinDiscountNum : null,
      bossDiscountLimit: connected ? snapshot?.resinDiscountNumLimit : null,
      finishedExpeditions: connected ? snapshot?.finishedExpeditionNum : null,
      totalExpeditions: connected ? snapshot?.currentExpeditionNum : null,
      realmCurrency: connected ? snapshot?.currentHomeCoin : null,
      realmCurrencyCap: connected ? snapshot?.maxHomeCoin : null,
      characterPity: pity?.pity,
      characterHardPity: pity?.hardPity,
      pityIsManual: pity?.manual ?? false,
      primogems: primogems?.balance,
      wishesAffordable: primogems?.wishes,
    );
  }

  /// Advances an unconnected account's manual commission counter, wrapping
  /// back to zero past the last one so a mis-tap is one tap to fix.
  Future<void> bumpManualCommissions(String profileId) async {
    final now = ref.read(clockProvider).nowUtc();
    final serverDate = await _serverDateFor(profileId, now);
    final repository = ref.read(accountStatusRepositoryProvider);
    final row = await repository.ensureCommissionRow(
      profileId,
      periodAnchor: serverDate,
      now: now,
    );

    final next = row.completed >= defaultDailyCommissionCount ? 0 : row.completed + 1;
    await repository.setCommissionProgress(
      row.id,
      completed: next,
      // Dropping below the full count can't leave a claimed bonus behind.
      bonusClaimed: next >= defaultDailyCommissionCount && row.bonusClaimed,
      now: now,
    );
    ref.invalidateSelf();
  }

  Future<void> toggleManualBonus(String profileId) async {
    final now = ref.read(clockProvider).nowUtc();
    final serverDate = await _serverDateFor(profileId, now);
    final repository = ref.read(accountStatusRepositoryProvider);
    final row = await repository.ensureCommissionRow(
      profileId,
      periodAnchor: serverDate,
      now: now,
    );

    await repository.setCommissionProgress(
      row.id,
      completed: row.completed,
      bonusClaimed: !row.bonusClaimed,
      now: now,
    );
    ref.invalidateSelf();
  }

  Future<DateTime> _serverDateFor(String profileId, DateTime now) async {
    final profiles = await ref.read(profileListProvider.future);
    final profile = profiles.firstWhere((p) => p.id == profileId);
    final server = GameServer.values.byName(profile.server);
    return ServerClock(ref.read(clockProvider), server).serverDateFor(now);
  }
}

/// The character banner's pity for one account, or null when it tracks no
/// wishes at all.
///
/// Imported history wins over a manual number, the same rule the Wishes
/// screen follows — blending the two would produce a figure that is neither.
Future<({int pity, int hardPity, bool manual})?> _pityFor(
  WishRepository repository,
  String profileId,
) async {
  final pulls = await repository.pullsFor(
    profileId,
    banner: WishBanner.character,
  );
  if (pulls.isNotEmpty) {
    final banner = pityFor(WishBanner.character, pulls);
    return (
      pity: banner.pullsSinceFive,
      hardPity: banner.hardPity,
      manual: false,
    );
  }

  final state = await repository.importStateFor(profileId);
  for (final row in state) {
    if (row.bannerType != WishBanner.character.gachaType) continue;
    final manual = row.manualPityFive;
    if (manual != null) {
      return (
        pity: manual,
        hardPity: hardPityFor(WishBanner.character),
        manual: true,
      );
    }
  }
  return null;
}

/// One account's primogem balance, or null until it has an anchor.
Future<({int balance, int wishes})?> _primogemsFor(
  PrimogemRepository primogems,
  WishRepository wishes,
  String profileId,
  DateTime now,
) async {
  final anchor = await primogems.anchorFor(profileId);
  if (anchor == null) return null;

  final (income, adjustments, wishesSinceAnchor) = await (
    primogems.monthlyIncomeFor(profileId),
    primogems.adjustmentsFor(profileId),
    wishes.pullCountSince(profileId, anchor.anchoredAt),
  ).wait;

  final balance = balanceAt(
    anchor: (
      balance: anchor.balance,
      fates: anchor.fates,
      anchoredAt: anchor.anchoredAt,
      anchorMonth: anchor.anchorMonth,
      monthIncomeAtAnchor: anchor.anchorMonthIncomeAtAnchor,
    ),
    monthlyIncome: income,
    adjustments: [
      for (final adjustment in adjustments)
        (at: adjustment.occurredAt, delta: adjustment.delta),
    ],
    wishesSinceAnchor: wishesSinceAnchor,
    now: now,
  );

  return (
    balance: balance,
    wishes: wishesAffordable(balance, fates: anchor.fates),
  );
}

/// Commissions available per server day. Community knowledge, not a
/// dataset field — a connected account always prefers the live
/// `total_task_num` over this (docs/ASSUMPTIONS.md).
const defaultDailyCommissionCount = 4;
