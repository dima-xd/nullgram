import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/message_history.dart';

Map<String, dynamic> message(
  int id, {
  int chatId = 10,
  int threadId = 0,
  int albumId = 0,
  int date = 100,
  bool isOutgoing = false,
}) =>
    {
      'id': id,
      'chatId': chatId,
      'messageThreadId': threadId,
      'mediaAlbumId': albumId,
      'date': date,
      'isOutgoing': isOutgoing,
      'content': {'@type': 'MessagePhoto'},
    };

/// A source that hands back pre-baked pages, so paging behaviour is tested
/// without the TDLib bridge.
class FakeSource implements HistorySource {
  FakeSource(this.pages, {this.chatId = 10, this.threadId = 0});

  /// Pages handed out in order, one per [load] call.
  final List<List<Map<String, dynamic>>> pages;

  @override
  final int chatId;

  final int threadId;

  int loadCount = 0;
  final List<int> requestedFrom = [];

  @override
  Future<List<Map<String, dynamic>>> load({
    required int fromMessageId,
    required int offset,
    required int limit,
    required bool onlyLocal,
  }) async {
    requestedFrom.add(fromMessageId);
    if (loadCount >= pages.length) return const [];
    return pages[loadCount++];
  }

  @override
  bool owns(Map<String, dynamic> other) =>
      other['chatId'] == chatId && other['messageThreadId'] == threadId;
}

void main() {
  group('loadLocal', () {
    test('keeps paging while the source still returns messages', () async {
      final source = FakeSource([
        [message(5), message(4)],
        [message(3)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);

      await history.loadLocal();

      expect(history.messages.map((m) => m['id']), [5, 4, 3]);
      expect(source.loadCount, 3);
    });

    test('pages from the oldest message it already holds', () async {
      final source = FakeSource([
        [message(5), message(4)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);

      await history.loadLocal();

      expect(source.requestedFrom, [0, 4]);
    });
  });

  group('loadMore', () {
    test('stops asking once the source is empty', () async {
      final source = FakeSource([const []]);
      final history = MessageHistoryController(source: source);

      await history.loadMore();

      expect(history.hasMore, isFalse);

      await history.loadMore();

      expect(source.loadCount, 1);
    });
  });

  group('album grouping', () {
    test('folds members sharing an album id into one entry', () async {
      final source = FakeSource([
        [message(5, albumId: 7), message(4, albumId: 7)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);

      await history.loadLocal();

      expect(history.messages.length, 1);
      expect(history.messages.single['isAlbum'], isTrue);
    });
  });

  group('applyUpdate', () {
    test('adds a new message at the front and reports it', () async {
      final history = MessageHistoryController(
        source: FakeSource([
          [message(4)],
          const [],
        ]),
      );
      await history.loadLocal();

      final added = history.applyUpdate({
        '@type': 'UpdateNewMessage',
        'message': message(5),
      });

      expect(added?['id'], 5);
      expect(history.messages.first['id'], 5);
    });

    test('ignores a message from another chat', () async {
      final history = MessageHistoryController(source: FakeSource(const []));

      final added = history.applyUpdate({
        '@type': 'UpdateNewMessage',
        'message': message(5, chatId: 99),
      });

      expect(added, isNull);
      expect(history.messages, isEmpty);
    });

    test('ignores a message from another thread', () async {
      final history = MessageHistoryController(
        source: FakeSource(const [], threadId: 3),
      );

      final added = history.applyUpdate({
        '@type': 'UpdateNewMessage',
        'message': message(5, threadId: 4),
      });

      expect(added, isNull);
    });

    test('drops a duplicate that races an in-flight page', () async {
      final source = FakeSource([
        [message(5)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);
      await history.loadLocal();

      final added = history.applyUpdate({
        '@type': 'UpdateNewMessage',
        'message': message(5),
      });

      expect(added, isNull);
      expect(history.messages.length, 1);
    });

    test('swaps a sent message for its server-side id', () async {
      final source = FakeSource([
        [message(-1)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);
      await history.loadLocal();

      history.applyUpdate({
        '@type': 'UpdateMessageSendSucceeded',
        'oldMessageId': -1,
        'message': message(9),
      });

      expect(history.messages.single['id'], 9);
    });

    test('patches content of a message inside an album', () async {
      final source = FakeSource([
        [message(5, albumId: 7), message(4, albumId: 7)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);
      await history.loadLocal();

      history.applyUpdate({
        '@type': 'UpdateMessageContent',
        'chatId': 10,
        'messageId': 4,
        'newContent': {'@type': 'MessageVideo'},
      });

      final members = history.messages.single['messages'] as List;
      final patched = members.firstWhere((m) => m['id'] == 4);
      expect(patched['content']['@type'], 'MessageVideo');
    });

    test('removes deleted messages and drops the album they empty', () async {
      final source = FakeSource([
        [message(5, albumId: 7), message(4, albumId: 7)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);
      await history.loadLocal();

      history.applyUpdate({
        '@type': 'UpdateDeleteMessages',
        'chatId': 10,
        'messageIds': [4, 5],
      });

      expect(history.messages, isEmpty);
    });

    test('ignores a patch aimed at another chat', () async {
      final source = FakeSource([
        [message(5)],
        const [],
      ]);
      final history = MessageHistoryController(source: source);
      await history.loadLocal();

      history.applyUpdate({
        '@type': 'UpdateMessageEdited',
        'chatId': 99,
        'messageId': 5,
        'editDate': 42,
      });

      expect(history.messages.single['editDate'], isNull);
    });
  });

  group('loadWindowAround', () {
    test('replaces the list with the window and re-opens paging', () async {
      final source = FakeSource([
        [message(5)],
        const [],
        [message(3), message(2)],
      ]);
      final history = MessageHistoryController(source: source);
      // loadLocal takes the first two pages; the window takes the third.
      await history.loadLocal();

      await history.loadWindowAround(3);

      expect(history.messages.map((m) => m['id']), [3, 2]);
      expect(history.hasMore, isTrue);
    });
  });
}
