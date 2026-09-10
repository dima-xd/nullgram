import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/services/proxy_link.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The proxies the account can route its connection through.
///
/// Telegram is blocked outright on some networks, so this is the difference
/// between a usable app and no app at all.
class ProxyPage extends StatefulWidget {
  const ProxyPage({super.key});

  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _proxies = ValueNotifier(
    const [],
  );

  /// Round-trip time per proxy id, in seconds; null means unreachable.
  ///
  /// A missing key means "not measured yet", which the row shows differently
  /// from a proxy that failed to answer.
  final ValueNotifier<Map<int, double?>> _pings = ValueNotifier(const {});

  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _proxies.dispose();
    _pings.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final proxies = await TDLibClient.getProxies();
    if (!mounted) return;
    _proxies.value = proxies;
    _isLoading.value = false;
    for (final proxy in proxies) {
      _ping(proxy['id'] as int);
    }
  }

  Future<void> _ping(int proxyId) async {
    final seconds = await TDLibClient.pingProxy(proxyId);
    if (!mounted) return;
    _pings.value = {..._pings.value, proxyId: seconds};
  }

  /// Whether any stored proxy is currently in use.
  bool get _isProxyEnabled =>
      _proxies.value.any((proxy) => proxy['isEnabled'] == true);

  Future<void> _toggleProxies(bool enable) async {
    if (!enable) {
      await TDLibClient.disableProxy();
    } else {
      final first = _proxies.value.firstOrNull;
      if (first == null) return;
      await TDLibClient.enableProxy(first['id'] as int);
    }
    await _load();
  }

  Future<void> _select(Map<String, dynamic> proxy) async {
    if (proxy['isEnabled'] == true) {
      await TDLibClient.disableProxy();
    } else {
      await TDLibClient.enableProxy(proxy['id'] as int);
    }
    await _load();
  }

  Future<void> _addOrEdit([Map<String, dynamic>? existing]) async {
    final draft = await showProxySheet(context, existing: existing);
    if (draft == null) return;

    if (existing == null) {
      await TDLibClient.addProxy(
        server: draft.server,
        port: draft.port,
        type: draft.type,
      );
    } else {
      await TDLibClient.editProxy(
        proxyId: existing['id'] as int,
        server: draft.server,
        port: draft.port,
        type: draft.type,
        enable: existing['isEnabled'] == true,
      );
    }
    await _load();
  }

  /// Reads a `t.me/proxy` link out of the clipboard and stores it.
  Future<void> _addFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final link = parseProxyLink(data?.text ?? '');
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.noProxyLinkInClipboard),
        ),
      );
      return;
    }
    await TDLibClient.addProxy(
      server: link.server,
      port: link.port,
      type: link.type,
    );
    await _load();
  }

  Future<void> _remove(Map<String, dynamic> proxy) async {
    await TDLibClient.removeProxy(proxy['id'] as int);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.proxy),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: context.l10n.addFromCopiedLink,
            onPressed: _addFromClipboard,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrEdit,
        tooltip: context.l10n.addProxy,
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: Listenable.merge([_proxies, _pings]),
            builder: (context, child) => _buildList(),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final proxies = _proxies.value;
    return ListView(
      padding: withBottomSafeArea(context, const EdgeInsets.only(bottom: 88)),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.vpn_key_outlined),
          title: Text(context.l10n.useAProxy),
          subtitle: Text(
            proxies.isEmpty
                ? 'Add a proxy first'
                : 'Route the connection through the selected server',
          ),
          value: _isProxyEnabled,
          onChanged: proxies.isEmpty ? null : _toggleProxies,
        ),
        const Divider(),
        if (proxies.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              context.l10n.noProxiesYet,
              textAlign: TextAlign.center,
            ),
          ),
        for (final proxy in proxies)
          _ProxyTile(
            proxy: proxy,
            ping: _pings.value[proxy['id'] as int],
            isMeasured: _pings.value.containsKey(proxy['id'] as int),
            onTap: () => _select(proxy),
            onEdit: () => _addOrEdit(proxy),
            onRemove: () => _remove(proxy),
            onRecheck: () => _ping(proxy['id'] as int),
          ),
      ],
    );
  }
}

/// One stored proxy, with its reachability and a menu of actions.
class _ProxyTile extends StatelessWidget {
  const _ProxyTile({
    required this.proxy,
    required this.ping,
    required this.isMeasured,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
    required this.onRecheck,
  });

  final Map<String, dynamic> proxy;
  final double? ping;
  final bool isMeasured;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = proxy['isEnabled'] == true;

    return ListTile(
      leading: Icon(
        isEnabled ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isEnabled ? scheme.primary : null,
      ),
      title: Text('${proxy['server']}:${proxy['port']}'),
      subtitle: Text(
        '${_typeLabel(proxy, context)} · ${_status(context)}',
      ),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (value) => switch (value) {
          'edit' => onEdit(),
          'recheck' => onRecheck(),
          _ => onRemove(),
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'recheck', child: Text(context.l10n.checkAgain)),
          PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
          PopupMenuItem(value: 'remove', child: Text(context.l10n.remove)),
        ],
      ),
    );
  }

  String _status(BuildContext context) {
    if (!isMeasured) return context.l10n.proxyChecking;
    if (ping == null) return context.l10n.proxyUnavailable;
    return context.l10n.pingMilliseconds((ping! * 1000).round());
  }

  static String _typeLabel(Map<String, dynamic> proxy, BuildContext context) {
    final type = proxy['type'] as Map<String, dynamic>?;
    return switch (type?['@type']) {
      'ProxyTypeMtproto' || 'proxyTypeMtproto' => 'MTProto',
      'ProxyTypeSocks5' || 'proxyTypeSocks5' => 'SOCKS5',
      'ProxyTypeHttp' || 'proxyTypeHttp' => 'HTTP',
      _ => 'Proxy',
    };
  }
}

/// What the add/edit sheet collected.
typedef ProxyDraft = ({String server, int port, Map<String, dynamic> type});

/// Collects a proxy's address and credentials, resolving to null on cancel.
Future<ProxyDraft?> showProxySheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) {
  return showModalBottomSheet<ProxyDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _ProxySheet(existing: existing),
  );
}

/// The kinds of proxy TDLib can connect through.
enum _ProxyKind {
  socks5('SOCKS5'),
  mtproto('MTProto'),
  http('HTTP');

  const _ProxyKind(this.label);

  final String label;

  /// The kind [proxy] already is, defaulting to SOCKS5 for a new entry.
  static _ProxyKind of(Map<String, dynamic>? proxy) {
    final type = (proxy?['type'] as Map<String, dynamic>?)?['@type'];
    return switch (type) {
      'ProxyTypeMtproto' || 'proxyTypeMtproto' => mtproto,
      'ProxyTypeHttp' || 'proxyTypeHttp' => http,
      _ => socks5,
    };
  }
}

class _ProxySheet extends StatefulWidget {
  const _ProxySheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_ProxySheet> createState() => _ProxySheetState();
}

class _ProxySheetState extends State<_ProxySheet> {
  late final Map<String, dynamic>? _type =
      widget.existing?['type'] as Map<String, dynamic>?;

  late final TextEditingController _server = TextEditingController(
    text: widget.existing?['server'] as String? ?? '',
  );
  late final TextEditingController _port = TextEditingController(
    text: widget.existing?['port']?.toString() ?? '',
  );
  late final TextEditingController _secret = TextEditingController(
    text: _type?['secret'] as String? ?? '',
  );
  late final TextEditingController _username = TextEditingController(
    text: _type?['username'] as String? ?? '',
  );
  late final TextEditingController _password = TextEditingController(
    text: _type?['password'] as String? ?? '',
  );

  late _ProxyKind _kind = _ProxyKind.of(widget.existing);

  @override
  void dispose() {
    _server.dispose();
    _port.dispose();
    _secret.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  int? get _parsedPort {
    final port = int.tryParse(_port.text.trim());
    if (port == null || port <= 0 || port > 65535) return null;
    return port;
  }

  bool get _isValid {
    if (_server.text.trim().isEmpty || _parsedPort == null) return false;
    // An MTProto proxy is identified by its secret, so it cannot be omitted.
    return _kind != _ProxyKind.mtproto || _secret.text.trim().isNotEmpty;
  }

  void _submit() {
    final type = switch (_kind) {
      _ProxyKind.mtproto => TDLibClient.mtprotoProxy(_secret.text.trim()),
      _ProxyKind.socks5 => TDLibClient.socks5Proxy(
        username: _username.text.trim(),
        password: _password.text,
      ),
      _ProxyKind.http => TDLibClient.httpProxy(
        username: _username.text.trim(),
        password: _password.text,
      ),
    };
    Navigator.pop(context, (
      server: _server.text.trim(),
      port: _parsedPort!,
      type: type,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetBottomPadding(context),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            widget.existing == null ? 'Add a proxy' : 'Edit proxy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SegmentedButton<_ProxyKind>(
            segments: [
              for (final kind in _ProxyKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) =>
                setState(() => _kind = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _server,
            autofocus: true,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.server,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.port,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_kind == _ProxyKind.mtproto)
            TextField(
              controller: _secret,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.secret,
                helperText: context.l10n.mtprotoSecretHint,
                border: OutlineInputBorder(),
              ),
            )
          else ...[
            TextField(
              controller: _username,
              decoration: InputDecoration(
                labelText: context.l10n.usernameOptional,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.passwordOptional,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isValid ? _submit : null,
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
