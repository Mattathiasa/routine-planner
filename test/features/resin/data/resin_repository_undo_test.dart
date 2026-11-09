import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/features/resin/data/resin_repository.dart';
import 'package:routine_planner/features/resin/domain/resin_engine.dart';

void main() {
  late UserDatabase db;
  late ResinRepository repository;
  late String profileId;
  const engine = ResinEngine();
  final now = DateTime.utc(2026, 1, 1, 12);
  final later = now.add(const Duration(minutes: 1));
  final evenLater = now.add(const Duration(minutes: 2));

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = ResinRepository(db);
    profileId = (await ProfileRepository(db).getActiveProfile()).id;
  });

  tearDown(() => db.close());

  test('undoing a spend restores v and leaves inventory untouched', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    final afterSync = await repository.loadResinState(profileId);
    final (spent, spendEvent) = engine.spend(afterSync, later, cost: 30);
    await repository.saveResinMutation(profileId, spent, spendEvent);

    await repository.undoLastMutation(profileId);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 100);
    expect(reloaded.condensed, 0);
    expect(reloaded.fragile, 0);
  });

  test('undoing craftCondensed restores both v and the condensed count', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    final afterSync = await repository.loadResinState(profileId);
    final (crafted, craftEvent) = engine.craftCondensed(afterSync, later, cost: 40);
    await repository.saveResinMutation(profileId, crafted, craftEvent);

    await repository.undoLastMutation(profileId);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 100);
    expect(reloaded.condensed, 0);
  });

  test('undoing useFragile restores both v and the fragile count', () async {
    // There's no "gain fragile resin" mutation in the domain (it's not
    // modeled — presumably an external game drop), so seed it via sync()'s
    // copyWith passthrough: everything but v/n carries through from the
    // input state.
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial.copyWith(fragile: 1), now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    var state = await repository.loadResinState(profileId);
    expect(state.fragile, 1);

    final (used, useEvent) = engine.useFragile(state, later);
    await repository.saveResinMutation(profileId, used, useEvent);

    state = await repository.loadResinState(profileId);
    expect(state.v, 160); // 100 + 60
    expect(state.fragile, 0);

    await repository.undoLastMutation(profileId);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 100);
    expect(reloaded.fragile, 1);
  });

  test('undoing useCondensed restores both v and the condensed count', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    var state = await repository.loadResinState(profileId);
    final (crafted, craftEvent) = engine.craftCondensed(state, later, cost: 40, amount: 1);
    await repository.saveResinMutation(profileId, crafted, craftEvent);

    state = await repository.loadResinState(profileId);
    final (used, useEvent) = engine.useCondensed(state, evenLater);
    await repository.saveResinMutation(profileId, used, useEvent);

    await repository.undoLastMutation(profileId);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 60); // 100 - 40 (craft) + 40 (used) - 40 (undo of use)
    expect(reloaded.condensed, 1);
  });

  test('undoing sync throws UndoNotSupportedException', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    expect(
      () => repository.undoLastMutation(profileId),
      throwsA(isA<UndoNotSupportedException>()),
    );
  });

  test('undo with no prior events throws NothingToUndoException', () async {
    expect(
      () => repository.undoLastMutation(profileId),
      throwsA(isA<NothingToUndoException>()),
    );
  });

  test('undoing twice in a row throws NothingToUndoException the second time', () async {
    final initial = await repository.loadResinState(profileId);
    final (synced, syncEvent) = engine.sync(initial, now, x: 100);
    await repository.saveResinMutation(profileId, synced, syncEvent);

    var state = await repository.loadResinState(profileId);
    final (spent, spendEvent) = engine.spend(state, later, cost: 30);
    await repository.saveResinMutation(profileId, spent, spendEvent);

    await repository.undoLastMutation(profileId);

    expect(
      () => repository.undoLastMutation(profileId),
      throwsA(isA<NothingToUndoException>()),
    );
  });

  test('undo re-anchors the timer, restarting it when the result drops below cap', () async {
    final initial = await repository.loadResinState(profileId);
    expect(initial.v, 200);
    expect(initial.n, isNull);

    final (spent, spendEvent) = engine.spend(initial, now, cost: 50);
    await repository.saveResinMutation(profileId, spent, spendEvent);

    await repository.undoLastMutation(profileId);

    final reloaded = await repository.loadResinState(profileId);
    expect(reloaded.v, 200);
    expect(reloaded.n, isNull); // back at cap: still no regen timer
  });
}
