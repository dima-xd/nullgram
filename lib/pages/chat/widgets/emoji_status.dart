import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/custom_emoji.dart';

/// The custom emoji a user or channel has set as their status, shown after
/// their name.
///
/// Renders nothing when there is no status, or when the status is one of the
/// non-custom kinds TDLib also models — those carry no emoji to draw.
class EmojiStatusBadge extends StatelessWidget {
  const EmojiStatusBadge({super.key, required this.chat, this.size = 16});

  /// A chat, which may carry a status itself (a channel) or through the user
  /// merged into it (a private chat).
  final Map<String, dynamic> chat;

  final double size;

  int? get _customEmojiId {
    final status = chat['emojiStatus'] ?? chat['user']?['emojiStatus'];
    final type = status?['type'];
    if (type?['@type'] != 'EmojiStatusTypeCustomEmoji') return null;
    return type['customEmojiId'] as int?;
  }

  @override
  Widget build(BuildContext context) {
    final customEmojiId = _customEmojiId;
    if (customEmojiId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: CustomEmoji(
        customEmojiId: customEmojiId,
        size: size,
        // A status has no text form to fall back to, so nothing is drawn
        // until the sticker arrives.
        fallback: '',
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
