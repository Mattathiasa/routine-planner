import 'package:flutter/widgets.dart';

/// Captures a HoYoLab session cookie by having the user log in through
/// HoYoLab's own web UI, instead of asking them to hunt it out of browser
/// DevTools. Returns the `Cookie` header value to send on future requests,
/// or `null` if the user backed out before logging in.
abstract class HoyolabWebLogin {
  /// Signs the in-app browser out of HoYoLab.
  ///
  /// Without this a second connect is impossible: the login page would see
  /// the first account's still-valid session, report "logged in"
  /// immediately, and hand back that same cookie — so every profile would
  /// end up pointing at one HoYoLab account. Callers run this before
  /// [captureCookie] so each connect starts from a real login.
  Future<void> clearSession();

  Future<String?> captureCookie(BuildContext context);
}
