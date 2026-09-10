import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The account's contact list.
///
/// In [selectable] mode the page returns the chosen user ids instead of opening
/// chats, which is how group creation picks its members.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, this.selectable = false, this.title});

  final bool selectable;
  final String? title;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _contacts =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<Set<int>> _selected = ValueNotifier(const {});
  final TextEditingController _filterController = TextEditingController();
  final ValueNotifier<String> _filter = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _filterController.addListener(
      () => _filter.value = _filterController.text.trim().toLowerCase(),
    );
    _load();
  }

  @override
  void dispose() {
    _contacts.dispose();
    _isLoading.dispose();
    _selected.dispose();
    _filter.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userIds = await TDLibClient.getContacts();
    final users = await Future.wait(
      userIds.map((id) => TDLibClient.getUser(userId: id)),
    );
    if (!mounted) return;

    final resolved = [
      for (final user in users)
        if (user != null) user,
    ]..sort((a, b) => _displayName(a).compareTo(_displayName(b)));

    _contacts.value = resolved;
    _isLoading.value = false;
  }

  static String _displayName(Map<String, dynamic> user) => [
        user['firstName'],
        user['lastName'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

  void _toggle(int userId) {
    final selected = Set<int>.from(_selected.value);
    if (!selected.remove(userId)) selected.add(userId);
    _selected.value = selected;
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    final chat = await TDLibClient.createPrivateChat(
      userId: user['id'] as int,
    );
    if (!mounted || chat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Contacts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              controller: _filterController,
              hintText: context.l10n.searchContacts,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
        ),
      ),
      floatingActionButton: widget.selectable
          ? ValueListenableBuilder<Set<int>>(
              valueListenable: _selected,
              builder: (context, selected, child) => FloatingActionButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected.toList()),
                backgroundColor: selected.isEmpty
                    ? Theme.of(context).disabledColor
                    : null,
                child: const Icon(Icons.arrow_forward),
              ),
            )
          : null,
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _contacts,
            builder: (context, contacts, child) {
              if (contacts.isEmpty) {
                return EmptyState(
                  icon: Icons.contacts_outlined,
                  title: context.l10n.noContacts,
                  subtitle:
                      context.l10n.contactsEmpty,
                );
              }
              return ValueListenableBuilder<String>(
                valueListenable: _filter,
                builder: (context, filter, child) {
                  final visible = filter.isEmpty
                      ? contacts
                      : contacts
                          .where((user) => _displayName(user)
                              .toLowerCase()
                              .contains(filter))
                          .toList();
                  if (visible.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off,
                      title: context.l10n.noContactsFound,
                    );
                  }
                  return ValueListenableBuilder<Set<int>>(
                    valueListenable: _selected,
                    builder: (context, selected, child) => ListView.builder(
                      padding: withBottomSafeArea(
                        context,
                        // Room for the "next" button in selection mode.
                        EdgeInsets.only(bottom: widget.selectable ? 80 : 0),
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final user = visible[index];
                        final userId = user['id'] as int;
                        return _ContactTile(
                          user: user,
                          name: _displayName(user),
                          selectable: widget.selectable,
                          isSelected: selected.contains(userId),
                          onTap: () => widget.selectable
                              ? _toggle(userId)
                              : _openChat(user),
                        );
                      },
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.user,
    required this.name,
    required this.selectable,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final String name;
  final bool selectable;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ChatAvatar reads a chat-shaped map; a contact has no chat, so build the
    // minimum it needs from the user itself.
    final avatarChat = {
      'id': user['id'],
      'title': name,
      'photo': user['profilePhoto'],
      'user': user,
    };

    return ListTile(
      leading: ChatAvatar(chat: avatarChat, radius: 22),
      title: Text(name),
      subtitle: Text(MessageFormatter.getUserStatus(user)),
      trailing: selectable
          ? Checkbox(value: isSelected, onChanged: (_) => onTap())
          : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}
