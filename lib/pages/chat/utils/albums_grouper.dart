/// Groups the messages of a media album into a single list entry.
///
/// TDLib delivers an album as separate messages sharing a `mediaAlbumId`;
/// Telegram renders them as one bubble. A grouped entry looks like
/// `{isAlbum: true, messages: [...], id, date, isOutgoing, mediaAlbumId}` and
/// stands in for its members in the message list.
class AlbumsGrouper {
  /// Regroups [messages], which may already contain album entries from an
  /// earlier pass.
  static List<Map<String, dynamic>> groupMediaAlbums(
    List<Map<String, dynamic>> messages,
  ) {
    final flat = _flatten(messages);

    final result = <Map<String, dynamic>>[];
    final albumMap = <int, List<Map<String, dynamic>>>{};
    final albumIndices = <int, int>{};

    for (var i = 0; i < flat.length; i++) {
      final mediaAlbumId = _albumIdOf(flat[i]);
      if (mediaAlbumId == null) continue;
      albumMap.putIfAbsent(mediaAlbumId, () => []).add(flat[i]);
      albumIndices.putIfAbsent(mediaAlbumId, () => i);
    }

    for (final albumMessages in albumMap.values) {
      albumMessages.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    }

    for (var i = 0; i < flat.length; i++) {
      final message = flat[i];
      final mediaAlbumId = _albumIdOf(message);

      if (mediaAlbumId == null) {
        result.add(message);
        continue;
      }
      // Only the album's first position emits an entry; its other members are
      // folded into that one.
      if (albumIndices[mediaAlbumId] != i) continue;

      final albumMessages = albumMap[mediaAlbumId]!;
      if (albumMessages.length == 1) {
        result.add(albumMessages.first);
        continue;
      }
      result.add({
        'isAlbum': true,
        'messages': albumMessages,
        'isOutgoing': albumMessages.first['isOutgoing'],
        'date': albumMessages.first['date'],
        'id': albumMessages.first['id'],
        'mediaAlbumId': mediaAlbumId,
      });
    }

    return result;
  }

  /// The messages grouped inside an album entry, as a properly typed list.
  ///
  /// Album entries are rebuilt by several update handlers, where a bare list
  /// literal widens to `List<dynamic>` and then fails the cast in
  /// `AlbumBubble`. Reads and writes both go through here so the element type
  /// survives a patch. The copy is shallow, so member identity is preserved.
  static List<Map<String, dynamic>> membersOf(Map<String, dynamic> entry) =>
      List<Map<String, dynamic>>.from(entry['messages'] as List);

  /// Expands any previously grouped album entry back into its members.
  ///
  /// Without this, regrouping a list that already holds an album entry would
  /// nest that entry inside a new one as soon as a later history page brought
  /// in another member of the same album — producing an "album of albums" with
  /// no renderable content.
  static List<Map<String, dynamic>> _flatten(
    List<Map<String, dynamic>> messages,
  ) =>
      [
        for (final message in messages)
          if (message['isAlbum'] == true) ...membersOf(message) else message,
      ];

  /// A message's album id, or null when it doesn't belong to an album.
  static int? _albumIdOf(Map<String, dynamic> message) {
    final id = message['mediaAlbumId'] as int?;
    return (id == null || id == 0) ? null : id;
  }
}
