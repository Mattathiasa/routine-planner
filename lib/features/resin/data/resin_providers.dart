import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../application/resin_controller.dart';
import 'resin_repository.dart';

part 'resin_providers.g.dart';

@Riverpod(keepAlive: true)
ResinRepository resinRepository(Ref ref) {
  return ResinRepository(ref.watch(userDatabaseProvider));
}

/// Plain fields only, deliberately not the Drift-generated `ResinEventRow`
/// — see `current_profile_provider.dart`'s doc comment for why a
/// `@riverpod` function can't expose a type declared entirely inside
/// another builder's generated output.
typedef ResinActivityEntry = ({
  String id,
  DateTime occurredAt,
  String kind,
  int? x,
  int? fullInSeconds,
  int? cost,
  int? amount,
  String? batchId,
  int? count,
  String? label,
  int resultingV,
  bool isUndo,
});

/// The Activity log's data source — re-runs whenever [ResinController]'s
/// state changes (including after an undo), so the log stays in sync
/// without the screen manually re-fetching.
@riverpod
Future<List<ResinActivityEntry>> resinRecentEvents(Ref ref) async {
  ref.watch(resinControllerProvider);
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  final rows = await ref.watch(resinRepositoryProvider).recentEvents(profileId);
  return [
    for (final row in rows)
      (
        id: row.id,
        occurredAt: row.occurredAt,
        kind: row.kind,
        x: row.x,
        fullInSeconds: row.fullInSeconds,
        cost: row.cost,
        amount: row.amount,
        batchId: row.batchId,
        count: row.count,
        label: row.label,
        resultingV: row.resultingV,
        isUndo: row.isUndo,
      ),
  ];
}

/// Plain fields only — same reason as [ResinActivityEntry].
typedef ResinAlertEntry = ({String id, int threshold, bool enabled});

/// A profile's resin-value alerts, sorted ascending. Callers must
/// `ref.invalidate(resinAlertsProvider)` after adding/removing/toggling one
/// (there's no controller wrapping this — it's a thin enough read that a
/// dedicated `AsyncNotifier` isn't warranted).
@riverpod
Future<List<ResinAlertEntry>> resinAlerts(Ref ref) async {
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  final rows = await ref.watch(settingsRepositoryProvider).alertsForProfile(profileId);
  return [for (final row in rows) (id: row.id, threshold: row.threshold, enabled: row.enabled)];
}
