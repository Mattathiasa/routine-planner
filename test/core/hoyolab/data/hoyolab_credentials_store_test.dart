import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/hoyolab/data/fake_hoyolab_credentials_store.dart';

/// Covers the per-profile credential contract against the fake, which is
/// the only testable implementation — `SecureHoyolabCredentialsStore` sits
/// on `flutter_secure_storage`'s platform channel, which never resolves
/// under plain `flutter_test`. The two implementations are kept in step by
/// sharing the abstract interface.
void main() {
  group('per-profile keying', () {
    test('each profile has its own slot', () async {
      final store = FakeHoyolabCredentialsStore();

      await store.save(profileId: 'main', cookie: 'cookie-main', uid: '800000001');
      await store.save(profileId: 'alt', cookie: 'cookie-alt', uid: '700000002');

      expect((await store.read('main'))!.uid, '800000001');
      expect((await store.read('alt'))!.uid, '700000002');
    });

    test('an unconnected profile reads null even when another is connected', () async {
      final store = FakeHoyolabCredentialsStore();
      await store.save(profileId: 'main', cookie: 'c', uid: 'u');

      expect(await store.read('never-connected'), isNull);
    });

    test('clearing one profile leaves the others connected', () async {
      final store = FakeHoyolabCredentialsStore();
      await store.save(profileId: 'main', cookie: 'c1', uid: 'u1');
      await store.save(profileId: 'alt', cookie: 'c2', uid: 'u2');

      await store.clear('main');

      expect(await store.read('main'), isNull);
      expect((await store.read('alt'))!.uid, 'u2');
    });

    test('saving again replaces that profile only', () async {
      final store = FakeHoyolabCredentialsStore();
      await store.save(profileId: 'main', cookie: 'old', uid: 'u1');
      await store.save(profileId: 'alt', cookie: 'untouched', uid: 'u2');

      await store.save(profileId: 'main', cookie: 'new', uid: 'u1');

      expect((await store.read('main'))!.cookie, 'new');
      expect((await store.read('alt'))!.cookie, 'untouched');
    });
  });

  group('legacy credential adoption', () {
    test('moves a pre-multi-login credential onto the given profile', () async {
      final store = FakeHoyolabCredentialsStore(
        legacyCredential: (cookie: 'legacy-cookie', uid: '800000009'),
      );

      await store.adoptLegacyCredential('main');

      final adopted = await store.read('main');
      expect(adopted, isNotNull);
      expect(adopted!.cookie, 'legacy-cookie');
      expect(adopted.uid, '800000009');
    });

    test('is one-shot: a second profile does not inherit the same credential', () async {
      final store = FakeHoyolabCredentialsStore(
        legacyCredential: (cookie: 'legacy-cookie', uid: '800000009'),
      );

      await store.adoptLegacyCredential('main');
      await store.adoptLegacyCredential('alt');

      expect(await store.read('alt'), isNull);
    });

    test('repeated runs are idempotent', () async {
      final store = FakeHoyolabCredentialsStore(
        legacyCredential: (cookie: 'legacy-cookie', uid: '800000009'),
      );

      await store.adoptLegacyCredential('main');
      await store.adoptLegacyCredential('main');
      await store.adoptLegacyCredential('main');

      expect((await store.read('main'))!.cookie, 'legacy-cookie');
      expect(store.legacyCredential, isNull);
    });

    test('never clobbers a credential already connected for that profile', () async {
      final store = FakeHoyolabCredentialsStore(
        legacyCredential: (cookie: 'legacy-cookie', uid: '800000009'),
      );
      await store.save(profileId: 'main', cookie: 'freshly-connected', uid: '111');

      await store.adoptLegacyCredential('main');

      expect((await store.read('main'))!.cookie, 'freshly-connected');
    });

    test('does nothing when there is no legacy credential', () async {
      final store = FakeHoyolabCredentialsStore();

      await store.adoptLegacyCredential('main');

      expect(await store.read('main'), isNull);
    });
  });
}
