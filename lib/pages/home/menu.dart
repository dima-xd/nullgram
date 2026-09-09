import 'package:flutter/material.dart';
import 'package:nullgram/pages/calls/calls_page.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/create_chat_page.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/contacts/contacts_page.dart';
import 'package:nullgram/pages/home/archive_page.dart';
import 'package:nullgram/pages/profile/my_profile_page.dart';
import 'package:nullgram/pages/settings/settings_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// The chat list's navigation drawer.
class HomeMenu extends StatefulWidget {
  const HomeMenu({super.key});

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  final ValueNotifier<Map<String, dynamic>?> _me = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    TDLibClient.getMe().then((me) {
      if (mounted) _me.value = me;
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _me.dispose();
    super.dispose();
  }

  String _fullName(Map<String, dynamic> me) =>
      '${me['firstName'] ?? ''} ${me['lastName'] ?? ''}'.trim();

  Map<String, dynamic> _avatarChat(Map<String, dynamic> me) => {
        'id': me['id'],
        'title': _fullName(me),
        'photo': me['profilePhoto'],
        'user': me,
      };

  /// Closes the drawer, then pushes [page]. Popping the pushed route lands back
  /// on the chat list rather than reopening the drawer.
  void _open(Widget Function() page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page()),
    );
  }

  Future<void> _openSavedMessages() async {
    final myId = _me.value?['id'] as int?;
    if (myId == null) return;
    final chat = await TDLibClient.createPrivateChat(userId: myId);
    if (!mounted || chat == null) return;
    _open(() => ChatPage(chat: chat));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: _me,
              builder: (context, me, child) {
                return InkWell(
                  onTap: me == null
                      ? null
                      : () => _open(() => const MyProfilePage()),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (me == null)
                          CircleAvatar(
                            radius: 32,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          ChatAvatar(chat: _avatarChat(me), radius: 32),
                        const SizedBox(height: 12),
                        Text(
                          me == null ? 'Nullgram' : _fullName(me),
                          style: theme.textTheme.titleLarge,
                        ),
                        if (me?['phoneNumber'] != null)
                          Text(
                            '+${me!['phoneNumber']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () => _open(() => const MyProfilePage()),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Saved Messages'),
              onTap: _openSavedMessages,
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived Chats'),
              onTap: () => _open(() => const ArchivePage()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('New Group'),
              onTap: () =>
                  _open(() => const CreateChatPage(kind: NewChatKind.group)),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('New Channel'),
              onTap: () =>
                  _open(() => const CreateChatPage(kind: NewChatKind.channel)),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Contacts'),
              onTap: () => _open(() => const ContactsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Calls'),
              onTap: () => _open(() => const CallsPage()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _open(() => const SettingsPage()),
            ),
          ],
        ),
      ),
    );
  }
}
