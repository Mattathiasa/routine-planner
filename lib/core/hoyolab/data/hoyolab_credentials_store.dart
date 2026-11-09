import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The HoYoLab session cookie is a real credential — it stays in
/// Android-Keystore-backed secure storage, never in the plain, unencrypted
/// `user.db`, and never leaves the device.
///
/// One global credential, not per-profile: connecting a HoYoLab account
/// affects resin sync under every local profile, not just whichever one
/// was selected when you connected. A deliberate v1 limitation — proper
/// multi-login support (one HoYoLab account per profile) is a separate,
/// larger piece of work, not an oversight here.
abstract class HoyolabCredentialsStore {
  Future<void> save({required String cookie, required String uid});
  Future<({String cookie, String uid})?> read();
  Future<void> clear();
}

class SecureHoyolabCredentialsStore implements HoyolabCredentialsStore {
  SecureHoyolabCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _cookieKey = 'hoyolab_cookie';
  static const _uidKey = 'hoyolab_uid';

  @override
  Future<void> save({required String cookie, required String uid}) async {
    await _storage.write(key: _cookieKey, value: cookie);
    await _storage.write(key: _uidKey, value: uid);
  }

  @override
  Future<({String cookie, String uid})?> read() async {
    final cookie = await _storage.read(key: _cookieKey);
    final uid = await _storage.read(key: _uidKey);
    if (cookie == null || uid == null) return null;
    return (cookie: cookie, uid: uid);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _uidKey);
  }
}
