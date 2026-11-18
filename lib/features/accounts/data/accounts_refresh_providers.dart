import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../resin/application/resin_controller.dart';
import '../../resin/data/resin_providers.dart';
import '../application/accounts_overview_controller.dart';
import 'accounts_refresh_service.dart';

part 'accounts_refresh_providers.g.dart';

@Riverpod(keepAlive: true)
AccountsRefreshService accountsRefreshService(Ref ref) {
  return AccountsRefreshService(
    client: ref.watch(hoyolabClientProvider),
    credentialsStore: ref.watch(hoyolabCredentialsStoreProvider),
    resinRepository: ref.watch(resinRepositoryProvider),
    accountStatusRepository: ref.watch(accountStatusRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}

/// Per-account refresh failures, keyed by profile id, so each card can
/// show its own problem. Held outside the overview controller because a
/// refresh writes to the database and then invalidates that controller —
/// storing errors there would be wiped by the very rebuild they describe.
@Riverpod(keepAlive: true)
class AccountRefreshErrors extends _$AccountRefreshErrors {
  @override
  Map<String, String> build() => const {};

  void record(Iterable<AccountRefreshOutcome> outcomes) {
    final next = {...state};
    for (final outcome in outcomes) {
      final error = outcome.error;
      if (error == null) {
        next.remove(outcome.profileId);
      } else {
        next[outcome.profileId] = error;
      }
    }
    state = next;
  }
}

/// Refreshes every account, records per-account errors, and lets the
/// overview rebuild from the freshly written rows. Returns the outcomes
/// so callers can react (e.g. a pull-to-refresh gesture completing).
@riverpod
Future<List<AccountRefreshOutcome>> refreshAllAccounts(
  Ref ref, {
  bool force = false,
}) async {
  final profiles = await ref.read(profileListProvider.future);
  final outcomes = await ref
      .read(accountsRefreshServiceProvider)
      .refreshAll([for (final p in profiles) p.id], force: force);
  ref.read(accountRefreshErrorsProvider.notifier).record(outcomes);
  if (outcomes.any((o) => o.refreshed)) {
    // Fresh rows are in the database; rebuild the cards that read them.
    // The selected account's resin also moved, so its controller — which
    // holds state optimistically rather than re-reading — must reload.
    ref.invalidate(resinControllerProvider);
    ref.invalidate(accountsOverviewControllerProvider);
  }
  return outcomes;
}
