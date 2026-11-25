import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The HoYoLab session cookie is a real credential — it stays in
/// platform-backed secure storage (Android Keystore / iOS Keychain), never
/// in the plain, unencrypted `user.db`, and never leaves the device.
///
/// One credential per local profile: each account carries its own HoYoLab
/// login, so connecting one leaves the others untouched. Keys are
/// namespaced by profile id (see [SecureHoyolabCredentialsStore]).
///
/// Soft-deleting a profile deliberately leaves its credential in place,
/// matching the delete dialog's promise that the data stays on the device
/// — otherwise Undo would restore the profile but silently drop its
/// HoYoLab link. [clear] is the only thing that forgets a credential.
abstract class HoyolabCredentialsStore {
  Future<void> save({
    required String profileId,
    required String cookie,
    required String uid,
  });

  Future<({String cookie, String uid})?> read(String profileId);

  Future<void> clear(String profileId);

  /// Moves a pre-multi-login credential (stored under the old global keys)
  /// onto [profileId], then forgets the global copy. A no-op once there is
  /// nothing left to adopt, so it is safe to call on every app start.
  Future<void> adoptLegacyCredential(String profileId);
}

class SecureHoyolabCredentialsStore implements HoyolabCredentialsStore {
  SecureHoyolabCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(iOptions: _iosOptions);

  /// `first_unlock_this_device` rather than the plugin's default `unlocked`:
  /// the launch-time notification reconcile reads every profile's credential,
  /// and an `unlocked` item is unreadable before the first unlock after a
  /// reboot — which would return null and read as "not connected" rather
  /// than failing loudly. `ThisDeviceOnly` (and `synchronizable: false`,
  /// already the default) is what makes "never leaves the device" literally
  /// true: the item is ineligible for iCloud Keychain and is not restored
  /// onto a different device from a backup.
  ///
  /// Accessibility is part of the keychain add attributes, so changing it
  /// later can orphan items written under the old value. No migration is
  /// needed for this first iOS release — no iOS install has ever existed.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage;

  /// Pre-multi-login keys. Read once by [adoptLegacyCredential], then
  /// deleted; nothing else may write them.
  static const _legacyCookieKey = 'hoyolab_cookie';
  static const _legacyUidKey = 'hoyolab_uid';

  static String _cookieKey(String profileId) => 'hoyolab_cookie_$profileId';
  static String _uidKey(String profileId) => 'hoyolab_uid_$profileId';

  @override
  Future<void> save({
    required String profileId,
    required String cookie,
    required String uid,
  }) async {
    await _storage.write(key: _cookieKey(profileId), value: cookie);
    await _storage.write(key: _uidKey(profileId), value: uid);
  }

  @override
  Future<({String cookie, String uid})?> read(String profileId) async {
    final cookie = await _storage.read(key: _cookieKey(profileId));
    final uid = await _storage.read(key: _uidKey(profileId));
    if (cookie == null || uid == null) return null;
    return (cookie: cookie, uid: uid);
  }

  @override
  Future<void> clear(String profileId) async {
    await _storage.delete(key: _cookieKey(profileId));
    await _storage.delete(key: _uidKey(profileId));
  }

  @override
  Future<void> adoptLegacyCredential(String profileId) async {
    final cookie = await _storage.read(key: _legacyCookieKey);
    final uid = await _storage.read(key: _legacyUidKey);
    if (cookie == null || uid == null) {
      // Nothing to adopt, but a half-written legacy pair should still not
      // linger in the keystore.
      await _deleteLegacy();
      return;
    }
    // Never clobber a credential the user has already connected for this
    // profile under the new keys.
    if (await read(profileId) == null) {
      await save(profileId: profileId, cookie: cookie, uid: uid);
    }
    await _deleteLegacy();
  }

  Future<void> _deleteLegacy() async {
    await _storage.delete(key: _legacyCookieKey);
    await _storage.delete(key: _legacyUidKey);
  }
}
