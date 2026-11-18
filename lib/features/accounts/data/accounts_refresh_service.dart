// Dart forbids named parameters that start with an underscore, so
// private fields fed by named constructor params must go through an
// initializer list; the lint's suggested fix doesn't compile here.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/clock/clock.dart';
import '../../../core/database/repositories/account_status_repository.dart';
import '../../../core/hoyolab/data/hoyolab_client.dart';
import '../../../core/hoyolab/data/hoyolab_credentials_store.dart';
import '../../../core/hoyolab/domain/hoyolab_region.dart';
import '../../resin/data/resin_repository.dart';
import '../../resin/domain/resin_engine.dart';

/// How long a fetched snapshot counts as fresh. Refreshes triggered by
/// app-open skip accounts newer than this, which keeps request volume
/// against an unofficial endpoint low; an explicit pull-to-refresh
/// ignores it (`force: true`).
const accountSnapshotFreshness = Duration(minutes: 5);

/// The outcome of refreshing one account, so a single failure can be shown
/// on that account's card instead of blanking the whole strip.
typedef AccountRefreshOutcome = ({String profileId, bool refreshed, String? error});

/// Pulls live `dailyNote` data for every connected account and persists it:
/// resin through the same `ResinEngine.sync` anchor math the manual Sync
/// dialog uses (so synced and manual resin stay one source of truth with
/// working undo and alerts), everything else into the account's snapshot
/// row.
///
/// Deliberately not routed through `ResinController`, which is bound to
/// the selected profile — this writes for every account, selected or not.
class AccountsRefreshService {
  AccountsRefreshService({
    required HoyolabClient client,
    required HoyolabCredentialsStore credentialsStore,
    required ResinRepository resinRepository,
    required AccountStatusRepository accountStatusRepository,
    required Clock clock,
    ResinEngine engine = const ResinEngine(),
  }) : _client = client,
       _credentialsStore = credentialsStore,
       _resinRepository = resinRepository,
       _accountStatusRepository = accountStatusRepository,
       _clock = clock,
       _engine = engine;

  final HoyolabClient _client;
  final HoyolabCredentialsStore _credentialsStore;
  final ResinRepository _resinRepository;
  final AccountStatusRepository _accountStatusRepository;
  final Clock _clock;
  final ResinEngine _engine;

  /// Refreshes each of [profileIds] that has a HoYoLab login. Accounts
  /// without one are skipped silently (they are tracked manually), and a
  /// per-account failure is reported rather than thrown.
  Future<List<AccountRefreshOutcome>> refreshAll(
    List<String> profileIds, {
    bool force = false,
  }) async {
    final outcomes = <AccountRefreshOutcome>[];
    for (final profileId in profileIds) {
      outcomes.add(await refreshOne(profileId, force: force));
    }
    return outcomes;
  }

  Future<AccountRefreshOutcome> refreshOne(String profileId, {bool force = false}) async {
    final credentials = await _credentialsStore.read(profileId);
    if (credentials == null) {
      return (profileId: profileId, refreshed: false, error: null);
    }

    final now = _clock.nowUtc();
    if (!force && !await _isStale(profileId, now)) {
      return (profileId: profileId, refreshed: false, error: null);
    }

    try {
      final notes = await _client.fetchNotes(
        cookie: credentials.cookie,
        uid: credentials.uid,
        region: hoyolabRegionForUid(credentials.uid),
      );

      final state = await _resinRepository.loadResinState(profileId);
      final (newState, event) = _engine.sync(
        state,
        now,
        x: notes.currentResin,
        fullIn: Duration(seconds: notes.secondsUntilFull),
      );
      await _resinRepository.saveResinMutation(profileId, newState, event);

      await _accountStatusRepository.saveSnapshot(
        profileId,
        fetchedAt: now,
        finishedTaskNum: notes.finishedTaskNum,
        totalTaskNum: notes.totalTaskNum,
        extraTaskRewardReceived: notes.extraTaskRewardReceived,
        remainResinDiscountNum: notes.remainResinDiscountNum,
        resinDiscountNumLimit: notes.resinDiscountNumLimit,
        currentExpeditionNum: notes.currentExpeditionNum,
        maxExpeditionNum: notes.maxExpeditionNum,
        finishedExpeditionNum: notes.expeditions.isEmpty
            ? null
            : notes.expeditions.where((e) => e.finished).length,
        currentHomeCoin: notes.currentHomeCoin,
        maxHomeCoin: notes.maxHomeCoin,
        homeCoinRecoverySeconds: notes.homeCoinRecoverySeconds,
      );

      return (profileId: profileId, refreshed: true, error: null);
    } on HoyolabException catch (e) {
      return (profileId: profileId, refreshed: false, error: e.message);
    } on UnknownHoyolabUidException catch (e) {
      return (profileId: profileId, refreshed: false, error: e.message);
    } on SocketException {
      return (profileId: profileId, refreshed: false, error: _offlineMessage);
    } on http.ClientException {
      return (profileId: profileId, refreshed: false, error: _offlineMessage);
    } on TimeoutException {
      return (profileId: profileId, refreshed: false, error: _offlineMessage);
    }
  }

  static const _offlineMessage = "Couldn't reach HoYoLab — showing the last known values.";

  Future<bool> _isStale(String profileId, DateTime now) async {
    final snapshot = await _accountStatusRepository.snapshotFor(profileId);
    if (snapshot == null) return true;
    return now.difference(snapshot.fetchedAt) >= accountSnapshotFreshness;
  }
}
