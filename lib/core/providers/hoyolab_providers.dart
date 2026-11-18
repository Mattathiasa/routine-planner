import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../hoyolab/data/hoyolab_client.dart';
import '../hoyolab/data/hoyolab_credentials_store.dart';
import '../hoyolab/data/hoyolab_web_login.dart';
import '../hoyolab/data/hoyolab_web_login_real.dart';
import 'current_profile_provider.dart';

part 'hoyolab_providers.g.dart';

@Riverpod(keepAlive: true)
HoyolabClient hoyolabClient(Ref ref) => HoyolabClient();

@Riverpod(keepAlive: true)
HoyolabCredentialsStore hoyolabCredentialsStore(Ref ref) =>
    SecureHoyolabCredentialsStore();

@Riverpod(keepAlive: true)
HoyolabWebLogin hoyolabWebLogin(Ref ref) => RealHoyolabWebLogin();

/// One-shot migration of a pre-multi-login credential onto the selected
/// profile. Watched once in `AppShell`, which is always mounted past
/// initial routing — the same trick `notificationReconcileProvider` uses
/// to cover "app start" without a manual call site. Idempotent: the store
/// deletes the legacy keys, so a second run finds nothing to adopt.
@Riverpod(keepAlive: true)
Future<void> hoyolabLegacyCredentialAdoption(Ref ref) async {
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  await ref.watch(hoyolabCredentialsStoreProvider).adoptLegacyCredential(profileId);
  // Whatever was adopted belongs to this profile now; let readers re-read.
  ref.invalidate(hoyolabCredentialsForProvider(profileId));
}

/// The HoYoLab credential for one specific profile — the real accessor,
/// used wherever every account is considered at once (the all-accounts
/// strip, the refresh service, notification fan-out).
///
/// Manually invalidated after `save`/`clear`, same convention as every
/// other provider in this app (secure storage has no native "watch"
/// mechanism to hook a reactive provider to).
@riverpod
Future<({String cookie, String uid})?> hoyolabCredentialsFor(
  Ref ref,
  String profileId,
) {
  return ref.watch(hoyolabCredentialsStoreProvider).read(profileId);
}

/// Whether the *currently selected* account has a HoYoLab login, and its
/// saved UID. A thin view over [hoyolabCredentialsForProvider] for the
/// screens that only ever act on the active profile.
@riverpod
Future<({String cookie, String uid})?> hoyolabCredentials(Ref ref) async {
  final profileId = (await ref.watch(currentProfileProvider.future)).id;
  return ref.watch(hoyolabCredentialsForProvider(profileId).future);
}
