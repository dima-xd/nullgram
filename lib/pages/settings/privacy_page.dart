import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';

/// Privacy and security: the blocked-senders list.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and security')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _blocked,
            builder: (context, blocked, child) {
              if (blocked.isEmpty) {
                return const EmptyState(
                  icon: Icons.lock_open,
                  title: 'Nobody is blocked',
                  subtitle:
                      'Blocked users cannot message you or see when you are '
                      'online.',
                );
              }
              return ListView.separated(
                itemCount: blocked.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Blocked users',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    );
                  }
                  final user = blocked[index - 1];
                  final name = _displayName(user);
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
                    subtitle: user['phoneNumber'] != null
                        ? Text('+${user['phoneNumber']}')
                        : null,
                    trailing: TextButton(
                      onPressed: () => _unblock(user),
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
