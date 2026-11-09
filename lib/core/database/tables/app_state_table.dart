import 'package:drift/drift.dart';

/// App-wide state that isn't scoped to any one profile — currently just
/// which profile is selected. Exactly one row (see `ids.appStateSingletonId`),
/// same "one wide typed row" shape `Settings` uses per-profile.
///
/// No FK on [selectedProfileId]: it's allowed to point at a soft-deleted
/// profile briefly, between a delete and the next resolve in
/// `ProfileRepository.getActiveProfile`.
class AppState extends Table {
  TextColumn get id => text()();
  TextColumn get selectedProfileId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
