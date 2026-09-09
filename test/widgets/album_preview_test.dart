import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/theme/app_theme.dart';

Map<String, dynamic> albumMember({
  required int id,
  String? caption,
  String type = 'MessagePhoto',
  int albumId = 42,
}) =>
    {
      'id': id,
      'date': 1750000000,
      'isOutgoing': false,
      'mediaAlbumId': albumId,
      'content': {
        '@type': type,
        if (caption != null)
          'caption': {'@type': 'FormattedText', 'text': caption},
      },
    };

Map<String, dynamic> chatWithAlbum(List<Map<String, dynamic>> members) => {
      'id': 7,
      'title': 'Abuchi',
      'type': {'@type': 'ChatTypeSupergroup', 'isChannel': true},
      'lastMessage': members.last,
      'lastMessageAlbum': members,
      'positions': const [],
    };

Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> chat) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(null),
      home: Scaffold(
        body: ChatListItem(chat: chat, onTap: (_) {}),
      ),
    ),
  );
}

void main() {
  group('album chat-list preview', () {
    testWidgets("shows the album's caption, not the last member's", (
      tester,
    ) async {
      // Only the first member of an album carries the caption, while
      // `lastMessage` is the last one — the case that used to render "Photo".
      final members = [
        albumMember(id: 1, caption: 'Вышло новое обновление!'),
        albumMember(id: 2),
        albumMember(id: 3),
      ];

      await pumpRow(tester, chatWithAlbum(members));

      expect(find.textContaining('Вышло новое обновление!'), findsOneWidget);
      expect(find.textContaining('Photo'), findsNothing);
    });

    testWidgets('counts the items when the album has no caption', (
      tester,
    ) async {
      final members = [
        albumMember(id: 1),
        albumMember(id: 2),
        albumMember(id: 3),
      ];

      await pumpRow(tester, chatWithAlbum(members));

      expect(find.textContaining('3 photos'), findsOneWidget);
    });

    testWidgets('names a mixed album generically', (tester) async {
      final members = [
        albumMember(id: 1),
        albumMember(id: 2, type: 'MessageVideo'),
      ];

      await pumpRow(tester, chatWithAlbum(members));

      expect(find.textContaining('2 items'), findsOneWidget);
    });

    testWidgets('falls back to "Album" before the album is resolved', (
      tester,
    ) async {
      // Resolution is asynchronous, so the row is built once with only
      // `lastMessage` available.
      final chat = {
        'id': 7,
        'title': 'Abuchi',
        'type': {'@type': 'ChatTypeSupergroup', 'isChannel': true},
        'lastMessage': albumMember(id: 3),
        'positions': const [],
      };

      await pumpRow(tester, chat);

      expect(find.textContaining('Album'), findsOneWidget);
    });
  });

  group('messagePreviewText', () {
    test('describes an uncaptioned album member as an album', () {
      expect(messagePreviewText(albumMember(id: 1)), 'Album');
    });

    test('prefers a caption over the album label', () {
      expect(
        messagePreviewText(albumMember(id: 1, caption: 'Look at this')),
        'Look at this',
      );
    });

    test('still describes a lone photo as a photo', () {
      expect(messagePreviewText(albumMember(id: 1, albumId: 0)), 'Photo');
    });
  });

  group('ChatStore.albumIdOf', () {
    test('treats zero and a missing field as "no album"', () {
      expect(ChatStore.albumIdOf({'mediaAlbumId': 0}), isNull);
      expect(ChatStore.albumIdOf(const {}), isNull);
      expect(ChatStore.albumIdOf(null), isNull);
    });

    test('returns the album id when set', () {
      expect(ChatStore.albumIdOf({'mediaAlbumId': 42}), 42);
    });
  });
}
