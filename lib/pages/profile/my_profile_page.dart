import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// The current user's own profile: avatar, name, username, phone and bio.
///
/// Name, username and bio are editable inline — tapping a tile opens a dialog
/// that writes the change back to TDLib and refreshes the view.
class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final ValueNotifier<Map<String, dynamic>?> _me = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _fullInfo = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final me = await TDLibClient.getMe();
    if (!mounted) return;
    _me.value = me;
    final id = me?['id'] as int?;
    if (id != null) {
      final info = await TDLibClient.getUserFullInfo(userId: id);
      if (mounted) _fullInfo.value = info;
    }
  }

  @override
  void dispose() {
    _me.dispose();
    _fullInfo.dispose();
    super.dispose();
  }

  String _fullName(Map<String, dynamic> me) =>
      '${me['firstName'] ?? ''} ${me['lastName'] ?? ''}'.trim();

  String? _username(Map<String, dynamic> me) {
    final active = me['usernames']?['activeUsernames'] as List?;
    if (active != null && active.isNotEmpty) return active.first as String?;
    return null;
  }

  /// A chat-shaped map so [ChatAvatar] can render the profile photo or initial.
  Map<String, dynamic> _avatarChat(Map<String, dynamic> me) => {
        'id': me['id'],
        'title': _fullName(me),
        'photo': me['profilePhoto'],
        'user': me,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _me,
        builder: (context, me, child) {
          if (me == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final phone = me['phoneNumber'] as String?;
          final username = _username(me);
          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(child: ChatAvatar(chat: _avatarChat(me), radius: 56)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _fullName(me),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              _EditableTile(
                icon: Icons.person_outline,
                label: 'Name',
                value: _fullName(me),
                onTap: () => _editName(me),
              ),
              _EditableTile(
                icon: Icons.alternate_email,
                label: 'Username',
                value: username != null ? '@$username' : 'Not set',
                onTap: () => _editUsername(username),
              ),
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _fullInfo,
                builder: (context, info, child) {
                  final bio = info?['bio']?['text'] as String? ?? '';
                  return _EditableTile(
                    icon: Icons.info_outline,
                    label: 'Bio',
                    value: bio.isNotEmpty ? bio : 'Not set',
                    onTap: () => _editBio(bio),
                  );
                },
              ),
              if (phone != null && phone.isNotEmpty)
                _InfoTile(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: phone.startsWith('+') ? phone : '+$phone',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editName(Map<String, dynamic> me) async {
    final first = TextEditingController(text: me['firstName'] as String? ?? '');
    final last = TextEditingController(text: me['lastName'] as String? ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              decoration: const InputDecoration(labelText: 'First name'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: last,
              decoration: const InputDecoration(labelText: 'Last name'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: _dialogActions(context),
      ),
    );
    if (saved != true) return;
    final firstName = first.text.trim();
    if (firstName.isEmpty) {
      _showError('First name cannot be empty');
      return;
    }
    await _run(() => TDLibClient.setName(
          firstName: firstName,
          lastName: last.text.trim(),
        ));
  }

  Future<void> _editUsername(String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final saved = await _singleFieldDialog(
      title: 'Edit username',
      label: 'Username',
      controller: controller,
    );
    if (saved != true) return;
    await _run(
        () => TDLibClient.setUsername(username: controller.text.trim()));
  }

  Future<void> _editBio(String current) async {
    final controller = TextEditingController(text: current);
    final saved = await _singleFieldDialog(
      title: 'Edit bio',
      label: 'Bio',
      controller: controller,
      maxLines: 3,
    );
    if (saved != true) return;
    await _run(() => TDLibClient.setBio(bio: controller.text.trim()));
  }

  Future<bool?> _singleFieldDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
        actions: _dialogActions(context),
      ),
    );
  }

  List<Widget> _dialogActions(BuildContext context) => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ];

  /// Runs an edit [action], then refreshes the profile, surfacing failures.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      _showError('Could not save changes');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditableTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: onTap,
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
