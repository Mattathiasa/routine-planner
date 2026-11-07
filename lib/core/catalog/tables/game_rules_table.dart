import 'package:drift/drift.dart';

/// Tunable game constants (e.g. the resin cap) that domain code reads
/// instead of hard-coding — a genuinely open-ended key/value set, unlike
/// the user's `settings` table's fixed fields.
class GameRules extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
