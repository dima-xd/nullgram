import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/custom_emoji_cache.dart';

Map<String, dynamic> sticker(int customEmojiId) => {
      'emoji': '⭐',
      'fullType': {
        '@type': 'StickerFullTypeCustomEmoji',
        'customEmojiId': customEmojiId,
      },
    };

void main() {
  /// The id batches the cache asked for, in order.
  late List<List<int>> requests;

  setUp(() {
    requests = [];
    CustomEmojiCache.clear();
    CustomEmojiCache.fetch = (ids) async {
      requests.add(ids);
      // TDLib returns only the ids it knows, in arbitrary order.
      return [for (final id in ids.reversed) if (id > 0) sticker(id)];
    };
  });

  tearDownAll(CustomEmojiCache.clear);

  group('CustomEmojiCache', () {
    test('coalesces ids asked for in the same window into one request',
        () async {
      final results = await Future.wait([
        CustomEmojiCache.resolve(1),
        CustomEmojiCache.resolve(2),
        CustomEmojiCache.resolve(3),
      ]);

      expect(requests, hasLength(1));
      expect(requests.single, containsAll([1, 2, 3]));
      expect(
        results.map((s) => s?['fullType']['customEmojiId']),
        containsAll([1, 2, 3]),
      );
    });

    test('matches answers by id, not by the order they came back in', () async {
      final sticker2 = await CustomEmojiCache.resolve(2);

      expect(sticker2?['fullType']['customEmojiId'], 2);
    });

    test('asks only once for an id it already knows', () async {
      await CustomEmojiCache.resolve(1);
      await CustomEmojiCache.resolve(1);

      expect(requests, hasLength(1));
      expect(CustomEmojiCache.cached(1), isNotNull);
    });

    test('shares one request between concurrent callers of the same id',
        () async {
      await Future.wait([
        CustomEmojiCache.resolve(5),
        CustomEmojiCache.resolve(5),
      ]);

      expect(requests, hasLength(1));
      expect(requests.single, [5]);
    });

    test('remembers an unknown id so it is never asked for twice', () async {
      // The fake answers nothing for id 0.
      expect(await CustomEmojiCache.resolve(0), isNull);
      expect(CustomEmojiCache.isResolved(0), isTrue);

      expect(await CustomEmojiCache.resolve(0), isNull);
      expect(requests, hasLength(1));
    });

    test('splits more ids than a request can carry across batches', () async {
      // TDLib accepts at most 200 ids per call.
      await Future.wait([
        for (var id = 1; id <= 250; id++) CustomEmojiCache.resolve(id),
      ]);

      expect(requests, hasLength(2));
      expect(requests.first, hasLength(200));
      expect(requests.last, hasLength(50));
    });

    test('keeps resolving after a failed request', () async {
      CustomEmojiCache.fetch = (ids) async => throw StateError('offline');
      expect(await CustomEmojiCache.resolve(7), isNull);

      CustomEmojiCache.clear();
      CustomEmojiCache.fetch = (ids) async {
        requests.add(ids);
        return [sticker(ids.single)];
      };

      expect(await CustomEmojiCache.resolve(7), isNotNull);
    });

    test('forgets everything on clear', () async {
      await CustomEmojiCache.resolve(1);
      CustomEmojiCache.clear();

      expect(CustomEmojiCache.cached(1), isNull);
      expect(CustomEmojiCache.isResolved(1), isFalse);
    });
  });
}
