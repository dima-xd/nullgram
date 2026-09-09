import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/chat_store.dart';

Map<String, dynamic> message(int id, {int albumId = 42}) => {
      'id': id,
      'mediaAlbumId': albumId,
    };

/// A fake chat history that mimics TDLib's documented habit of returning
/// fewer messages than the caller asked for.
class FakeHistory {
  FakeHistory(this.messages, {this.batchSize = 1});

  /// Every message in the chat, newest first.
  final List<Map<String, dynamic>> messages;

  /// How many messages a single call hands back.
  final int batchSize;

  int calls = 0;

  Future<List<Map<String, dynamic>>> fetchOlder(int fromMessageId) async {
    calls++;
    final older = [
      for (final candidate in messages)
        if ((candidate['id'] as int) < fromMessageId) candidate,
    ];
    return older.take(batchSize).toList();
  }
}

void main() {
  group('collectAlbumMembers', () {
    test('walks back through one-message batches to find the whole album', () {
      // The regression: TDLib answered with a single message, so a three-photo
      // album was resolved as "1 photo".
      final history = FakeHistory([
        message(3),
        message(2),
        message(1),
        message(0, albumId: 0),
      ]);

      return expectLater(
        collectAlbumMembers(
          lastMessage: message(3),
          albumId: 42,
          fetchOlder: history.fetchOlder,
        ).then((members) => members.map((m) => m['id'])),
        completion([1, 2, 3]),
      );
    });

    test('stops at the first message outside the album', () async {
      final history = FakeHistory([
        message(5),
        message(4),
        message(3, albumId: 0),
        message(2),
      ], batchSize: 10);

      final members = await collectAlbumMembers(
        lastMessage: message(5),
        albumId: 42,
        fetchOlder: history.fetchOlder,
      );

      // Message 2 shares the album id but sits behind an unrelated message,
      // so it belongs to a different album that happened to reuse the id.
      expect(members.map((m) => m['id']), [4, 5]);
    });

    test('returns the lone message when the history holds nothing older',
        () async {
      final history = FakeHistory([message(1)]);

      final members = await collectAlbumMembers(
        lastMessage: message(1),
        albumId: 42,
        fetchOlder: history.fetchOlder,
      );

      expect(members.map((m) => m['id']), [1]);
    });

    test('gives up instead of looping on an empty history', () async {
      final history = FakeHistory(const []);

      await collectAlbumMembers(
        lastMessage: message(9),
        albumId: 42,
        fetchOlder: history.fetchOlder,
      );

      // Two rounds of nothing is taken as the end of the history.
      expect(history.calls, 2);
    });

    test('gives up when the backend keeps replaying the same messages',
        () async {
      var calls = 0;
      Future<List<Map<String, dynamic>>> stuck(int fromMessageId) async {
        calls++;
        // Ids at or above the cursor can never advance the walk.
        return [message(9), message(10)];
      }

      final members = await collectAlbumMembers(
        lastMessage: message(9),
        albumId: 42,
        fetchOlder: stuck,
      );

      expect(calls, 2);
      expect(members.map((m) => m['id']), [9]);
    });

    test('never collects more than an album can hold', () async {
      final history = FakeHistory([
        for (var id = 30; id > 0; id--) message(id),
      ], batchSize: 3);

      final members = await collectAlbumMembers(
        lastMessage: message(30),
        albumId: 42,
        fetchOlder: history.fetchOlder,
      );

      expect(members.length, lessThanOrEqualTo(maxAlbumSize));
    });
  });
}
