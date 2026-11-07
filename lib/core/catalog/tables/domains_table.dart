import 'package:drift/drift.dart';

import 'materials_table.dart';

/// A farmable location: a talent/weapon domain or a boss.
class Domains extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `'talent'` | `'weapon'` | `'boss'`.
  TextColumn get kind => text()();

  /// `'daily'` | `'weekly'` — e.g. "Weekly bosses" resets weekly, not daily.
  TextColumn get resetCadence => text().withDefault(const Constant('daily'))();

  /// Null when uncapped; e.g. `3` for a weekly-capped boss.
  IntColumn get maxRunsPerPeriod => integer().nullable()();

  /// Resin cost of one run (20 for a domain, 40 for a boss, per the Resin
  /// screen's action buttons).
  IntColumn get costResin => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which materials drop from a domain, and on which weekdays. Modeled
/// per-material (not per-domain) so different tiers of the same domain
/// could someday open on different day-subsets.
class DomainDrops extends Table {
  TextColumn get id => text()();
  TextColumn get domainId => text().references(Domains, #id)();
  TextColumn get materialId => text().references(Materials, #id)();

  /// Bit0 = Monday. A domain is also open on Sunday regardless of this mask
  /// — "Sunday opens all" is business logic in the read layer, not stored
  /// redundantly here.
  IntColumn get weekdayMask => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
