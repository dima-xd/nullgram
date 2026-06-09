import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/profile/my_profile_page.dart';
import 'package:nullgram/pages/settings/settings_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

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

  void _openMyProfile() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyProfilePage()),
    );
  }

  Future<void> _openSavedMessages() async {
    final me = _me.value;
    final myId = me?['id'] as int?;
    if (myId == null) return;
    final chat = await TDLibClient.createPrivateChat(userId: myId);
    if (!mounted || chat == null) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }

  /// Items not yet wired to a backend flow: tell the user instead of silently
  /// closing the drawer (a dead-end tap).
  void _comingSoon(String label) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }

  void _openSettings() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
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
                  onTap: me == null ? null : _openMyProfile,
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
                            child: Icon(Icons.person,
                                size: 32,
                                color: theme.colorScheme.onSurfaceVariant),
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
              onTap: _openMyProfile,
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Saved Messages'),
              onTap: _openSavedMessages,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('New Group'),
              onTap: () => _comingSoon('New Group'),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('New Channel'),
              onTap: () => _comingSoon('New Channel'),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Contacts'),
              onTap: () => _comingSoon('Contacts'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Calls'),
              onTap: () => _comingSoon('Calls'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: _openSettings,
            ),
          ],
        ),
      ),
    );
  }
}
