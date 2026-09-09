import 'package:flutter/material.dart';
import 'sticker_image.dart';

/// A message that is nothing but one emoji, which Telegram enlarges and
/// animates.
///
/// TDLib hands over the sticker to draw in `animatedEmoji.sticker`; it is
/// nullable, and a plain oversized glyph is the fallback for the emoji that
/// have no animation.
class MessageAnimatedEmoji extends StatelessWidget {
  const MessageAnimatedEmoji({super.key, required this.content});

  final Map<String, dynamic> content;

  /// The side Telegram gives a lone emoji — noticeably larger than text, but
  /// smaller than a sticker.
  static const double _size = 112;

  @override
  Widget build(BuildContext context) {
    final sticker = content['animatedEmoji']?['sticker'];
    if (sticker is! Map<String, dynamic>) {
      return Text(
        content['emoji'] as String? ?? '',
        style: const TextStyle(fontSize: 48),
      );
    }

    return StickerImage(sticker: sticker, size: _size);
  }
}
