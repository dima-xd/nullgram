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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _me,
            builder: (context, me, child) {
              return InkWell(
                onTap: me == null ? null : _openMyProfile,
                child: DrawerHeader(
                  decoration: BoxDecoration(color: theme.colorScheme.primary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (me == null)
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 32),
                        )
                      else
                        ChatAvatar(chat: _avatarChat(me), radius: 32),
                      const SizedBox(height: 8),
                      Text(
                        me == null ? 'Nullgram' : _fullName(me),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            onTap: _openMyProfile,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('New Group'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('New Channel'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Contacts'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Calls'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Saved Messages'),
            onTap: _openSavedMessages,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
