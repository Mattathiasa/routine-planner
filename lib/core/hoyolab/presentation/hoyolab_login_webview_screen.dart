import 'package:flutter/material.dart';
import 'package:webview_cookie_manager_flutter/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/hoyolab_cookie_capture.dart';

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
/// The check is a bounded poll rather than a single read: on iOS
/// `WKHTTPCookieStore` is populated asynchronously and can lag
/// `onPageFinished`, so the cookies sometimes land a moment after the page
/// reports done. Android's `CookieManager` is synchronous enough that the
/// first attempt wins, so the retry costs nothing there.
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
  State<HoyolabLoginWebviewScreen> createState() =>
      _HoyolabLoginWebviewScreenState();
}

class _HoyolabLoginWebviewScreenState extends State<HoyolabLoginWebviewScreen> {
  late final WebViewController _controller;
  bool _checkingCookies = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _checkLoggedIn()),
      )
      ..loadRequest(Uri.parse(_hoyolabHome));
  }

  Future<void> _checkLoggedIn() async {
    // One poll at a time. HoYoLab redirects several times during login, so
    // page-finish events overlap; the in-flight poll covers them.
    if (_checkingCookies || _disposed || !mounted) return;
    _checkingCookies = true;
    try {
      final cookieHeader = await pollForSessionCookie(
        read: WebviewCookieManager().getCookies,
        url: _hoyolabHome,
        sleep: Future<void>.delayed,
        isCancelled: () => _disposed || !mounted,
      );
      if (cookieHeader != null && mounted) {
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
