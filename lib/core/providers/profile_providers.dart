import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'current_profile_provider.dart';
import 'repository_providers.dart';

part 'profile_providers.g.dart';

/// Every live profile, for the Settings account switcher. Not `keepAlive` —
/// scoped to however long Settings is open, re-fetched fresh each time.
///
/// Watches `currentProfileProvider` first (ignoring its value) purely to
/// force `getActiveProfile`'s bootstrap-on-empty to run before listing —
/// without that, this could race ahead of the first-ever profile being
/// created and briefly list zero profiles.
///
/// A plain record list rather than raw `Profile` rows, matching
/// `current_profile_provider.dart`'s existing workaround for
/// `riverpod_generator`'s inability to resolve types declared entirely in
/// Drift's generated output.
@riverpod
Future<List<({String id, String displayName, String server})>> profileList(Ref ref) async {
  await ref.watch(currentProfileProvider.future);
  final profiles = await ref.watch(profileRepositoryProvider).listProfiles();
  return [for (final p in profiles) (id: p.id, displayName: p.displayName, server: p.server)];
}
