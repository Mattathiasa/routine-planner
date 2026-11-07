import 'package:drift/drift.dart';

import '../../../core/database/ids.dart';
import '../../../core/database/user_database.dart';
import '../domain/resin_engine.dart';
import '../domain/resin_event.dart';
import '../domain/resin_state.dart';

/// Thrown by [ResinRepository.undoLastMutation] when there's no live event
/// to undo, or the most recent one is itself an undo (no chained undo).
class NothingToUndoException implements Exception {
  const NothingToUndoException();

  @override
  String toString() => 'NothingToUndoException';
}

/// Thrown by [ResinRepository.undoLastMutation] for a mutation kind with no
/// well-defined inverse: `sync` (an external observation, not a derivable
/// delta) and `useTransient` (the consumed batch's `expiresAt` isn't
/// preserved in the event log).
class UndoNotSupportedException implements Exception {
  const UndoNotSupportedException(this.kind);
  final String kind;

  @override
  String toString() => 'UndoNotSupportedException: cannot undo "$kind"';
}

/// Persists [ResinState]/[ResinEvent] (the already-tested pure `ResinEngine`
/// domain model) into `user.db`. Pure persistence — no regen math here.
class ResinRepository {
  ResinRepository(this._db);

  final UserDatabase _db;

  /// Loads the live resin state for [profileId], creating a default row
  /// (full, at cap — the only invariant-consistent default for a brand new
  /// profile) on first access. The default `cap` is the table's literal
  /// default (200); fetching the real `game_rules.resin_cap` from the
  /// catalog at profile-creation time is future Riverpod-wiring, not this
  /// repository's concern.
  Future<ResinState> loadResinState(String profileId) async {
    final row = await _getOrCreateStateRow(profileId);
    final batches = await (_db.select(_db.transientResinBatches)..where(
      (t) => t.resinStateId.equals(row.id) & t.deletedAt.isNull(),
    )).get();

    return ResinState(
      v: row.v,
      n: row.n,
      cap: row.cap,
      condensed: row.condensed,
      fragile: row.fragile,
      transient: [
        for (final batch in batches)
          TransientResinBatch(id: batch.id, count: batch.count, expiresAt: batch.expiresAt),
      ],
    );
  }

  Future<ResinStateTableData> _getOrCreateStateRow(String profileId) async {
    final existing = await (_db.select(_db.resinStateTable)..where(
      (t) => t.profileId.equals(profileId) & t.deletedAt.isNull(),
    )).getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    await _db.into(_db.resinStateTable).insert(
      ResinStateTableCompanion.insert(
        id: newId(),
        profileId: profileId,
        v: 200,
        updatedAt: now,
      ),
    );
    return _getOrCreateStateRow(profileId);
  }

  /// Applies one `ResinEngine` mutation's result transactionally: overwrite
  /// the scalar `resin_state` row, soft-delete the consumed batch if
  /// [event] is a `useTransient`, and append one `resin_events` row.
  Future<void> saveResinMutation(
    String profileId,
    ResinState newState,
    ResinEvent event, {
    String? label,
  }) {
    return _db.transaction(() async {
      final row = await _getOrCreateStateRow(profileId);
      final now = DateTime.now().toUtc();

      await (_db.update(_db.resinStateTable)..where((t) => t.id.equals(row.id))).write(
        ResinStateTableCompanion(
          v: Value(newState.v),
          n: Value(newState.n),
          cap: Value(newState.cap),
          condensed: Value(newState.condensed),
          fragile: Value(newState.fragile),
          updatedAt: Value(now),
        ),
      );

      if (event case ResinEventUseTransient(batchId: final batchId)) {
        await (_db.update(
          _db.transientResinBatches,
        )..where((t) => t.id.equals(batchId))).write(
          TransientResinBatchesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }

      await _db.into(_db.resinEvents).insert(_eventToRow(profileId, event, newState.v, label, now));
    });
  }

  /// Adds a newly-claimed transient resin batch. There's no `ResinEvent`
  /// variant for "claim a reward," so this isn't routed through the event
  /// log.
  Future<void> addTransientBatch(String profileId, TransientResinBatch batch) async {
    final row = await _getOrCreateStateRow(profileId);
    await _db.into(_db.transientResinBatches).insert(
      TransientResinBatchesCompanion.insert(
        id: batch.id,
        resinStateId: row.id,
        count: batch.count,
        expiresAt: batch.expiresAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<ResinEventRow>> recentEvents(String profileId, {int limit = 20}) {
    return (_db.select(_db.resinEvents)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
  }

  /// Reverses the most recent mutation for [profileId], by reversing its
  /// delta against the *current* live state (a forward-moving compensating
  /// mutation, not a rollback to a historical snapshot — robust to regen
  /// ticks that happened since). Only `spend`/`craftCondensed`/
  /// `useFragile`/`useCondensed` are reversible; see [UndoNotSupportedException].
  Future<void> undoLastMutation(String profileId) {
    return _db.transaction(() async {
      final recent = await (_db.select(_db.resinEvents)
            ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(1))
          .getSingleOrNull();

      if (recent == null || recent.isUndo) {
        throw const NothingToUndoException();
      }

      final row = await _getOrCreateStateRow(profileId);
      final now = DateTime.now().toUtc();
      var newV = row.v;
      var newCondensed = row.condensed;
      var newFragile = row.fragile;

      switch (recent.kind) {
        case 'spend':
          newV += recent.cost!;
        case 'craftCondensed':
          newV += recent.cost!;
          newCondensed -= recent.amount!;
        case 'useFragile':
          newV -= ResinEngine.fragileOrTransientResinValue * recent.amount!;
          newFragile += recent.amount!;
        case 'useCondensed':
          newV -= ResinEngine.condensedResinValue * recent.amount!;
          newCondensed += recent.amount!;
        default:
          throw UndoNotSupportedException(recent.kind);
      }

      final newN = newV >= row.cap
          ? null
          : now.add(const ResinEngine().regenInterval);

      await (_db.update(_db.resinStateTable)..where((t) => t.id.equals(row.id))).write(
        ResinStateTableCompanion(
          v: Value(newV),
          n: Value(newN),
          condensed: Value(newCondensed),
          fragile: Value(newFragile),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.resinEvents).insert(
        ResinEventsCompanion.insert(
          id: newId(),
          profileId: profileId,
          occurredAt: now,
          kind: recent.kind,
          x: Value(recent.x),
          fullInSeconds: Value(recent.fullInSeconds),
          cost: Value(recent.cost),
          amount: Value(recent.amount),
          batchId: Value(recent.batchId),
          count: Value(recent.count),
          label: Value(recent.label),
          resultingV: newV,
          isUndo: const Value(true),
          undoneEventId: Value(recent.id),
          updatedAt: now,
        ),
      );
    });
  }

  ResinEventsCompanion _eventToRow(
    String profileId,
    ResinEvent event,
    int resultingV,
    String? label,
    DateTime now,
  ) {
    final (kind, x, fullInSeconds, cost, amount, batchId, count) = switch (event) {
      ResinEventSync(x: final x, fullIn: final fullIn) => (
        'sync',
        x,
        fullIn?.inSeconds,
        null,
        null,
        null,
        null,
      ),
      ResinEventSpend(cost: final cost) => ('spend', null, null, cost, null, null, null),
      ResinEventCraftCondensed(cost: final cost, amount: final amount) => (
        'craftCondensed',
        null,
        null,
        cost,
        amount,
        null,
        null,
      ),
      ResinEventUseFragile(amount: final amount) => (
        'useFragile',
        null,
        null,
        null,
        amount,
        null,
        null,
      ),
      ResinEventUseTransient(batchId: final batchId, count: final count) => (
        'useTransient',
        null,
        null,
        null,
        null,
        batchId,
        count,
      ),
      ResinEventUseCondensed(amount: final amount) => (
        'useCondensed',
        null,
        null,
        null,
        amount,
        null,
        null,
      ),
    };

    return ResinEventsCompanion.insert(
      id: newId(),
      profileId: profileId,
      occurredAt: event.occurredAt,
      kind: kind,
      x: Value(x),
      fullInSeconds: Value(fullInSeconds),
      cost: Value(cost),
      amount: Value(amount),
      batchId: Value(batchId),
      count: Value(count),
      label: Value(label),
      resultingV: resultingV,
      updatedAt: now,
    );
  }
}
