import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/forum_topics_page.dart';
import 'package:nullgram/services/chat_store.dart';

/// The route that opens [chat]: its history, or its topic list when the chat
/// is a forum supergroup, where messages only exist inside a topic.
Route<void> chatRoute(
  Map<String, dynamic> chat, {
  int? initialMessageId,
  String? initialText,
}) {
  // A chat handed over by search or a contact list carries only its `type`, so
  // the store is asked for the copy that has the supergroup merged in.
  final resolved = ChatStore.instance.chat(chat['id'] as int) ?? chat;

  if (initialMessageId == null && resolved['supergroup']?['isForum'] == true) {
    return MaterialPageRoute(builder: (_) => ForumTopicsPage(chat: resolved));
  }
  return MaterialPageRoute(
    builder: (_) => ChatPage(
      chat: resolved,
      initialMessageId: initialMessageId,
      initialText: initialText,
    ),
  );
}
