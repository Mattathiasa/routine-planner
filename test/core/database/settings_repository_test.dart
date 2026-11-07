import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/repositories/profile_repository.dart';
import 'package:routine_planner/core/database/repositories/settings_repository.dart';
import 'package:routine_planner/core/database/user_database.dart';

void main() {
  late UserDatabase db;
  late SettingsRepository settingsRepository;
  late String profileId;

  tearDown(() => db.close());

  group('settings', () {
    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      settingsRepository = SettingsRepository(db);
      profileId = (await ProfileRepository(db).getOrCreateDefaultProfile()).id;
    });

    test('getOrCreateSettings creates exactly one row with defaults', () async {
      final created = await settingsRepository.getOrCreateSettings(profileId);
      expect(created.worldLevel, 0);
      expect(created.totalsOnlyMode, isFalse);
      expect(created.transientExpiryAlertEnabled, isTrue);

      final again = await settingsRepository.getOrCreateSettings(profileId);
      expect(again.id, created.id);

      final all = await db.select(db.settings).get();
      expect(all, hasLength(1));
    });

    test('updateWorldLevel and updateTotalsOnlyMode persist', () async {
      await settingsRepository.getOrCreateSettings(profileId);
      await settingsRepository.updateWorldLevel(profileId, 7);
      await settingsRepository.updateTotalsOnlyMode(profileId, true);

      final updated = await settingsRepository.getOrCreateSettings(profileId);
      expect(updated.worldLevel, 7);
      expect(updated.totalsOnlyMode, isTrue);
    });
  });

  group('resin alert thresholds', () {
    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      settingsRepository = SettingsRepository(db);
      profileId = (await ProfileRepository(db).getOrCreateDefaultProfile()).id;
    });

    test('addAlertThreshold then alertsForProfile returns it ordered', () async {
      await settingsRepository.addAlertThreshold(profileId, 200);
      await settingsRepository.addAlertThreshold(profileId, 160);

      final alerts = await settingsRepository.alertsForProfile(profileId);
      expect(alerts.map((a) => a.threshold), [160, 200]);
    });

    test('removeAlertThreshold soft-deletes and excludes it from the list', () async {
      await settingsRepository.addAlertThreshold(profileId, 160);
      final [alert] = await settingsRepository.alertsForProfile(profileId);

      await settingsRepository.removeAlertThreshold(alert.id);

      expect(await settingsRepository.alertsForProfile(profileId), isEmpty);
    });

    test(
      'the same threshold can be re-added after the old row is soft-deleted',
      () async {
        await settingsRepository.addAlertThreshold(profileId, 160);
        final [alert] = await settingsRepository.alertsForProfile(profileId);
        await settingsRepository.removeAlertThreshold(alert.id);

        await settingsRepository.addAlertThreshold(profileId, 160);

        expect(await settingsRepository.alertsForProfile(profileId), hasLength(1));
      },
    );

    test('two simultaneously-live rows for the same threshold are rejected', () async {
      await settingsRepository.addAlertThreshold(profileId, 160);

      expect(
        () => settingsRepository.addAlertThreshold(profileId, 160),
        throwsA(isA<Exception>()),
      );
    });
  });
}
