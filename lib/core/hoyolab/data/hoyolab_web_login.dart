import 'package:flutter/widgets.dart';

/// Captures a HoYoLab session cookie by having the user log in through
/// HoYoLab's own web UI, instead of asking them to hunt it out of browser
/// DevTools. Returns the `Cookie` header value to send on future requests,
/// or `null` if the user backed out before logging in.
abstract class HoyolabWebLogin {
  Future<String?> captureCookie(BuildContext context);
}
