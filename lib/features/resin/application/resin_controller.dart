import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../data/resin_providers.dart';
import '../domain/resin_engine.dart';
import '../domain/resin_event.dart';
import '../domain/resin_state.dart';

part 'resin_controller.g.dart';

/// Wraps the pure [ResinEngine] with persistence via [ResinRepository]. The
/// shared source of truth for both the Today hero card and the Resin
/// screen, so they never disagree.
@riverpod
class ResinController extends _$ResinController {
  static const _engine = ResinEngine();

  @override
  Future<ResinState> build() async {
    final profileId = (await ref.watch(currentProfileProvider.future)).id;
    return ref.watch(resinRepositoryProvider).loadResinState(profileId);
  }

  Future<void> sync(int x, {Duration? fullIn}) {
    return _mutate((state, now) => _engine.sync(state, now, x: x, fullIn: fullIn));
  }

  Future<void> spend(int cost, {String? label}) {
    return _mutate((state, now) => _engine.spend(state, now, cost: cost), label: label);
  }

  Future<void> craftCondensed({required int cost, int amount = 1}) {
    return _mutate(
      (state, now) => _engine.craftCondensed(state, now, cost: cost, amount: amount),
    );
  }

  Future<void> useFragile({int amount = 1}) {
    return _mutate((state, now) => _engine.useFragile(state, now, amount: amount));
  }

  Future<void> useCondensed({int amount = 1}) {
    return _mutate((state, now) => _engine.useCondensed(state, now, amount: amount));
  }

  Future<void> useTransient(String batchId) {
    return _mutate((state, now) => _engine.useTransient(state, now, batchId: batchId));
  }

  /// Reverses the most recent mutation, if it's reversible — see
  /// [ResinRepository.undoLastMutation].
  Future<void> undoLast() async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref.read(resinRepositoryProvider).undoLastMutation(profileId);
    ref.invalidateSelf();
  }

  Future<void> _mutate(
    (ResinState, ResinEvent) Function(ResinState state, DateTime now) run, {
    String? label,
  }) async {
    final current = await future;
    final now = ref.read(clockProvider).nowUtc();
    final (newState, event) = run(current, now);
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref
        .read(resinRepositoryProvider)
        .saveResinMutation(profileId, newState, event, label: label);
    state = AsyncData(newState);
  }
}
