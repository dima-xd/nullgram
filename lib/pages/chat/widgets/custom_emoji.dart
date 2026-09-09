import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/sticker_image.dart';
import 'package:nullgram/services/custom_emoji_cache.dart';

/// A custom (premium) emoji, drawn as the sticker behind it.
///
/// Until the sticker is resolved — and forever, if Telegram doesn't know the
/// id — this shows [fallback], which is the plain emoji the message already
/// carries in its text. That is the same graceful degradation a client without
/// custom emoji support gives, so text never comes out blank.
class CustomEmoji extends StatefulWidget {
  const CustomEmoji({
    super.key,
    required this.customEmojiId,
    required this.size,
    required this.fallback,
    this.color,
    this.animate = true,
  });

  final int customEmojiId;

  /// The rendered side length, normally a little above the line's font size.
  final double size;

  /// The text this emoji stands in for while unresolved.
  final String fallback;

  /// The colour to paint a monochrome emoji in — usually the surrounding text
  /// colour. Ignored for emoji that carry their own colours.
  final Color? color;

  final bool animate;

  @override
  State<CustomEmoji> createState() => _CustomEmojiState();
}

class _CustomEmojiState extends State<CustomEmoji> {
  Map<String, dynamic>? _sticker;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CustomEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customEmojiId != widget.customEmojiId) {
      _sticker = null;
      _resolve();
    }
  }

  void _resolve() {
    final known = CustomEmojiCache.cached(widget.customEmojiId);
    if (known != null) {
      _sticker = known;
      return;
    }
    if (CustomEmojiCache.isResolved(widget.customEmojiId)) return;

    CustomEmojiCache.resolve(widget.customEmojiId).then((sticker) {
      if (sticker != null && mounted) setState(() => _sticker = sticker);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sticker = _sticker;
    if (sticker == null) {
      return Text(
        widget.fallback,
        style: TextStyle(fontSize: widget.size * 0.85),
      );
    }

    final image = StickerImage(
      sticker: sticker,
      size: widget.size,
      animate: widget.animate,
    );

    // A "repainting" custom emoji ships as a monochrome shape that Telegram
    // tints to match the text around it; drawn as-is it can come out
    // invisible against the bubble.
    final tint = widget.color;
    if (sticker['fullType']?['needsRepainting'] != true || tint == null) {
      return image;
    }
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcATop),
      child: image,
    );
  }
}
