import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/chat/widgets/custom_emoji.dart';
import 'package:nullgram/services/custom_emoji_cache.dart';

Map<String, dynamic> sticker(int id, {bool needsRepainting = false}) => {
      'emoji': '⭐',
      'width': 100,
      'height': 100,
      'format': {'@type': 'StickerFormatWebp'},
      'sticker': {
        'id': 1,
        'local': {'path': '', 'isDownloadingCompleted': false},
      },
      'fullType': {
        '@type': 'StickerFullTypeCustomEmoji',
        'customEmojiId': id,
        'needsRepainting': needsRepainting,
      },
    };

Future<void> pumpEmoji(
  WidgetTester tester, {
  required int id,
  Color? color,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomEmoji(
          customEmojiId: id,
          size: 20,
          fallback: '🙂',
          color: color,
        ),
      ),
    ),
  );
}

void main() {
  setUp(CustomEmojiCache.clear);
  tearDownAll(CustomEmojiCache.clear);

  group('CustomEmoji', () {
    testWidgets('shows the plain-emoji fallback until the sticker resolves', (
      tester,
    ) async {
      // Stands in for a lookup that hasn't come back yet.
      final answer = Completer<List<Map<String, dynamic>>>();
      CustomEmojiCache.fetch = (ids) => answer.future;

      await pumpEmoji(tester, id: 1);
      // Let the batch window elapse, so the lookup is genuinely in flight
      // rather than merely queued.
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('🙂'), findsOneWidget);

      // Settle it, so no timer or future outlives the test.
      answer.complete([sticker(1)]);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the fallback for an emoji Telegram does not know', (
      tester,
    ) async {
      CustomEmojiCache.fetch = (ids) async => const [];

      await pumpEmoji(tester, id: 1);
      await tester.pumpAndSettle();

      expect(find.text('🙂'), findsOneWidget);
    });

    testWidgets('swaps the fallback for the sticker once resolved', (
      tester,
    ) async {
      CustomEmojiCache.fetch = (ids) async => [sticker(ids.single)];

      await pumpEmoji(tester, id: 1);
      await tester.pumpAndSettle();

      expect(find.text('🙂'), findsNothing);
    });

    testWidgets('tints a monochrome emoji to the surrounding text colour', (
      tester,
    ) async {
      CustomEmojiCache.fetch =
          (ids) async => [sticker(ids.single, needsRepainting: true)];

      await pumpEmoji(tester, id: 1, color: Colors.red);
      await tester.pumpAndSettle();

      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('leaves a full-colour emoji untinted', (tester) async {
      CustomEmojiCache.fetch = (ids) async => [sticker(ids.single)];

      await pumpEmoji(tester, id: 1, color: Colors.red);
      await tester.pumpAndSettle();

      expect(find.byType(ColorFiltered), findsNothing);
    });
  });
}
