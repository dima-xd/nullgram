import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// A profile screen for a chat: large avatar, title, and details such as a
/// user's bio/phone or a supergroup's member count.
class ChatProfilePage extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatProfilePage({super.key, required this.chat});

  @override
  State<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends State<ChatProfilePage> {
  /// The resolved user object for private/secret chats, or null otherwise.
  final ValueNotifier<Map<String, dynamic>?> _user = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _userFullInfo =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    final userId = _chatUserId();
    if (userId != null) {
      // chat has no embedded user; resolve it (and its full info) from TDLib.
      TDLibClient.getUser(userId: userId).then((user) {
        if (mounted) _user.value = user;
      }).catchError((_) {});
      TDLibClient.getUserFullInfo(userId: userId).then((info) {
        if (mounted) _userFullInfo.value = info;
      }).catchError((_) {});
    }
  }

  /// The user id behind a private/secret chat, read from the chat's type.
  int? _chatUserId() {
    final type = widget.chat['type'];
    final typeName = type?['@type'];
    if (typeName == 'ChatTypePrivate' || typeName == 'ChatTypeSecret') {
      return type['userId'] as int?;
    }
    return null;
  }

  @override
  void dispose() {
    _user.dispose();
    _userFullInfo.dispose();
    super.dispose();
  }

  String? _subtitle(Map<String, dynamic>? user) {
    if (user != null) return MessageFormatter.getUserStatus(user);
    final supergroup = widget.chat['supergroup'];
    if (supergroup != null) {
      final count = supergroup['memberCount'] ?? 0;
      final label = supergroup['isChannel'] == true ? 'subscribers' : 'members';
      return '${NumberFormat('#,###', 'en_US').format(count)} $label';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _user,
        builder: (context, user, child) {
          final phone = user?['phoneNumber'] as String?;
          final activeUsernames =
              user?['usernames']?['activeUsernames'] as List?;
          final username =
              (activeUsernames != null && activeUsernames.isNotEmpty)
                  ? activeUsernames.first as String?
                  : null;
          final subtitle = _subtitle(user);

          final chatWithUser =
              user == null ? widget.chat : {...widget.chat, 'user': user};
          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(child: ChatAvatar(chat: chatWithUser, radius: 56)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  widget.chat['title'] ?? 'Chat',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _userFullInfo,
                builder: (context, fullInfo, child) {
                  final bio = fullInfo?['bio']?['text'] as String?;
                  return Column(
                    children: [
                      if (phone != null && phone.isNotEmpty)
                        _InfoTile(
                          icon: Icons.phone,
                          label: 'Phone',
                          value: phone.startsWith('+') ? phone : '+$phone',
                        ),
                      if (username != null && username.isNotEmpty)
                        _InfoTile(
                          icon: Icons.alternate_email,
                          label: 'Username',
                          value: '@$username',
                        ),
                      if (bio != null && bio.isNotEmpty)
                        _InfoTile(
                          icon: Icons.info_outline,
                          label: 'Bio',
                          value: bio,
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label),
    );
  }
}
