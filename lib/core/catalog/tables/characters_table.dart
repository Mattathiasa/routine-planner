import 'package:drift/drift.dart';

class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get rarity => integer()();
  TextColumn get element => text()();
  TextColumn get weaponType => text()();

  @override
  Set<Column> get primaryKey => {id};
}
