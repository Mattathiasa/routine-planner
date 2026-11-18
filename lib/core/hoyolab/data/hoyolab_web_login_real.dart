import 'package:flutter/material.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';

import '../presentation/hoyolab_login_webview_screen.dart';
import 'hoyolab_web_login.dart';

class RealHoyolabWebLogin implements HoyolabWebLogin {
  @override
  Future<void> clearSession() {
    // Clears the WebView's whole cookie jar. The app only ever loads
    // HoYoLab in this WebView, so there is nothing else to lose.
    return WebviewCookieManager().clearCookies();
  }

  @override
  Future<String?> captureCookie(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const HoyolabLoginWebviewScreen()),
    );
  }
}
