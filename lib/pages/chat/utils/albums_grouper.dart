class AlbumsGrouper {
  static List<Map<String, dynamic>> groupMediaAlbums(List<Map<String, dynamic>> messages) {
    final result = <Map<String, dynamic>>[];
    final albumMap = <int, List<Map<String, dynamic>>>{};
    final albumIndices = <int, int>{};

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final mediaAlbumId = message['mediaAlbumId'] as int?;

      if (mediaAlbumId != null && mediaAlbumId != 0) {
        albumMap.putIfAbsent(mediaAlbumId, () => []).add(message);
        if (!albumIndices.containsKey(mediaAlbumId)) {
          albumIndices[mediaAlbumId] = i;
        }
      }
    }

    for (final albumMessages in albumMap.values) {
      albumMessages.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    }

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final mediaAlbumId = message['mediaAlbumId'] as int?;

      if (mediaAlbumId != null && mediaAlbumId != 0) {
        if (albumIndices[mediaAlbumId] == i) {
          final albumMessages = albumMap[mediaAlbumId]!;
          if (albumMessages.length > 1) {
            result.add({
              'isAlbum': true,
              'messages': albumMessages,
              'isOutgoing': albumMessages.first['isOutgoing'],
              'date': albumMessages.first['date'],
              'id': albumMessages.first['id'],
              'mediaAlbumId': mediaAlbumId,
            });
          } else {
            result.add(albumMessages.first);
          }
        }
      } else {
        result.add(message);
      }
    }

    return result;
  }
}
