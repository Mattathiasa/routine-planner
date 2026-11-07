import 'package:freezed_annotation/freezed_annotation.dart';

part 'resin_state.freezed.dart';

/// A batch of transient resin (e.g. event rewards) that expires at a fixed
/// time and is otherwise worth [fragileOrTransientResinValue] resin each
/// when used, same as fragile resin.
@freezed
abstract class TransientResinBatch with _$TransientResinBatch {
  const factory TransientResinBatch({
    required String id,
    required int count,
    required DateTime expiresAt,
  }) = _TransientResinBatch;
}

/// Resin state stored as an anchor — the resin value `v` as of time `n`'s
/// *previous* tick, plus `n`, the time of the *next* +1 tick (null once at
/// or above `cap`) — never as a live ticking counter.
///
/// `cap` (`C` in the architecture doc) is a constructor parameter rather
/// than a hard-coded literal: it ultimately comes from a `game_rules` table,
/// not from domain code.
@freezed
abstract class ResinState with _$ResinState {
  const factory ResinState({
    required int v,
    DateTime? n,
    @Default(200) int cap,
    @Default(0) int condensed,
    @Default(0) int fragile,
    @Default(<TransientResinBatch>[]) List<TransientResinBatch> transient,
  }) = _ResinState;
}
