import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// The devices signed in to this account, with the option to sign others out.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _sessions =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sessions.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = await TDLibClient.getActiveSessions();
    if (!mounted) return;
    // This device first, then the rest by how recently they were used.
    _sessions.value = [...sessions]..sort((a, b) {
        if (a['isCurrent'] != b['isCurrent']) {
          return a['isCurrent'] == true ? -1 : 1;
        }
        return (b['lastActiveDate'] as int? ?? 0)
            .compareTo(a['lastActiveDate'] as int? ?? 0);
      });
    _isLoading.value = false;
  }

  Future<void> _terminate(Map<String, dynamic> session) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign this device out?'),
        content: Text(
          '${session['deviceModel']} will lose access to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await TDLibClient.terminateSession(sessionId: session['id'] as int);
    if (!mounted) return;
    _sessions.value = [
      for (final other in _sessions.value)
        if (other['id'] != session['id']) other,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _sessions,
            builder: (context, sessions, child) => RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: withBottomSafeArea(context),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isCurrent = session['isCurrent'] == true;
                  return ListTile(
                    leading: Icon(
                      isCurrent
                          ? Icons.phone_android
                          : Icons.devices_other_outlined,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      '${session['applicationName'] ?? 'App'} '
                      '${session['applicationVersion'] ?? ''}'.trim(),
                    ),
                    subtitle: Text(_details(session, isCurrent)),
                    trailing: isCurrent
                        ? const Text('This device')
                        : IconButton(
                            icon: const Icon(Icons.logout),
                            tooltip: 'Sign out',
                            onPressed: () => _terminate(session),
                          ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _details(Map<String, dynamic> session, bool isCurrent) {
    final parts = <String>[
      [
        session['deviceModel'],
        session['platform'],
        session['systemVersion'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
      if ((session['location'] as String?)?.isNotEmpty == true)
        session['location'] as String,
      if (!isCurrent && session['lastActiveDate'] != null)
        'Last active ${MessageFormatter.formatDateSeparator(
          session['lastActiveDate'] as int,
        )}',
    ];
    return parts.where((part) => part.isNotEmpty).join('\n');
  }
}
