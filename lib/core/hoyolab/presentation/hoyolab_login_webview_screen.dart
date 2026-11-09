import 'package:flutter/material.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _hoyolabHome = 'https://www.hoyolab.com/home';

/// Renders HoYoLab's real login page in an embedded WebView — the user
/// logs in exactly as they would in a browser (we never see the password),
/// and after each page load we check whether the session cookies HoYoLab's
/// API needs have landed yet. `CookieManager`/`WKHTTPCookieStore` (what
/// [WebviewCookieManager] wraps) read cookies at the platform level, so
/// this sees `HttpOnly` cookies even though in-page JavaScript can't —
/// `ltoken_v2`/`ltuid_v2` are typically set `HttpOnly` for session-hijack
/// protection.
class HoyolabLoginWebviewScreen extends StatefulWidget {
  const HoyolabLoginWebviewScreen({super.key});

  @override
  State<HoyolabLoginWebviewScreen> createState() => _HoyolabLoginWebviewScreenState();
}

class _HoyolabLoginWebviewScreenState extends State<HoyolabLoginWebviewScreen> {
  late final WebViewController _controller;
  bool _checkingCookies = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _checkLoggedIn()))
      ..loadRequest(Uri.parse(_hoyolabHome));
  }

  Future<void> _checkLoggedIn() async {
    if (_checkingCookies || !mounted) return;
    _checkingCookies = true;
    try {
      final cookies = await WebviewCookieManager().getCookies(_hoyolabHome);
      final byName = {for (final cookie in cookies) cookie.name: cookie.value};
      final ltoken = byName['ltoken_v2'];
      final ltuid = byName['ltuid_v2'];
      if (ltoken != null && ltuid != null && mounted) {
        Navigator.of(context).pop('ltoken_v2=$ltoken; ltuid_v2=$ltuid');
      }
    } finally {
      _checkingCookies = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to HoYoLab'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
