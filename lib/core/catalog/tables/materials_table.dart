import 'package:drift/drift.dart';

/// A catalog item: tiered ascension/talent materials, EXP books, currency,
/// or boss materials. `tier`/`tierGroup` support the future ratio-3
/// tier-walking aggregation; `domainId` links it back to where it drops
/// (nullable for currency/EXP books, which don't come from a domain).
class Materials extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `'tieredMaterial'` | `'bossMaterial'` | `'expBook'` | `'currency'`.
  TextColumn get category => text()();

  IntColumn get tier => integer().nullable()();
  TextColumn get tierGroup => text().nullable()();
  TextColumn get domainId => text().nullable()();

  /// EXP value when consumed, for a future "largest book first" selection.
  IntColumn get expValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
