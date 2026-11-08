import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The HoYoLab session cookie is a real credential — it stays in
/// Android-Keystore-backed secure storage, never in the plain, unencrypted
/// `user.db`, and never leaves the device.
class HoyolabCredentialsStore {
  HoyolabCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _cookieKey = 'hoyolab_cookie';
  static const _uidKey = 'hoyolab_uid';

  Future<void> save({required String cookie, required String uid}) async {
    await _storage.write(key: _cookieKey, value: cookie);
    await _storage.write(key: _uidKey, value: uid);
  }

  Future<({String cookie, String uid})?> read() async {
    final cookie = await _storage.read(key: _cookieKey);
    final uid = await _storage.read(key: _uidKey);
    if (cookie == null || uid == null) return null;
    return (cookie: cookie, uid: uid);
  }

  Future<void> clear() async {
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _uidKey);
  }
}
