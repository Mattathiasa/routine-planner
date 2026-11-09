import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../hoyolab/data/hoyolab_client.dart';
import '../hoyolab/data/hoyolab_credentials_store.dart';
import '../hoyolab/data/hoyolab_web_login.dart';
import '../hoyolab/data/hoyolab_web_login_real.dart';

part 'hoyolab_providers.g.dart';

@Riverpod(keepAlive: true)
HoyolabClient hoyolabClient(Ref ref) => HoyolabClient();

@Riverpod(keepAlive: true)
HoyolabCredentialsStore hoyolabCredentialsStore(Ref ref) => SecureHoyolabCredentialsStore();

@Riverpod(keepAlive: true)
HoyolabWebLogin hoyolabWebLogin(Ref ref) => RealHoyolabWebLogin();

/// Whether a HoYoLab account is connected, and its saved UID — manually
/// invalidated after `save`/`clear`, same convention as every other
/// provider in this app (secure storage has no native "watch" mechanism
/// to hook a reactive provider to).
@riverpod
Future<({String cookie, String uid})?> hoyolabCredentials(Ref ref) {
  return ref.watch(hoyolabCredentialsStoreProvider).read();
}
