import 'package:drift/drift.dart';

import 'profiles_table.dart';

/// The order the user dragged their accounts into.
///
/// A table of its own rather than a column on `Profiles`, and not by choice:
/// the v2 migration rebuilds `profiles` with `alterTable`, which copies the
/// table using the *current* Dart definition — so any column added to
/// `Profiles` now makes that historical step try to select a column the old
/// database has never had. A table introduced in its own migration step
/// touches no earlier step at all.
///
/// No `deletedAt`: this is derived interface state, not user content, so a
/// row is simply removed. An account with no row here sorts last, which is
/// also exactly what a newly created account should do.
class ProfileOrder extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();

  /// Zero-based position in the list.
  IntColumn get position => integer()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}
