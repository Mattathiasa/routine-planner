import 'package:drift/drift.dart';

import '../ids.dart';
import '../user_database.dart';

/// Reads and writes per-profile app preferences and resin-value alerts.
class SettingsRepository {
  SettingsRepository(this._db);

  final UserDatabase _db;

  Future<Setting> getOrCreateSettings(String profileId) async {
    final existing = await (_db.select(
      _db.settings,
    )..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())).getSingleOrNull();
    if (existing != null) return existing;

    final row = SettingsCompanion.insert(
      id: newId(),
      profileId: profileId,
      updatedAt: DateTime.now().toUtc(),
    );
    await _db.into(_db.settings).insert(row);
    return getOrCreateSettings(profileId);
  }

  Future<void> updateWorldLevel(String profileId, int worldLevel) {
    return _updateSettings(profileId, SettingsCompanion(worldLevel: Value(worldLevel)));
  }

  Future<void> updateTotalsOnlyMode(String profileId, bool enabled) {
    return _updateSettings(profileId, SettingsCompanion(totalsOnlyMode: Value(enabled)));
  }

  Future<void> updateTransientExpiryAlertEnabled(String profileId, bool enabled) {
    return _updateSettings(
      profileId,
      SettingsCompanion(transientExpiryAlertEnabled: Value(enabled)),
    );
  }

  Future<void> _updateSettings(String profileId, SettingsCompanion patch) {
    return (_db.update(
      _db.settings,
    )..where((t) => t.profileId.equals(profileId))).write(
      patch.copyWith(updatedAt: Value(DateTime.now().toUtc())),
    );
  }

  Future<List<ResinAlertThreshold>> alertsForProfile(String profileId) {
    return (_db.select(_db.resinAlertThresholds)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.threshold)]))
        .get();
  }

  Future<void> addAlertThreshold(String profileId, int threshold) {
    return _db.into(_db.resinAlertThresholds).insert(
      ResinAlertThresholdsCompanion.insert(
        id: newId(),
        profileId: profileId,
        threshold: threshold,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> setAlertEnabled(String id, bool enabled) {
    return (_db.update(_db.resinAlertThresholds)..where((t) => t.id.equals(id))).write(
      ResinAlertThresholdsCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> removeAlertThreshold(String id) {
    return (_db.update(_db.resinAlertThresholds)..where((t) => t.id.equals(id))).write(
      ResinAlertThresholdsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
