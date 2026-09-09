import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/chat_store.dart';

Map<String, dynamic> chatWith(List<Map<String, dynamic>> positions) => {
      'id': 1,
      'positions': positions,
    };

Map<String, dynamic> position(
  String listType, {
  int? folderId,
  bool isPinned = false,
  Object order = 1,
}) =>
    {
      'list': {
        '@type': listType,
        if (folderId != null) 'chatFolderId': folderId,
      },
      'isPinned': isPinned,
      'order': order,
    };

void main() {
  group('ChatStore.positionIn', () {
    test('finds the main-list position', () {
      final chat = chatWith([position('ChatListMain', isPinned: true)]);

      final found = ChatStore.positionIn(chat, ChatListKind.main);

      expect(found?['isPinned'], isTrue);
    });

    test('does not mistake an archived chat for a main-list one', () {
      // Both lists omit `chatFolderId`, so matching on that alone would put
      // archived chats back in the main list.
      final chat = chatWith([position('ChatListArchive')]);

      expect(ChatStore.positionIn(chat, ChatListKind.main), isNull);
      expect(ChatStore.positionIn(chat, ChatListKind.archive), isNotNull);
    });

    test('finds a folder position by its folder id', () {
      final chat = chatWith([
        position('ChatListMain'),
        position('ChatListFolder', folderId: 7, isPinned: true),
      ]);

      final found = ChatStore.positionIn(chat, ChatListKind.main, folderId: 7);

      expect(found?['isPinned'], isTrue);
    });

    test('returns null for a folder the chat is not in', () {
      final chat = chatWith([position('ChatListFolder', folderId: 7)]);

      expect(
        ChatStore.positionIn(chat, ChatListKind.main, folderId: 8),
        isNull,
      );
    });

    test('handles a chat with no positions at all', () {
      expect(ChatStore.positionIn({'id': 1}, ChatListKind.main), isNull);
    });
  });

  group('isChatMuted', () {
    test('is true while a mute duration is set', () {
      expect(
        isChatMuted({
          'notificationSettings': {'muteFor': 3600},
        }),
        isTrue,
      );
    });

    test('is false with no mute duration or no settings', () {
      expect(
        isChatMuted({
          'notificationSettings': {'muteFor': 0},
        }),
        isFalse,
      );
      expect(isChatMuted(const {}), isFalse);
    });
  });
}
