import 'package:drift/drift.dart';

/// A game account. Which one is active is tracked separately, in
/// `AppState.selectedProfileId` — this table just holds the accounts
/// themselves.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withDefault(const Constant('Player'))();

  /// A [GameServer.name] string (`'asia'`, `'europe'`, `'america'`, `'twHkMo'`).
  TextColumn get server => text()();

  /// Needed for a stable multi-profile list order — `updatedAt` changes on
  /// every rename/server-switch, so it can't serve that role.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
