import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_view.dart';
import 'package:nullgram/services/chat_store.dart';

/// The archived chat list.
///
/// Shares [ChatStore] with the main list, so archiving a chat from either
/// screen moves it immediately without a reload.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived chats')),
      body: ChatListView(
        kind: ChatListKind.archive,
        onChatTap: (chatId) {
          final chat = ChatStore.instance.chat(chatId);
          if (chat == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
          );
        },
      ),
    );
  }
}
