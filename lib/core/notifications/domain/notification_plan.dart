/// Pure Dart, no Flutter/plugin imports — mirrors `ResinEngine`'s purity.
/// Describes what notifications *should* exist right now; the actual
/// scheduling side effect lives in `core/notifications/data/`.
library;

import 'dart:convert';

import '../../../features/resin/domain/resin_engine.dart';
import '../../../features/resin/domain/resin_state.dart';

typedef PlannedNotification = ({
  int id,
  String kind,
  String title,
  String body,
  DateTime scheduledAt,
});

const _fnvOffsetBasis = 0x811c9dc5;
const _fnvPrime = 0x01000193;

/// A deterministic id, stable across app restarts — deliberately not
/// `Object.hash`/`String.hashCode`, which Dart does not guarantee are
/// stable across runs. Idempotent reconcile depends on the same
/// `(profileId, kind, key)` tuple always producing the same id, so a
/// stale schedule can be reliably replaced rather than duplicated.
int stableNotificationId(String profileId, String kind, String key) {
  var hash = _fnvOffsetBasis;
  for (final byte in utf8.encode('$profileId:$kind:$key')) {
    hash ^= byte;
    hash = (hash * _fnvPrime) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// One planned notification per enabled, still-reachable resin-value
/// alert. `engine.timeToThreshold` is purely anchor-based (no `now`), so a
/// computed instant can already be in the past relative to [now] if enough
/// regen ticks have elapsed since the anchor — those are filtered out here
/// rather than scheduled as an immediately-firing notification.
List<PlannedNotification> planResinThresholdNotifications({
  required String profileId,
  required ResinEngine engine,
  required ResinState state,
  required DateTime now,
  required List<({String id, int threshold, bool enabled})> alerts,
}) {
  final planned = <PlannedNotification>[];
  for (final alert in alerts) {
    if (!alert.enabled) continue;
    final scheduledAt = engine.timeToThreshold(state, alert.threshold);
    if (scheduledAt == null || !scheduledAt.isAfter(now)) continue;

    planned.add((
      id: stableNotificationId(profileId, 'resinThreshold', alert.threshold.toString()),
      kind: 'resinThreshold',
      title: alert.threshold == state.cap ? 'Resin is full' : 'Resin reaches ${alert.threshold}',
      body: 'Open Routine Planner to spend it before it caps.',
      scheduledAt: scheduledAt,
    ));
  }
  return planned;
}

/// One planned notification per unexpired transient resin batch, fired
/// 24h before it expires — only included if that point hasn't already
/// passed.
List<PlannedNotification> planTransientExpiryNotifications({
  required String profileId,
  required List<TransientResinBatch> transient,
  required DateTime now,
  required bool enabled,
}) {
  if (!enabled) return [];

  final planned = <PlannedNotification>[];
  for (final batch in transient) {
    final scheduledAt = batch.expiresAt.subtract(const Duration(hours: 24));
    if (!scheduledAt.isAfter(now)) continue;

    planned.add((
      id: stableNotificationId(profileId, 'transientExpiry', batch.id),
      kind: 'transientExpiry',
      title: 'Transient Resin expiring soon',
      body: 'A transient resin stack expires in 24 hours.',
      scheduledAt: scheduledAt,
    ));
  }
  return planned;
}
