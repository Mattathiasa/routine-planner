import 'dart:io' show Cookie;

/// Reads the platform cookie jar for a URL. Matches
/// `WebviewCookieManager.getCookies`.
typedef CookieReader = Future<List<Cookie>> Function(String? url);

/// Injected so tests never wait on a real delay — the same reasoning as
/// injecting `Clock` in the domain layer, applied to a retry interval
/// rather than to a clock read.
typedef Sleeper = Future<void> Function(Duration);

/// The cookies that only exist once a HoYoLab session really exists, so
/// their presence is the "login finished" signal. Typically `HttpOnly`,
/// which is why this reads the platform jar rather than in-page JavaScript.
const sessionCookieNames = {'ltoken_v2', 'ltuid_v2'};

bool hasSessionCookies(List<Cookie> cookies) {
  final names = cookies.map((cookie) => cookie.name).toSet();
  return sessionCookieNames.every(names.contains);
}

/// The *entire* jar for the domain as a request header, in jar order — not
/// just the two session cookies. A real browser sends everything, and the
/// API has been observed rejecting requests built from only
/// `ltoken_v2`/`ltuid_v2` (likely wanting one of the other login-time
/// cookies such as `account_id_v2`/`cookie_token_v2`).
String toCookieHeader(List<Cookie> cookies) =>
    cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

bool _never() => false;

/// Polls [read] until the session cookies land, returning the cookie header,
/// or null if the budget ran out or [isCancelled] went true.
///
/// iOS needs this: `WKHTTPCookieStore` is populated asynchronously and can
/// lag `onPageFinished`, so a single read per page load can miss cookies
/// that arrive milliseconds later. Android's `CookieManager` is synchronous
/// enough that the first attempt almost always wins — which is why attempt
/// one happens with no leading delay, leaving the Android path exactly as
/// fast as it was before.
///
/// The budget is deliberately short relative to HoYoLab's login redirects:
/// the caller drops page-finish events while a poll is in flight, so a long
/// budget would swallow the page load that actually matters.
///
/// Never throws. A failed read is just a failed attempt — platform channels
/// can fail transiently mid-navigation.
Future<String?> pollForSessionCookie({
  required CookieReader read,
  required String url,
  required Sleeper sleep,
  bool Function() isCancelled = _never,
  int attempts = 10,
  Duration interval = const Duration(milliseconds: 200),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (isCancelled()) return null;
    if (attempt > 0) {
      await sleep(interval);
      if (isCancelled()) return null;
    }
    try {
      final cookies = await read(url);
      if (hasSessionCookies(cookies)) return toCookieHeader(cookies);
    } catch (_) {
      // Transient platform-channel failure; try again within the budget.
    }
  }
  return null;
}
