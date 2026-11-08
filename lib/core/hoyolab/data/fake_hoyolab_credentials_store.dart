import 'hoyolab_credentials_store.dart';

/// A [HoyolabCredentialsStore] double for tests — same placement
/// convention as `core/clock/fake_clock.dart` and
/// `core/notifications/data/fake_notification_scheduler.dart`. Avoids
/// `flutter_secure_storage`'s platform channel, which has no mock under
/// plain `flutter_test` and never resolves.
class FakeHoyolabCredentialsStore implements HoyolabCredentialsStore {
  ({String cookie, String uid})? _value;

  @override
  Future<void> save({required String cookie, required String uid}) async {
    _value = (cookie: cookie, uid: uid);
  }

  @override
  Future<({String cookie, String uid})?> read() async => _value;

  @override
  Future<void> clear() async {
    _value = null;
  }
}
