import 'package:flutter/widgets.dart';

import 'hoyolab_web_login.dart';

/// A [HoyolabWebLogin] double for tests — same placement convention as
/// `fake_hoyolab_credentials_store.dart`. Avoids ever constructing a real
/// `WebViewWidget` under `flutter_test`, which has no platform-channel
/// implementation registered and would behave like the secure-storage
/// hang this session already hit once.
class FakeHoyolabWebLogin implements HoyolabWebLogin {
  FakeHoyolabWebLogin({this.cookie = 'ltoken_v2=fake; ltuid_v2=1'});

  /// The cookie string [captureCookie] resolves with. `null` simulates the
  /// user backing out of the login screen without completing login.
  final String? cookie;

  @override
  Future<String?> captureCookie(BuildContext context) async => cookie;
}
