import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/features/resin/data/resin_repository.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';

void main() {
  late UserDatabase db;
  late ResinRepository repository;
  late String profileId;
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = ResinRepository(db);
    profileId = (await ProfileRepository(db).getOrCreateDefaultProfile()).id;
  });

  tearDown(() => db.close());

  test('loadResinState creates a default row (full, at cap) on first access', () async {
    final state = await repository.loadResinState(profileId);
    expect(state.v, 200);
    expect(state.cap, 200);
    expect(state.n, isNull);
    expect(state.condensed, 0);
    expect(state.fragile, 0);
    expect(state.transient, isEmpty);

    await repository.loadResinState(profileId);
    expect(await db.select(db.resinStateTable).get(), hasLength(1));
  });

  test('sync round-trips through save/load, including a transient batch', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, event) = engine.sync(
      initial,
      now,
      x: 143,
      fullIn: const Duration(hours: 5, minutes: 20),
    );
    await repository.saveResinMutation(profileId, synced, event);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 143);
    expect(reloaded.n, synced.n);

    final batch = TransientResinBatch(
      id: 'batch-1',
      count: 1,
      expiresAt: now.add(const Duration(days: 4)),
    );
    await repository.addTransientBatch(profileId, batch);

    final withBatch = await repository.loadResinState(profileId);
    expect(withBatch.transient, [batch]);
  });

  test('spend after sync appends a second event and decreases v', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    final afterSync = await repository.loadResinState(profileId);
    final later = now.add(const Duration(minutes: 1));
    final (spent, spendEvent) = engine.spend(afterSync, later, cost: 30);
    await repository.saveResinMutation(profileId, spent, spendEvent, label: 'Ember core');

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 70);

    final events = await repository.recentEvents(profileId);
    expect(events.map((e) => e.kind), ['spend', 'sync']);
    expect(events.first.label, 'Ember core');
    expect(events.first.resultingV, 70);
  });

  test('useTransient soft-deletes the consumed batch and increases v', () async {
    final initial = await repository.loadResinState(profileId);
    final batch = TransientResinBatch(
      id: 'batch-1',
      count: 2,
      expiresAt: now.add(const Duration(days: 1)),
    );
    await repository.addTransientBatch(profileId, batch);
    final stateWithBatch = await repository.loadResinState(profileId);

    final (result, event) = engine.useTransient(stateWithBatch, now, batchId: 'batch-1');
    await repository.saveResinMutation(profileId, result, event);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.transient, isEmpty);
    expect(reloaded.v, initial.v + 60 * 2);

    final batchRow = await (db.select(
      db.transientResinBatches,
    )..where((t) => t.id.equals('batch-1'))).getSingle();
    expect(batchRow.deletedAt, isNotNull);
  });

  test('a transaction that throws does not persist partial writes', () async {
    final initial = await repository.loadResinState(profileId);
    final row = await (db.select(
      db.resinStateTable,
    )..where((t) => t.profileId.equals(profileId))).getSingle();

    await expectLater(
      db.transaction(() async {
        await (db.update(
          db.resinStateTable,
        )..where((t) => t.id.equals(row.id))).write(
          const ResinStateTableCompanion(v: Value(9999)),
        );
        throw Exception('simulated failure');
      }),
      throwsException,
    );

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, initial.v);
  });
}
