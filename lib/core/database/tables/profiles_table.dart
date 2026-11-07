import 'package:drift/drift.dart';

/// A game account. The v1 UI only ever shows one, but the table exists so
/// multi-account support doesn't require a schema change later.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withDefault(const Constant('Player'))();

  /// A [GameServer.name] string (`'asia'`, `'europe'`, `'america'`, `'twHkMo'`).
  TextColumn get server => text()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
