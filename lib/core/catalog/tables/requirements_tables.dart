import 'package:drift/drift.dart';

import 'materials_table.dart';

/// Material cost of one ascension phase for a character or weapon. The
/// future aggregation algorithm reads this uniformly — Mora is just another
/// row pointing at a `materials` entry with `category = 'currency'`, not a
/// special column.
class AscensionRequirements extends Table {
  /// `'character'` | `'weapon'`.
  TextColumn get entityKind => text()();
  TextColumn get entityId => text()();
  IntColumn get phase => integer()();
  TextColumn get materialId => text().references(Materials, #id)();
  IntColumn get quantity => integer()();

  @override
  Set<Column> get primaryKey => {entityKind, entityId, phase, materialId};
}

/// Material cost of one talent level. No per-slot index — a character's
/// three talents are assumed to share one cost curve; per-talent progress
/// is tracked only in the user's `planner_targets`.
class TalentRequirements extends Table {
  TextColumn get entityId => text()();
  IntColumn get level => integer()();
  TextColumn get materialId => text().references(Materials, #id)();
  IntColumn get quantity => integer()();

  @override
  Set<Column> get primaryKey => {entityId, level, materialId};
}
