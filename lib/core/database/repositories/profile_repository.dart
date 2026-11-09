import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Reads and writes game accounts, and tracks which one is active.
class ProfileRepository {
  ProfileRepository(this._db);

  final UserDatabase _db;

  /// Live profiles, oldest first — a stable order that doesn't shift when a
  /// profile is renamed or its server changes (unlike `updatedAt`).
  Future<List<Profile>> listProfiles() {
    return (_db.select(_db.profiles)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<Profile?> getProfile(String id) {
    return (_db.select(
      _db.profiles,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
  }

  Future<Profile> createProfile({String? displayName, required String server}) async {
    final id = newId();
    final now = DateTime.now().toUtc();
    await _db.into(_db.profiles).insert(
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
    return (await getProfile(id))!;
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
      ProfilesCompanion(server: Value(server), updatedAt: Value(DateTime.now().toUtc())),
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

  Future<void> selectProfile(String id) {
    return _db.into(_db.appState).insertOnConflictUpdate(
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
          AppStateCompanion.insert(id: appStateSingletonId, updatedAt: DateTime.now().toUtc()),
        );
    return _getOrCreateAppState();
  }
}
