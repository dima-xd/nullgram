import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/create_chat_page.dart';
import 'package:nullgram/pages/contacts/contacts_page.dart';
import 'package:nullgram/pages/search/search_page.dart';

/// The compose menu behind the chat list's floating action button.
Future<void> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Entry(
            icon: Icons.group_outlined,
            label: 'New group',
            page: () => const CreateChatPage(kind: NewChatKind.group),
          ),
          _Entry(
            icon: Icons.campaign_outlined,
            label: 'New channel',
            page: () => const CreateChatPage(kind: NewChatKind.channel),
          ),
          _Entry(
            icon: Icons.contacts_outlined,
            label: 'Contacts',
            page: () => const ContactsPage(),
          ),
          _Entry(
            icon: Icons.search,
            label: 'Find people and groups',
            page: () => const SearchPage(),
          ),
        ],
      ),
    ),
  );
}

/// One compose option: closes the sheet, then pushes its page.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.label,
    required this.page,
  });

  final IconData icon;
  final String label;
  final Widget Function() page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page()),
        );
      },
    );
  }
}
