/// Parses the wish-history link the game hands out, into the pieces the
/// importer needs.
///
/// Pure Dart, no Flutter/Riverpod/Drift imports.
///
/// The link comes from the game itself (its wish-history webview), and it
/// carries a short-lived `authkey` — the only credential that can read a
/// player's wish history. No HoYoLab cookie can; see `docs/ARCHITECTURE.md`.
///
/// **The endpoint's host and path are taken from the pasted link, never
/// hardcoded.** The same API is served at more than one spelling depending on
/// region and client version (`hk4e-api-os.hoyoverse.com/event/gacha_info/api/
/// getGachaLog` and `public-operation-hk4e-sg.hoyoverse.com/gacha_info/api/
/// getGachaLog`), and the link always carries the right one for that account —
/// so reusing it costs nothing and survives an upstream move.
library;

/// Everything needed to call the wish-history endpoint, with the query
/// parameters that identify *which* history to read deliberately left out —
/// those are the client's business.
typedef GachaAuth = ({
  /// Scheme, host and path only. The client replaces the query wholesale.
  Uri baseUrl,
  String authkey,
  String authkeyVer,
  String signType,
});

/// Thrown when a pasted string isn't a usable wish-history link.
///
/// Carries the input so the UI can show what it got, in the shape of
/// `UnknownHoyolabUidException`.
class InvalidGachaUrlException implements Exception {
  const InvalidGachaUrlException(this.input, this.reason);

  final String input;
  final String reason;

  String get message => reason;

  @override
  String toString() => 'InvalidGachaUrlException: $reason';
}

/// Pulls [GachaAuth] out of a pasted wish-history link.
///
/// Tolerant on purpose, because the link is copied by hand from a game
/// webview: surrounding whitespace is trimmed, and the parameters are read
/// from the query *or* the URL fragment (the in-game link carries
/// `#/log?authkey=...` on some client versions, which [Uri] parses as a
/// fragment, not a query).
GachaAuth parseGachaUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const InvalidGachaUrlException('', 'Paste the wish history link.');
  }

  final Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    throw InvalidGachaUrlException(
      trimmed,
      "That doesn't look like a link. Copy the whole wish history URL.",
    );
  }

  if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw InvalidGachaUrlException(
      trimmed,
      'Copy the whole link, starting with https://.',
    );
  }

  final params = {..._fragmentParams(uri.fragment), ...uri.queryParameters};

  final authkey = params['authkey']?.trim();
  if (authkey == null || authkey.isEmpty) {
    throw InvalidGachaUrlException(
      trimmed,
      'That link has no authkey in it. Open wish history in the game and copy '
      'the link again.',
    );
  }

  return (
    baseUrl: _baseUrlOf(uri),
    authkey: authkey,
    authkeyVer: params['authkey_ver']?.trim().isNotEmpty == true
        ? params['authkey_ver']!.trim()
        : '1',
    signType: params['sign_type']?.trim().isNotEmpty == true
        ? params['sign_type']!.trim()
        : '2',
  );
}

/// Scheme + host + path, with the port kept only when it was explicit.
Uri _baseUrlOf(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  );
}

/// The in-game link often looks like `…/index.html?...#/log?authkey=…`, so the
/// parameters can sit after the `#`. Everything up to the first `?` inside the
/// fragment is a route, not a parameter.
Map<String, String> _fragmentParams(String fragment) {
  if (fragment.isEmpty) return const {};
  final start = fragment.indexOf('?');
  final query = start == -1 ? fragment : fragment.substring(start + 1);
  if (query.isEmpty || !query.contains('=')) return const {};
  try {
    return Uri.splitQueryString(query);
  } on FormatException {
    return const {};
  }
}
