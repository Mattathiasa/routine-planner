import 'package:freezed_annotation/freezed_annotation.dart';

part 'resin_event.freezed.dart';

/// One record per resin mutation, carrying just enough payload for a future
/// persistence layer to append an immutable `resin_events` row. Pure Dart —
/// no Drift import here.
@freezed
sealed class ResinEvent with _$ResinEvent {
  const factory ResinEvent.sync({
    required DateTime occurredAt,
    required int x,
    Duration? fullIn,
  }) = ResinEventSync;

  const factory ResinEvent.spend({
    required DateTime occurredAt,
    required int cost,
  }) = ResinEventSpend;

  const factory ResinEvent.craftCondensed({
    required DateTime occurredAt,
    required int cost,
    required int amount,
  }) = ResinEventCraftCondensed;

  const factory ResinEvent.useFragile({
    required DateTime occurredAt,
    required int amount,
  }) = ResinEventUseFragile;

  const factory ResinEvent.useTransient({
    required DateTime occurredAt,
    required String batchId,
    required int count,
  }) = ResinEventUseTransient;

  const factory ResinEvent.useCondensed({
    required DateTime occurredAt,
    required int amount,
  }) = ResinEventUseCondensed;
}
