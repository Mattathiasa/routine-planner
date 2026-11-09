import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/planner_repository.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/repositories/settings_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/features/resin/data/resin_repository.dart';
import 'package:routine_planner/features/resin/domain/resin_state.dart';
import 'package:routine_planner/features/settings/data/backup_service.dart';

void main() {
  late UserDatabase db;
  late String profileId;
  late BackupService backup;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    backup = BackupService(db);

    final profile = await ProfileRepository(db).getActiveProfile();
    profileId = profile.id;

    final settingsRepo = SettingsRepository(db);
    await settingsRepo.getOrCreateSettings(profileId);
    await settingsRepo.updateWorldLevel(profileId, 5);
    await settingsRepo.addAlertThreshold(profileId, 160);
    await settingsRepo.addAlertThreshold(profileId, 200);

    final resinRepo = ResinRepository(db);
    await resinRepo.loadResinState(profileId);
    await resinRepo.addTransientBatch(
      profileId,
      TransientResinBatch(id: 'batch-1', count: 2, expiresAt: DateTime.utc(2026, 2, 1)),
    );

    final plannerRepo = PlannerRepository(db);
    await plannerRepo.upsertTarget(
      PlannerTargetsCompanion.insert(
        id: 'target-1',
        profileId: profileId,
        entityKind: 'character',
        entityId: 'aster',
        currentLevel: 1,
        goalLevel: 90,
        currentAscension: 0,
        goalAscension: 6,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await plannerRepo.setInventoryCount(profileId, 'ember_core', 7);
  });

  tearDown(() => db.close());

  test('export then import restores every table exactly, ids included', () async {
    final exported = await backup.exportBackupJson(profileId);

    // Mutate everything further after the export.
    final settingsRepo = SettingsRepository(db);
    await settingsRepo.updateWorldLevel(profileId, 9);
    await settingsRepo.addAlertThreshold(profileId, 180);
    final plannerRepo = PlannerRepository(db);
    await plannerRepo.setInventoryCount(profileId, 'ember_core', 999);
    await plannerRepo.upsertTarget(
      PlannerTargetsCompanion.insert(
        id: 'target-2',
        profileId: profileId,
        entityKind: 'weapon',
        entityId: 'larkspur_spear',
        currentLevel: 1,
        goalLevel: 90,
        currentAscension: 0,
        goalAscension: 6,
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    await backup.importBackupJson(exported);

    final profiles = await db.select(db.profiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, profileId);

    final settings = await (db.select(
      db.settings,
    )..where((t) => t.profileId.equals(profileId))).getSingle();
    expect(settings.worldLevel, 5);

    final alerts = await (db.select(
      db.resinAlertThresholds,
    )..where((t) => t.profileId.equals(profileId))).get();
    expect(alerts.map((a) => a.threshold).toSet(), {160, 200});

    final targets = await (db.select(
      db.plannerTargets,
    )..where((t) => t.profileId.equals(profileId))).get();
    expect(targets.map((t) => t.id).toSet(), {'target-1'});

    final inventory = await (db.select(
      db.materialInventory,
    )..where((t) => t.profileId.equals(profileId) & t.materialId.equals('ember_core'))).getSingle();
    expect(inventory.count, 7);

    final restoredState = await ResinRepository(db).loadResinState(profileId);
    expect(restoredState.transient, hasLength(1));
    expect(restoredState.transient.single.id, 'batch-1');
    expect(restoredState.transient.single.count, 2);
  });

  test('importing an unsupported format version throws', () async {
    expect(
      () => backup.importBackupJson('{"formatVersion": 999, "tables": {}}'),
      throwsFormatException,
    );
  });

  test('importing profile A leaves profile B completely untouched', () async {
    final profileRepo = ProfileRepository(db);
    final profileB = await profileRepo.createProfile(displayName: 'Alt', server: 'europe');
    final settingsRepo = SettingsRepository(db);
    await settingsRepo.getOrCreateSettings(profileB.id);
    await settingsRepo.updateWorldLevel(profileB.id, 3);
    final plannerRepo = PlannerRepository(db);
    await plannerRepo.setInventoryCount(profileB.id, 'ember_core', 42);

    final exportedA = await backup.exportBackupJson(profileId);

    // Mutate both profiles further before importing A's backup.
    await settingsRepo.updateWorldLevel(profileId, 9);
    await settingsRepo.updateWorldLevel(profileB.id, 7);
    await plannerRepo.setInventoryCount(profileB.id, 'ember_core', 999);

    final importedId = await backup.importBackupJson(exportedA);
    expect(importedId, profileId);

    final profiles = await db.select(db.profiles).get();
    expect(profiles.map((p) => p.id).toSet(), {profileId, profileB.id});

    final settingsB = await (db.select(
      db.settings,
    )..where((t) => t.profileId.equals(profileB.id))).getSingle();
    expect(settingsB.worldLevel, 7);

    final inventoryB = await (db.select(
      db.materialInventory,
    )..where((t) => t.profileId.equals(profileB.id) & t.materialId.equals('ember_core'))).getSingle();
    expect(inventoryB.count, 999);

    final settingsA = await (db.select(
      db.settings,
    )..where((t) => t.profileId.equals(profileId))).getSingle();
    expect(settingsA.worldLevel, 5);
  });
}
