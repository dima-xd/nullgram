import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/profile/widgets/profile_header_sliver.dart';
import 'package:nullgram/pages/profile/widgets/profile_info_tile.dart';
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
    return Scaffold(
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
          final title = widget.chat['title'] as String? ?? 'Chat';
          final subtitle = _subtitle(user);

          final chatWithUser =
              user == null ? widget.chat : {...widget.chat, 'user': user};

          final phoneValue = (phone != null && phone.isNotEmpty)
              ? (phone.startsWith('+') ? phone : '+$phone')
              : null;

          return CustomScrollView(
            slivers: [
              ProfileHeaderSliver(
                chat: chatWithUser,
                title: title,
                subtitle: subtitle,
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  if (phoneValue != null || username != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        child: Column(
                          children: [
                            if (phoneValue != null)
                              ProfileInfoTile(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: phoneValue,
                                copyable: true,
                              ),
                            if (username != null && username.isNotEmpty)
                              ProfileInfoTile(
                                icon: Icons.alternate_email,
                                label: 'Username',
                                value: '@$username',
                                copyable: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: _userFullInfo,
                    builder: (context, fullInfo, child) {
                      final bio = fullInfo?['bio']?['text'] as String?;
                      if (bio == null || bio.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Card(
                          child: ProfileInfoTile(
                            icon: Icons.info_outline,
                            label: 'Bio',
                            value: bio,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
