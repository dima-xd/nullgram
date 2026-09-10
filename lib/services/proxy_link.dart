/// Parsing of the `t.me/proxy` and `t.me/socks` links Telegram shares.
///
/// Kept apart from the settings page so the parsing can be tested without a
/// widget tree, and so the same code can serve a future deep-link handler.
library;

/// A proxy described by a shared link.
typedef ProxyLink = ({
  String server,
  int port,
  /// A `proxyType*` map ready to hand to `TDLibClient.addProxy`.
  Map<String, dynamic> type,
});

/// Reads a proxy out of [link], or returns null when it is not a proxy link.
///
/// Accepts both the `https://t.me/...` and `tg://...` spellings of the two
/// shapes Telegram publishes:
///
/// ```text
/// https://t.me/proxy?server=1.2.3.4&port=443&secret=ee00
/// tg://socks?server=1.2.3.4&port=1080&user=me&pass=secret
/// ```
ProxyLink? parseProxyLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return null;

  final kind = _proxyKind(uri);
  if (kind == null) return null;

  final server = uri.queryParameters['server']?.trim() ?? '';
  final port = int.tryParse(uri.queryParameters['port'] ?? '');
  if (server.isEmpty || port == null || port <= 0 || port > 65535) return null;

  final type = switch (kind) {
    _ProxyKind.mtproto => _mtprotoType(uri),
    _ProxyKind.socks5 => _socks5Type(uri),
  };
  if (type == null) return null;

  return (server: server, port: port, type: type);
}

enum _ProxyKind { mtproto, socks5 }

/// Which shape [uri] is, if any.
///
/// The path carries the kind on `t.me` links and the host carries it on
/// `tg://` ones, so both places are checked.
_ProxyKind? _proxyKind(Uri uri) {
  final segments = uri.pathSegments;
  final name = uri.scheme == 'tg'
      ? uri.host
      : (segments.isEmpty ? '' : segments.last);
  if (uri.scheme != 'tg' && !_isTelegramHost(uri.host)) return null;

  return switch (name.toLowerCase()) {
    'proxy' => _ProxyKind.mtproto,
    'socks' => _ProxyKind.socks5,
    _ => null,
  };
}

bool _isTelegramHost(String host) => const {
  't.me',
  'telegram.me',
  'telegram.dog',
}.contains(host.toLowerCase());

/// An MTProto type, which is worthless without its secret.
Map<String, dynamic>? _mtprotoType(Uri uri) {
  final secret = uri.queryParameters['secret']?.trim() ?? '';
  if (secret.isEmpty) return null;
  return {"@type": "proxyTypeMtproto", "secret": secret};
}

/// A SOCKS5 type; credentials are optional, so an empty pair is still valid.
Map<String, dynamic> _socks5Type(Uri uri) => {
  "@type": "proxyTypeSocks5",
  "username": uri.queryParameters['user'] ?? '',
  "password": uri.queryParameters['pass'] ?? '',
};
