import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';

part 'settings_providers.g.dart';

/// Plain fields only, never the Drift-generated `Setting` row — see
/// `current_profile_provider.dart`'s doc comment for why.
typedef SettingsSnapshot = ({int worldLevel, bool totalsOnlyMode, bool transientExpiryAlertEnabled});

@riverpod
Future<SettingsSnapshot> settingsSnapshot(Ref ref) async {
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  final settings = await ref.watch(settingsRepositoryProvider).getOrCreateSettings(profileId);
  return (
    worldLevel: settings.worldLevel,
    totalsOnlyMode: settings.totalsOnlyMode,
    transientExpiryAlertEnabled: settings.transientExpiryAlertEnabled,
  );
}

@riverpod
Future<String> catalogVersion(Ref ref) {
  return ref.watch(catalogRepositoryProvider).catalogVersion();
}
