import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/notifications/domain/notification_plan.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';

void main() {
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);
  const profileId = 'profile-1';

  group('stableNotificationId', () {
    test('same inputs produce the same id across separate calls', () {
      final a = stableNotificationId(profileId, 'resinThreshold', '160');
      final b = stableNotificationId(profileId, 'resinThreshold', '160');
      expect(a, b);
    });

    test('a different key produces a different id', () {
      final a = stableNotificationId(profileId, 'resinThreshold', '160');
      final b = stableNotificationId(profileId, 'resinThreshold', '200');
      expect(a, isNot(b));
    });

    test('a different kind produces a different id', () {
      final a = stableNotificationId(profileId, 'resinThreshold', 'x');
      final b = stableNotificationId(profileId, 'transientExpiry', 'x');
      expect(a, isNot(b));
    });

    test('ids are always non-negative (fit Android\'s 32-bit signed id)', () {
      for (final key in ['160', '200', 'batch-abc', '', 'a very long key indeed']) {
        expect(stableNotificationId(profileId, 'resinThreshold', key), greaterThanOrEqualTo(0));
      }
    });
  });

  group('planResinThresholdNotifications', () {
    test('disabled alerts are skipped', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      final planned = planResinThresholdNotifications(
        profileId: profileId,
        engine: engine,
        state: state,
        now: now,
        alerts: [(id: 'a1', threshold: 160, enabled: false)],
      );
      expect(planned, isEmpty);
    });

    test('a capped state (n == null) produces nothing', () {
      final state = ResinState(v: 200, n: null, cap: 200);
      final planned = planResinThresholdNotifications(
        profileId: profileId,
        engine: engine,
        state: state,
        now: now,
        alerts: [(id: 'a1', threshold: 160, enabled: true)],
      );
      expect(planned, isEmpty);
    });

    test('a reachable enabled threshold is planned with the right id/kind/time', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      final planned = planResinThresholdNotifications(
        profileId: profileId,
        engine: engine,
        state: state,
        now: now,
        alerts: [(id: 'a1', threshold: 160, enabled: true)],
      );
      expect(planned, hasLength(1));
      expect(planned.single.kind, 'resinThreshold');
      expect(planned.single.id, stableNotificationId(profileId, 'resinThreshold', '160'));
      expect(planned.single.scheduledAt, engine.timeToThreshold(state, 160));
      expect(planned.single.title, 'Resin reaches 160');
    });

    test('a threshold equal to cap is titled "Resin is full"', () {
      final state = ResinState(v: 100, n: now, cap: 200);
      final planned = planResinThresholdNotifications(
        profileId: profileId,
        engine: engine,
        state: state,
        now: now,
        alerts: [(id: 'a1', threshold: 200, enabled: true)],
      );
      expect(planned.single.title, 'Resin is full');
    });

    test('a computed time already in the past (relative to now) is excluded', () {
      // Anchor far enough in the past that the threshold's tick already
      // happened before `now`, even though the raw anchor value `v` is
      // still below it — `timeToThreshold` is purely anchor-based and has
      // no `now` of its own, so this filtering has to happen here.
      final farPastAnchor = now.subtract(const Duration(days: 30));
      final state = ResinState(v: 100, n: farPastAnchor, cap: 200);
      final planned = planResinThresholdNotifications(
        profileId: profileId,
        engine: engine,
        state: state,
        now: now,
        alerts: [(id: 'a1', threshold: 101, enabled: true)],
      );
      expect(planned, isEmpty);
    });
  });

  group('planTransientExpiryNotifications', () {
    test('disabled means no notifications regardless of batches', () {
      final planned = planTransientExpiryNotifications(
        profileId: profileId,
        transient: [
          TransientResinBatch(id: 'b1', count: 1, expiresAt: now.add(const Duration(hours: 30))),
        ],
        now: now,
        enabled: false,
      );
      expect(planned, isEmpty);
    });

    test('a batch whose 24h-before point is still in the future is planned', () {
      final batch = TransientResinBatch(
        id: 'b1',
        count: 1,
        expiresAt: now.add(const Duration(hours: 30)),
      );
      final planned = planTransientExpiryNotifications(
        profileId: profileId,
        transient: [batch],
        now: now,
        enabled: true,
      );
      expect(planned, hasLength(1));
      expect(planned.single.kind, 'transientExpiry');
      expect(planned.single.id, stableNotificationId(profileId, 'transientExpiry', 'b1'));
      expect(planned.single.scheduledAt, now.add(const Duration(hours: 6)));
    });

    test('a batch whose 24h-before point has already passed is excluded', () {
      final batch = TransientResinBatch(
        id: 'b1',
        count: 1,
        expiresAt: now.add(const Duration(hours: 10)),
      );
      final planned = planTransientExpiryNotifications(
        profileId: profileId,
        transient: [batch],
        now: now,
        enabled: true,
      );
      expect(planned, isEmpty);
    });

    test('multiple batches each get a distinct, stable id', () {
      final planned = planTransientExpiryNotifications(
        profileId: profileId,
        transient: [
          TransientResinBatch(id: 'b1', count: 1, expiresAt: now.add(const Duration(hours: 30))),
          TransientResinBatch(id: 'b2', count: 2, expiresAt: now.add(const Duration(hours: 40))),
        ],
        now: now,
        enabled: true,
      );
      expect(planned, hasLength(2));
      expect(planned.map((p) => p.id).toSet(), hasLength(2));
    });
  });
}
