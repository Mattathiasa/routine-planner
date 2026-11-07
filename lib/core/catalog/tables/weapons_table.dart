import 'package:drift/drift.dart';

class Weapons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get rarity => integer()();
  TextColumn get weaponType => text()();

  @override
  Set<Column> get primaryKey => {id};
}
