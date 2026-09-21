import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/settings/two_step_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/pages/settings/passcode_page.dart';
import 'package:nullgram/pages/settings/privacy_rules.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Privacy and security: the per-setting rules and the blocked senders.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _blocked =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _blocked.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  /// Loads the blocked senders and resolves the users behind them, since the
  /// list only carries ids.
  Future<void> _load() async {
    final senders = await TDLibClient.getBlockedMessageSenders();
    final users = await Future.wait([
      for (final sender in senders)
        if (sender['@type'] == 'MessageSenderUser')
          TDLibClient.getUser(userId: sender['userId'] as int),
    ]);
    if (!mounted) return;
    _blocked.value = [
      for (final user in users)
        if (user != null) user,
    ];
    _isLoading.value = false;
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    await TDLibClient.setUserBlocked(
      userId: user['id'] as int,
      blocked: false,
    );
    if (!mounted) return;
    _blocked.value = [
      for (final blocked in _blocked.value)
        if (blocked['id'] != user['id']) blocked,
    ];
  }

  static String _displayName(Map<String, dynamic> user) => [
        user['firstName'],
        user['lastName'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.privacyAndSecurity)),
      // A single scroll view rather than one list per section, so the
      // two-step row stays reachable even when nobody is blocked.
      body: ListView(
        padding: withBottomSafeArea(context),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(context.l10n.passcodeLock),
            subtitle: Text(context.l10n.passcodeSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PasscodePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(context.l10n.twoStepVerification),
            subtitle: Text(context.l10n.twoStepSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TwoStepPage()),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              context.l10n.privacy,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final rule in privacyRules()) PrivacyRuleTile(rule: rule),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              context.l10n.blockedUsers,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) {
              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _blocked,
                builder: (context, blocked, child) {
                  if (blocked.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Text(
                        context.l10n.nobodyBlocked,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final user in blocked)
                        _BlockedUserTile(
                          user: user,
                          name: _displayName(user),
                          onUnblock: () => _unblock(user),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One row of the blocked-users list.
class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.name,
    required this.onUnblock,
  });

  final Map<String, dynamic> user;
  final String name;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ChatAvatar(
        chat: {
          'id': user['id'],
          'title': name,
          'photo': user['profilePhoto'],
        },
        radius: 22,
      ),
      title: Text(name),
      subtitle:
          user['phoneNumber'] != null ? Text('+${user['phoneNumber']}') : null,
      trailing: TextButton(
        onPressed: onUnblock,
        child: Text(context.l10n.unblock),
      ),
    );
  }
}
