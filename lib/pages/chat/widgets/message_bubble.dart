import 'package:flutter/material.dart';
import 'package:nullgram/theme/app_theme.dart';
import 'message_animation.dart';
import 'message_audio.dart';
import 'message_contact.dart';
import 'message_document.dart';
import 'message_location.dart';
import 'message_photo.dart';
import 'message_poll.dart';
import 'message_service.dart';
import 'message_reactions.dart';
import 'message_sender_avatar.dart';
import 'message_sticker.dart';
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

  /// Non-media content types rendered explicitly in the bubble's text branch.
  /// Anything outside this set (and not media or a service message) falls back
  /// to an [unsupportedLabel] line so it is never blank.
  static const _handledNonMedia = {
    'MessageText',
    'MessageLocation',
    'MessageVenue',
    'MessageContact',
    'MessagePoll',
    'MessageAnimatedEmoji',
    'MessageDice',
  };

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
      case 'MessageDocument':
        return MessageDocument(content: content);
      case 'MessageSticker':
        return MessageSticker(content: content);
      case 'MessageAnimation':
        return MessageAnimation(content: content);
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
    final content = message['content'] as Map<String, dynamic>;
    final serviceText = serviceMessageText(content);
    if (serviceText != null) return ServiceMessage(text: serviceText);

    final scheme = Theme.of(context).colorScheme;
    final isOutgoing = message['isOutgoing'] ?? false;
    final contentType = content['@type'];
    final hasCaption = content['caption']?['text'] != null &&
        content['caption']['text'].toString().isNotEmpty;

    final hasMedia = contentType == 'MessagePhoto' ||
        contentType == 'MessageVideo' ||
        contentType == 'MessageAudio' ||
        contentType == 'MessageVoiceNote' ||
        contentType == 'MessageDocument' ||
        contentType == 'MessageSticker' ||
        contentType == 'MessageAnimation';

    final isSupergroupChat = chat['supergroup'] != null;
    final senderName =
        (isSupergroupChat && !isOutgoing && isFirstInGroup) ? chat['title'] : null;

    // Group chats (basic groups and non-channel supergroups) show a sender
    // avatar beside incoming messages; private chats and channels do not.
    final chatType = chat['type']?['@type'];
    final isGroupChat = chatType == 'ChatTypeBasicGroup' ||
        (chatType == 'ChatTypeSupergroup' && chat['type']?['isChannel'] != true);
    final showAvatar = isGroupChat && !isOutgoing;
    const double avatarRadius = 16;

    final radius = _bubbleRadius(isOutgoing);
    final chatColors = context.chatColors;
    final bubbleColor = isOutgoing
        ? chatColors.outgoingBubble
        : chatColors.incomingBubble;

    final margin = EdgeInsets.only(
      left: 12,
      right: 12,
      top: isFirstInGroup ? 8 : 2,
      bottom: 1,
    );

    final shadow = [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: 0.05),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
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
              border: Border.all(color: chatColors.bubbleBorder),
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
          border: Border.all(color: chatColors.bubbleBorder),
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
            border: Border.all(color: chatColors.bubbleBorder),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              if (contentType == 'MessageText')
                MessageText(content: content['text']),
              if (contentType == 'MessageLocation' ||
                  contentType == 'MessageVenue')
                MessageLocation(content: content),
              if (contentType == 'MessageContact')
                MessageContact(content: content),
              if (contentType == 'MessagePoll')
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.65,
                  child: MessagePoll(
                    poll: content['poll'],
                    chatId: chat['id'],
                    messageId: message['id'],
                  ),
                ),
              if (contentType == 'MessageAnimatedEmoji')
                Text(
                  content['emoji'] as String? ?? '',
                  style: const TextStyle(fontSize: 48),
                ),
              if (contentType == 'MessageDice')
                Text(
                  '${content['emoji'] ?? '🎲'} ${content['value'] ?? ''}',
                  style: const TextStyle(fontSize: 40),
                ),
              if (!_handledNonMedia.contains(contentType))
                Text(
                  unsupportedLabel(content),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
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

    final bubbleColumn = Container(
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
    );

    final Widget aligned;
    if (showAvatar) {
      // Reserve avatar space for every message in the group so bubbles line up,
      // but only render the avatar on the last message in the run (Telegram
      // anchors it to the bottom of the group).
      final senderId = message['senderId'] as Map<String, dynamic>?;
      aligned = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: avatarRadius * 2,
                child: (isLastInGroup && senderId != null)
                    ? MessageSenderAvatar(
                        senderId: senderId,
                        radius: avatarRadius,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(child: bubbleColumn),
            ],
          ),
        ),
      );
    } else {
      aligned = Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(padding: margin, child: bubbleColumn),
      );
    }

    return GestureDetector(
      onLongPress: onLongPress == null ? null : () => onLongPress!(message),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: showAvatar
            ? EdgeInsets.only(top: isFirstInGroup ? 8 : 2, bottom: 1)
            : EdgeInsets.zero,
        child: aligned,
      ),
    );
  }
}
