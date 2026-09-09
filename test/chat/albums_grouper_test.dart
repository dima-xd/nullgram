import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';

Map<String, dynamic> message(int id, {int albumId = 0, int date = 100}) => {
      'id': id,
      'date': date,
      'isOutgoing': false,
      'mediaAlbumId': albumId,
      'content': {'@type': 'MessagePhoto'},
    };

void main() {
  group('AlbumsGrouper.groupMediaAlbums', () {
    test('leaves standalone messages alone', () {
      final grouped = AlbumsGrouper.groupMediaAlbums([
        message(3),
        message(2),
      ]);

      expect(grouped.map((m) => m['id']), [3, 2]);
      expect(grouped.every((m) => m['isAlbum'] != true), isTrue);
    });

    test('folds members sharing an album id into one entry', () {
      final grouped = AlbumsGrouper.groupMediaAlbums([
        message(3, albumId: 9),
        message(2, albumId: 9),
        message(1),
      ]);

      expect(grouped.length, 2);
      expect(grouped.first['isAlbum'], isTrue);
      expect(AlbumsGrouper.membersOf(grouped.first).map((m) => m['id']),
          [2, 3]);
      expect(grouped.last['id'], 1);
    });

    test('does not group an album of one', () {
      final grouped = AlbumsGrouper.groupMediaAlbums([
        message(3, albumId: 9),
      ]);

      expect(grouped.single['isAlbum'], isNull);
      expect(grouped.single['id'], 3);
    });

    test('regrouping an already grouped list is stable', () {
      final once = AlbumsGrouper.groupMediaAlbums([
        message(3, albumId: 9),
        message(2, albumId: 9),
      ]);

      final twice = AlbumsGrouper.groupMediaAlbums(once);

      expect(twice.length, 1);
      expect(AlbumsGrouper.membersOf(twice.single).map((m) => m['id']), [2, 3]);
    });

    test('merges a late album member instead of nesting the album', () {
      // A history page can split an album, so the second half arrives after the
      // first half was already grouped. Nesting the existing entry inside a new
      // one would leave a member with no renderable content.
      final firstPage = AlbumsGrouper.groupMediaAlbums([
        message(3, albumId: 9),
        message(2, albumId: 9),
      ]);

      final merged = AlbumsGrouper.groupMediaAlbums([
        ...firstPage,
        message(1, albumId: 9),
      ]);

      expect(merged.length, 1);
      final members = AlbumsGrouper.membersOf(merged.single);
      expect(members.map((m) => m['id']), [1, 2, 3]);
      expect(members.every((m) => m['isAlbum'] != true), isTrue);
    });
  });

  group('AlbumsGrouper.membersOf', () {
    test('returns a typed list even when the entry holds List<dynamic>', () {
      // Update handlers rebuild album entries, where a bare list literal widens
      // to List<dynamic> and used to blow up AlbumBubble's cast at runtime.
      final entry = <String, dynamic>{
        'isAlbum': true,
        'messages': <dynamic>[message(1, albumId: 9)],
      };

      expect(AlbumsGrouper.membersOf(entry), isA<List<Map<String, dynamic>>>());
    });

    test('preserves member identity so in-place patches are visible', () {
      final member = message(1, albumId: 9);
      final entry = <String, dynamic>{
        'isAlbum': true,
        'messages': <dynamic>[member],
      };

      expect(AlbumsGrouper.membersOf(entry).single, same(member));
    });
  });
}
