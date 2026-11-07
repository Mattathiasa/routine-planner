import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Reads and writes the (currently singular) game account.
class ProfileRepository {
  ProfileRepository(this._db);

  final UserDatabase _db;

  /// Returns the one live profile, creating a default one on first launch.
  Future<Profile> getOrCreateDefaultProfile() async {
    final existing = await (_db.select(
      _db.profiles,
    )..where((t) => t.deletedAt.isNull())).getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final row = ProfilesCompanion.insert(
      id: newId(),
      server: 'asia',
      updatedAt: now,
    );
    await _db.into(_db.profiles).insert(row);
    return getOrCreateDefaultProfile();
  }

  Future<Profile?> getProfile(String id) {
    return (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
  }

  Future<void> updateServer(String id, String server) {
    return (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(server: Value(server), updatedAt: Value(DateTime.now().toUtc())),
    );
  }
}
