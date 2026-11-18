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
  /// Mutable so one fake can stand in for logging into two different
  /// HoYoLab accounts in sequence.
  String? cookie;

  /// Every call this fake saw, in order — lets a test assert that the
  /// session was cleared *before* the login was shown, which is the whole
  /// point of [clearSession].
  final calls = <String>[];

  bool get sessionCleared => calls.contains('clearSession');

  @override
  Future<void> clearSession() async {
    calls.add('clearSession');
  }

  @override
  Future<String?> captureCookie(BuildContext context) async {
    calls.add('captureCookie');
    return cookie;
  }
}
