import 'package:drift/drift.dart';

import '../../../../core/database/tables/profiles_table.dart';

/// The current anchor for one profile's resin — mirrors `ResinState`'s
/// scalar fields 1:1 (`transient` is the only non-scalar field, held in
/// [TransientResinBatches] instead).
@TableIndex(name: 'resin_state_profile_unique', columns: {#profileId}, unique: true)
class ResinStateTable extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  IntColumn get v => integer()();
  DateTimeColumn get n => dateTime().nullable()();

  /// Cached from `game_rules.resin_cap` at profile creation; `ResinEngine`
  /// never hard-codes it.
  IntColumn get cap => integer().withDefault(const Constant(200))();
  IntColumn get condensed => integer().withDefault(const Constant(0))();
  IntColumn get fragile => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One live batch of `TransientResinBatch` — soft-deleted once consumed by
/// `useTransient`. `id` is the same value as `TransientResinBatch.id`, no
/// translation.
@DataClassName('TransientResinBatchRow')
class TransientResinBatches extends Table {
  TextColumn get id => text()();
  TextColumn get resinStateId => text().references(ResinStateTable, #id)();
  IntColumn get count => integer()();
  DateTimeColumn get expiresAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// An append-only ledger entry, one row per `ResinEngine` mutation. `kind`
/// discriminates which of the 6 `ResinEvent` variants this row encodes;
/// the nullable payload columns cover the union of all their fields.
/// `label`/`resultingV` aren't part of the pure `ResinEvent` — they're
/// written by the future controller for Activity-log rendering and
/// cheap history without replay.
///
/// Named `ResinEventRow` (not the default `ResinEvent`) to avoid colliding
/// with the pure-Dart `ResinEvent` sealed union in `features/resin/domain/`.
@DataClassName('ResinEventRow')
class ResinEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get occurredAt => dateTime()();

  /// `'sync'` | `'spend'` | `'craftCondensed'` | `'useFragile'` |
  /// `'useTransient'` | `'useCondensed'`.
  TextColumn get kind => text()();

  IntColumn get x => integer().nullable()(); // sync
  IntColumn get fullInSeconds => integer().nullable()(); // sync
  IntColumn get cost => integer().nullable()(); // spend, craftCondensed
  IntColumn get amount => integer().nullable()(); // craftCondensed, useFragile, useCondensed
  TextColumn get batchId => text().nullable()(); // useTransient
  IntColumn get count => integer().nullable()(); // useTransient

  TextColumn get label => text().nullable()();
  IntColumn get resultingV => integer()();

  BoolColumn get isUndo => boolean().withDefault(const Constant(false))();
  TextColumn get undoneEventId => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
