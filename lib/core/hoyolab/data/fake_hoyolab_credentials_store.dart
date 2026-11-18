import 'hoyolab_credentials_store.dart';

/// A [HoyolabCredentialsStore] double for tests — same placement
/// convention as `core/clock/fake_clock.dart` and
/// `core/notifications/data/fake_notification_scheduler.dart`. Avoids
/// `flutter_secure_storage`'s platform channel, which has no mock under
/// plain `flutter_test` and never resolves.
///
/// Pass [legacyCredential] to simulate a keystore still holding a
/// pre-multi-login (global) credential, so the adoption path can be tested.
class FakeHoyolabCredentialsStore implements HoyolabCredentialsStore {
  FakeHoyolabCredentialsStore({({String cookie, String uid})? legacyCredential})
    : _legacy = legacyCredential;

  final _byProfile = <String, ({String cookie, String uid})>{};
  ({String cookie, String uid})? _legacy;

  /// What the fake keystore holds for every profile — test-only view.
  Map<String, ({String cookie, String uid})> get saved =>
      Map.unmodifiable(_byProfile);

  ({String cookie, String uid})? get legacyCredential => _legacy;

  @override
  Future<void> save({
    required String profileId,
    required String cookie,
    required String uid,
  }) async {
    _byProfile[profileId] = (cookie: cookie, uid: uid);
  }

  @override
  Future<({String cookie, String uid})?> read(String profileId) async =>
      _byProfile[profileId];

  @override
  Future<void> clear(String profileId) async {
    _byProfile.remove(profileId);
  }

  @override
  Future<void> adoptLegacyCredential(String profileId) async {
    final legacy = _legacy;
    if (legacy == null) return;
    _byProfile.putIfAbsent(profileId, () => legacy);
    _legacy = null;
  }
}
