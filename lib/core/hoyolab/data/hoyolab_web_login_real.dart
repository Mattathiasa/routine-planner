import 'package:flutter/material.dart';

import '../presentation/hoyolab_login_webview_screen.dart';
import 'hoyolab_web_login.dart';

class RealHoyolabWebLogin implements HoyolabWebLogin {
  @override
  Future<String?> captureCookie(BuildContext context) {
    return Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const HoyolabLoginWebviewScreen()));
  }
}
