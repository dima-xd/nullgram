import 'package:flutter/material.dart';
import 'sticker_image.dart';

/// A sticker message.
class MessageSticker extends StatelessWidget {
  final Map<String, dynamic> content;

  const MessageSticker({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return StickerImage(
      sticker: content['sticker'] as Map<String, dynamic>,
      size: 160,
    );
  }
}
