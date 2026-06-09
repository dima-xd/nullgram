import 'package:flutter/material.dart';
import 'package:nullgram/pages/profile/widgets/profile_header_sliver.dart';
import 'package:nullgram/pages/profile/widgets/profile_info_tile.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// The current user's own profile: avatar, name, username, phone and bio.
///
/// Name, username and bio are editable inline — tapping a tile opens a bottom
/// sheet that writes the change back to TDLib and refreshes the view.
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

  /// A chat-shaped map so the avatar can render the profile photo or initial.
  Map<String, dynamic> _avatarChat(Map<String, dynamic> me) => {
        'id': me['id'],
        'title': _fullName(me),
        'photo': me['profilePhoto'],
        'user': me,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _me,
        builder: (context, me, child) {
          if (me == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final phone = me['phoneNumber'] as String?;
          final username = _username(me);
          final phoneValue = (phone != null && phone.isNotEmpty)
              ? (phone.startsWith('+') ? phone : '+$phone')
              : null;

          return CustomScrollView(
            slivers: [
              ProfileHeaderSliver(
                chat: _avatarChat(me),
                title: _fullName(me),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: Column(
                        children: [
                          ProfileInfoTile(
                            icon: Icons.person_outline,
                            label: 'Name',
                            value: _fullName(me),
                            editable: true,
                            onTap: () => _editName(me),
                          ),
                          ValueListenableBuilder<Map<String, dynamic>?>(
                            valueListenable: _fullInfo,
                            builder: (context, info, child) {
                              final bio =
                                  info?['bio']?['text'] as String? ?? '';
                              return ProfileInfoTile(
                                icon: Icons.info_outline,
                                label: 'Bio',
                                value: bio.isNotEmpty ? bio : 'Not set',
                                editable: true,
                                onTap: () => _editBio(bio),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Card(
                      child: Column(
                        children: [
                          ProfileInfoTile(
                            icon: Icons.alternate_email,
                            label: 'Username',
                            value: username != null ? '@$username' : 'Not set',
                            editable: true,
                            onTap: () => _editUsername(username),
                          ),
                          if (phoneValue != null)
                            ProfileInfoTile(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: phoneValue,
                              copyable: true,
                            ),
                        ],
                      ),
                    ),
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

  Future<void> _editName(Map<String, dynamic> me) async {
    final result = await showModalBottomSheet<_NameResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NameEditSheet(
        firstName: me['firstName'] as String? ?? '',
        lastName: me['lastName'] as String? ?? '',
      ),
    );
    if (result == null) return;
    await _run(() => TDLibClient.setName(
          firstName: result.firstName,
          lastName: result.lastName,
        ));
  }

  Future<void> _editUsername(String? current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SingleFieldEditSheet(
        title: 'Edit username',
        label: 'Username',
        icon: Icons.alternate_email,
        initialValue: _stripAt(current ?? ''),
      ),
    );
    if (result == null) return;
    await _run(() => TDLibClient.setUsername(username: _stripAt(result)));
  }

  Future<void> _editBio(String current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SingleFieldEditSheet(
        title: 'Edit bio',
        label: 'Bio',
        icon: Icons.info_outline,
        initialValue: current,
        maxLines: 3,
        maxLength: 70,
        allowEmpty: true,
      ),
    );
    if (result == null) return;
    await _run(() => TDLibClient.setBio(bio: result));
  }

  /// Removes a single leading '@' from a username, if present.
  String _stripAt(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

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

/// The first/last name pair returned by [_NameEditSheet].
class _NameResult {
  final String firstName;
  final String lastName;

  const _NameResult(this.firstName, this.lastName);
}

/// A bottom sheet for editing first and last name.
///
/// The Save button stays disabled until the first name is non-empty.
class _NameEditSheet extends StatefulWidget {
  final String firstName;
  final String lastName;

  const _NameEditSheet({required this.firstName, required this.lastName});

  @override
  State<_NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<_NameEditSheet> {
  late final TextEditingController _first =
      TextEditingController(text: widget.firstName);
  late final TextEditingController _last =
      TextEditingController(text: widget.lastName);

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _submit() {
    final first = _first.text.trim();
    if (first.isEmpty) return;
    Navigator.of(context).pop(_NameResult(first, _last.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: 'Edit name',
      children: [
        TextField(
          controller: _first,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'First name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _last,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Last name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 20),
        _SaveButton(
          enabled: _first.text.trim().isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// A bottom sheet for editing a single text field (username or bio).
class _SingleFieldEditSheet extends StatefulWidget {
  final String title;
  final String label;
  final IconData icon;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final bool allowEmpty;

  const _SingleFieldEditSheet({
    required this.title,
    required this.label,
    required this.icon,
    required this.initialValue,
    this.maxLines = 1,
    this.maxLength,
    this.allowEmpty = false,
  });

  @override
  State<_SingleFieldEditSheet> createState() => _SingleFieldEditSheetState();
}

class _SingleFieldEditSheetState extends State<_SingleFieldEditSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave =>
      widget.allowEmpty || _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSave) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return _EditSheetScaffold(
      title: widget.title,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textInputAction: widget.maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: widget.maxLines > 1 ? null : (_) => _submit(),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
          ),
        ),
        const SizedBox(height: 20),
        _SaveButton(enabled: _canSave, onPressed: _submit),
      ],
    );
  }
}

/// Shared chrome for an edit bottom sheet: title and insets that lift the
/// content above the keyboard.
class _EditSheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditSheetScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// A full-width primary Save button shared by the edit sheets.
class _SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SaveButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      child: const Text('Save'),
    );
  }
}
