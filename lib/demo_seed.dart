import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock/game_server.dart';
import 'core/clock/server_clock.dart';
import 'core/database/ids.dart';
import 'core/providers/clock_providers.dart';
import 'core/database/user_database.dart';
import 'core/providers/current_profile_provider.dart';
import 'core/providers/repository_providers.dart';
import 'features/primogems/data/primogem_providers.dart';
import 'features/resin/data/resin_providers.dart';
import 'features/resin/domain/resin_engine.dart';
import 'features/wishes/data/wish_providers.dart';
import 'features/wishes/domain/wish_banner.dart';
import 'features/wishes/domain/wish_pull.dart';

/// Screenshot/demo fixture: compiled in only with
/// `--dart-define=DEMO_SEED=true` (used to capture the README screens) and
/// applied once, only to an otherwise-empty profile. Entity/material ids
/// reference the bundled catalog.
Future<void> maybeApplyDemoSeed(ProviderContainer container) async {
  if (!const bool.fromEnvironment('DEMO_SEED')) return;

  final profile = await container.read(currentProfileProvider.future);
  final planner = container.read(plannerRepositoryProvider);
  if ((await planner.targetsForProfile(profile.id)).isNotEmpty) return;

  final now = DateTime.now().toUtc();
  await planner.upsertTarget(
    PlannerTargetsCompanion.insert(
      id: newId(),
      profileId: profile.id,
      entityKind: 'character',
      entityId: 'furina',
      currentLevel: 70,
      goalLevel: 90,
      currentAscension: 4,
      goalAscension: 6,
      talent1Current: const Value(6),
      talent1Goal: const Value(9),
      talent2Current: const Value(6),
      talent2Goal: const Value(9),
      talent3Current: const Value(2),
      talent3Goal: const Value(6),
      updatedAt: now,
    ),
  );
  await planner.upsertTarget(
    PlannerTargetsCompanion.insert(
      id: newId(),
      profileId: profile.id,
      entityKind: 'character',
      entityId: 'nahida',
      currentLevel: 80,
      goalLevel: 90,
      currentAscension: 5,
      goalAscension: 6,
      talent1Current: const Value(8),
      talent1Goal: const Value(10),
      talent2Current: const Value(8),
      talent2Goal: const Value(10),
      talent3Current: const Value(8),
      talent3Goal: const Value(10),
      updatedAt: now,
    ),
  );
  for (final (materialId, count) in const [
    ('philosophies_of_justice', 5),
    ('guide_to_justice', 7),
    ('varunada_lazurite_chunk', 4),
    ('whopperflower_nectar', 36),
    ('mora', 1200000),
  ]) {
    await planner.setInventoryCount(profile.id, materialId, count);
  }

  // Straight through the repository rather than ResinController: the
  // controller's notification reconcile needs platform plugins that are
  // not available this early in main().
  const engine = ResinEngine();
  final resinRepository = container.read(resinRepositoryProvider);
  final initial = await resinRepository.loadResinState(profile.id);
  final (synced, event) = engine.sync(
    initial,
    now,
    x: 132,
    fullIn: const Duration(hours: 9, minutes: 4),
  );
  await resinRepository.saveResinMutation(profile.id, synced, event);

  // A second account, so the all-accounts strip has something to show:
  // on a different server, with its own resin and a part-done manual
  // commission count.
  final profiles = container.read(profileRepositoryProvider);
  final alt = await profiles.createProfile(displayName: 'Alt', server: 'europe');
  final altInitial = await resinRepository.loadResinState(alt.id);
  final (altSynced, altEvent) = engine.sync(
    altInitial,
    now,
    x: 48,
    fullIn: const Duration(hours: 20, minutes: 16),
  );
  await resinRepository.saveResinMutation(alt.id, altSynced, altEvent);

  final status = container.read(accountStatusRepositoryProvider);
  final serverClock = ServerClock(container.read(clockProvider), GameServer.asia);
  final mainRow = await status.ensureCommissionRow(
    profile.id,
    periodAnchor: serverClock.serverDateFor(now),
    now: now,
  );
  await status.setCommissionProgress(
    mainRow.id,
    completed: 3,
    bonusClaimed: false,
    now: now,
  );

  final altClock = ServerClock(container.read(clockProvider), GameServer.europe);
  final altRow = await status.ensureCommissionRow(
    alt.id,
    periodAnchor: altClock.serverDateFor(now),
    now: now,
  );
  await status.setCommissionProgress(
    altRow.id,
    completed: 1,
    bonusClaimed: false,
    now: now,
  );

  // Wish history for the main account, so the Wishes tab has pity, a 5★
  // list and real statistics to show. Names reference the bundled catalog.
  final wishes = container.read(wishRepositoryProvider);
  await wishes.insertPulls(profile.id, _demoWishHistory(now), now: now);

  // The alt account is tracked by hand instead, which is the other half of
  // the story the screen tells.
  await wishes.saveManualPity(
    alt.id,
    WishBanner.character,
    pityFive: 58,
    pityFour: 4,
    guaranteed: true,
    now: now,
  );

  final primogems = container.read(primogemRepositoryProvider);
  await primogems.setAnchor(
    profile.id,
    balance: 12480,
    fates: 6,
    anchoredAt: now.subtract(const Duration(days: 9)),
    anchorMonth: _monthKey(now),
    monthIncomeAtAnchor: 2140,
  );
  await primogems.saveMonthlyIncome(
    profile.id,
    month: _monthKey(now),
    primogems: 3860,
    fetchedAt: now,
  );
  await primogems.addAdjustment(
    profile.id,
    delta: -1600,
    note: 'Topped up resin',
    occurredAt: now.subtract(const Duration(days: 3)),
  );
}

String _monthKey(DateTime at) =>
    '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}';

/// A plausible character-banner history: two 5★s at believable pity, 4★s
/// roughly every ten pulls, 3★ weapons in between. Snowflake-shaped ids,
/// ascending, since that ordering is what the domain reads.
List<WishPull> _demoWishHistory(DateTime now) {
  const fiveStarsAt = {12: 'Nahida', 86: 'Furina'};
  const fourStarsAt = {4: 'Xingqiu', 23: 'Bennett', 31: 'Fischl', 47: 'Xingqiu', 58: 'Bennett', 70: 'Fischl', 79: 'Xingqiu'};

  final pulls = <WishPull>[];
  for (var i = 1; i <= 94; i++) {
    final fiveStar = fiveStarsAt[i];
    final fourStar = fourStarsAt[i];
    pulls.add(
      WishPull(
        id: (1700000000000000000 + i).toString(),
        banner: WishBanner.character,
        itemName: fiveStar ?? fourStar ?? 'Cool Steel',
        kind: fiveStar != null || fourStar != null
            ? WishItemKind.character
            : WishItemKind.weapon,
        rarity: fiveStar != null
            ? 5
            : fourStar != null
            ? 4
            : 3,
        // Spread backwards from now, newest last.
        pulledAtUtc: now.subtract(Duration(hours: (94 - i) * 4)),
      ),
    );
  }
  return pulls;
}
