import 'package:drift/drift.dart';

/// EXP (and Mora) needed to go from `level` to `level + 1`. Sparse seed
/// rows only — not a full leveling ladder.
class ExpCurves extends Table {
  /// `'character'` | `'weapon'`.
  TextColumn get entityKind => text()();
  IntColumn get level => integer()();
  IntColumn get expToNext => integer()();
  IntColumn get moraToNext => integer().nullable()();

  @override
  Set<Column> get primaryKey => {entityKind, level};
}
