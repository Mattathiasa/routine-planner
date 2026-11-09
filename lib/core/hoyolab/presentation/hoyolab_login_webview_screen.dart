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
///
/// We send HoYoLab's *entire* cookie jar for the domain on every request,
/// not just `ltoken_v2`/`ltuid_v2` — a real browser does the same, and the
/// API has been observed rejecting requests built from only those two
/// (likely wanting one of the other login-time cookies too, such as
/// `account_id_v2`/`cookie_token_v2`). `ltoken_v2`/`ltuid_v2` are still
/// used as the "login finished" signal, since those are the ones that
/// only appear once the session actually exists.
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
      final loggedIn = byName['ltoken_v2'] != null && byName['ltuid_v2'] != null;
      if (loggedIn && mounted) {
        final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        Navigator.of(context).pop(cookieHeader);
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
