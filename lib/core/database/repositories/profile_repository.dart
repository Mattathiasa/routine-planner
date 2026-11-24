import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Sorts after every account that has a stored position.
const _unordered = 1 << 30;

/// Reads and writes game accounts, and tracks which one is active.
class ProfileRepository {
  ProfileRepository(this._db);

  final UserDatabase _db;

  /// Live profiles in the user's own order, falling back to oldest first.
  ///
  /// Accounts with no stored position sort after the ones that have one, by
  /// `createdAt` — so an install that has never reordered anything keeps the
  /// order it always had, and a newly created account lands at the end.
  /// `createdAt` rather than `updatedAt` because renaming an account or
  /// changing its server must not move it.
  Future<List<Profile>> listProfiles() async {
    final profiles =
        await (_db.select(_db.profiles)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    final positions = await _positions();
    if (positions.isEmpty) return profiles;

    // Sorted here rather than in SQL: the list is a handful of rows, and a
    // LEFT JOIN with a null-last ordering is far more machinery than this.
    profiles.sort((a, b) {
      final byPosition = (positions[a.id] ?? _unordered).compareTo(
        positions[b.id] ?? _unordered,
      );
      if (byPosition != 0) return byPosition;
      return a.createdAt.compareTo(b.createdAt);
    });
    return profiles;
  }

  Future<Map<String, int>> _positions() async {
    final rows = await _db.select(_db.profileOrder).get();
    return {for (final row in rows) row.profileId: row.position};
  }

  Future<Profile?> getProfile(String id) {
    return (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
  }

  Future<Profile> createProfile({
    String? displayName,
    required String server,
  }) async {
    final id = newId();
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: id,
            displayName: displayName == null || displayName.isEmpty
                ? const Value.absent()
                : Value(displayName),
            server: server,
            createdAt: Value(now),
            updatedAt: now,
          ),
        );
    // No position row: an unordered account sorts last, which is where a new
    // one belongs.
    return (await getProfile(id))!;
  }

  /// Rewrites the list order to match [orderedIds].
  ///
  /// Takes the whole order rather than a from/to pair so the result can't
  /// drift out of step with what the user sees. Ids not in [orderedIds] keep
  /// whatever position they had, which is what lets a soft-deleted profile
  /// come back via Undo without disturbing anything.
  Future<void> reorderProfiles(List<String> orderedIds) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await _db
            .into(_db.profileOrder)
            .insertOnConflictUpdate(
              ProfileOrderCompanion.insert(
                profileId: orderedIds[i],
                position: i,
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<void> renameProfile(String id, String displayName) {
    return (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(
        displayName: Value(displayName),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateServer(String id, String server) {
    return (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(
        server: Value(server),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Soft-deletes. Doesn't touch `AppState` even if [id] was selected — all
  /// selection-resolution logic stays centralized in [getActiveProfile], so
  /// this method stays single-purpose.
  Future<void> deleteProfile(String id) {
    return (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );
  }

  /// Clears a soft delete — the undo path for [deleteProfile].
  Future<void> restoreProfile(String id) {
    return (_db.update(_db.profiles)..where((t) => t.id.equals(id))).write(
      ProfilesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> selectProfile(String id) {
    return _db
        .into(_db.appState)
        .insertOnConflictUpdate(
          AppStateCompanion.insert(
            id: appStateSingletonId,
            selectedProfileId: Value(id),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Resolves whichever profile should currently be active: the persisted
  /// selection if it still points at a live profile; else the oldest
  /// remaining live profile (persisting that as the new selection, so it's
  /// stable across restarts); else a freshly bootstrapped default if none
  /// remain at all.
  Future<Profile> getActiveProfile() async {
    final state = await _getOrCreateAppState();
    final selectedId = state.selectedProfileId;
    if (selectedId != null) {
      final selected = await getProfile(selectedId);
      if (selected != null) return selected;
    }

    final remaining = await listProfiles();
    if (remaining.isNotEmpty) {
      await selectProfile(remaining.first.id);
      return remaining.first;
    }

    final created = await createProfile(server: 'asia');
    await selectProfile(created.id);
    return created;
  }

  Future<AppStateData> _getOrCreateAppState() async {
    final existing = await (_db.select(
      _db.appState,
    )..where((t) => t.id.equals(appStateSingletonId))).getSingleOrNull();
    if (existing != null) return existing;

    await _db
        .into(_db.appState)
        .insert(
          AppStateCompanion.insert(
            id: appStateSingletonId,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    return _getOrCreateAppState();
  }
}
