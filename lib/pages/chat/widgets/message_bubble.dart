import 'package:flutter/material.dart';
import 'message_audio.dart';
import 'message_photo.dart';
import 'message_reactions.dart';
import 'message_text.dart';
import 'message_video.dart';
import 'interaction_info.dart';

/// A single chat message.
///
/// [isFirstInGroup] / [isLastInGroup] describe the message's place in a run of
/// consecutive messages from the same sender. They drive grouped spacing, the
/// bubble tail (only the last message in a group gets one), and whether the
/// sender name and timestamp are shown, so a burst of messages reads as a unit.
class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final Map<String, dynamic> chat;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// Called when the bubble is long-pressed, to open the context menu.
  final void Function(Map<String, dynamic> message)? onLongPress;

  /// Called when a reaction chip is tapped, to toggle that reaction.
  final void Function(Map<String, dynamic> message, String emoji)?
      onReactionTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.chat,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onLongPress,
    this.onReactionTap,
  });

  Widget _buildMediaContent(Map<String, dynamic> content, int messageId) {
    final contentType = content['@type'];

    switch (contentType) {
      case 'MessagePhoto':
        return MessagePhoto(content: content, messageId: messageId);
      case 'MessageVideo':
        return MessageVideo(content: content);
      case 'MessageAudio':
      case 'MessageVoiceNote':
        return MessageAudio(content: content);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Rounds all corners except the sender-side bottom corner of the last
  /// message in a group, which is clipped to form a tail.
  BorderRadius _bubbleRadius(bool isOutgoing) {
    const big = Radius.circular(18);
    const tail = Radius.circular(6);
    return BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: (!isOutgoing && isLastInGroup) ? tail : big,
      bottomRight: (isOutgoing && isLastInGroup) ? tail : big,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOutgoing = message['isOutgoing'] ?? false;
    final content = message['content'];
    final contentType = content['@type'];
    final hasCaption = content['caption']?['text'] != null &&
        content['caption']['text'].toString().isNotEmpty;

    final hasMedia = contentType == 'MessagePhoto' ||
        contentType == 'MessageVideo' ||
        contentType == 'MessageAudio' ||
        contentType == 'MessageVoiceNote';

    final isSupergroupChat = chat['supergroup'] != null;
    final senderName =
        (isSupergroupChat && !isOutgoing && isFirstInGroup) ? chat['title'] : null;

    final radius = _bubbleRadius(isOutgoing);
    final bubbleColor =
        isOutgoing ? scheme.primaryContainer : scheme.surfaceContainerHighest;

    final margin = EdgeInsets.only(
      left: 12,
      right: 12,
      top: isFirstInGroup ? 8 : 2,
      bottom: 1,
    );

    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];

    final senderLabel = senderName == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              senderName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          );

    final Widget bubbleContent;

    if (hasMedia && !hasCaption) {
      bubbleContent = Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              boxShadow: shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (senderLabel != null) senderLabel,
                ClipRRect(
                  borderRadius: radius,
                  child: _buildMediaContent(content, message['id']),
                ),
              ],
            ),
          ),
          if (isLastInGroup)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: InteractionInfo(message: message, isOutgoing: isOutgoing),
            ),
        ],
      );
    } else if (hasMedia) {
      bubbleContent = Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: radius,
          boxShadow: shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderLabel != null) senderLabel,
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: _buildMediaContent(content, message['id']),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: double.infinity),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessageText(content: content['caption']),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InteractionInfo(
                      message: message,
                      isOutgoing: isOutgoing,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      bubbleContent = IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
              if (contentType == 'MessageText')
                MessageText(content: content['text']),
              if (isLastInGroup) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: InteractionInfo(
                    message: message,
                    isOutgoing: isOutgoing,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final reactionsList =
        message['interactionInfo']?['reactions']?['reactions'] as List?;

    return GestureDetector(
      onLongPress:
          onLongPress == null ? null : () => onLongPress!(message),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: margin,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubbleContent,
              if (reactionsList != null && reactionsList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: MessageReactions(
                    reactions: reactionsList,
                    isOutgoing: isOutgoing,
                    onTap: (emoji) => onReactionTap?.call(message, emoji),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
