import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/sender_names.dart';
import 'package:nullgram/theme/app_theme.dart';
import 'message_animated_emoji.dart';
import 'message_animation.dart';
import 'message_audio.dart';
import 'message_contact.dart';
import 'message_document.dart';
import 'message_location.dart';
import 'message_photo.dart';
import 'message_poll.dart';
import 'message_keyboard.dart';
import 'message_link_preview.dart';
import 'message_reply.dart';
import 'message_service.dart';
import 'message_reactions.dart';
import 'message_sender_avatar.dart';
import 'message_sticker.dart';
import 'message_text.dart';
import 'message_video.dart';
import 'interaction_info.dart';
import 'thread_button.dart';

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

  /// Whether the message is part of the current selection, which the chat
  /// draws as a tinted row.
  final bool isSelected;

  /// Called when the bubble is long-pressed, to open the context menu.
  final void Function(Map<String, dynamic> message)? onLongPress;

  /// Called when the bubble is tapped. Only wired while a selection is active,
  /// so a plain tap does nothing in normal reading.
  final void Function(Map<String, dynamic> message)? onTap;

  /// Called when a reaction chip is tapped, to toggle that reaction. Takes a
  /// TDLib reaction *type*, since a custom (premium) reaction has an id rather
  /// than an emoji string.
  final void Function(
    Map<String, dynamic> message,
    Map<String, dynamic> reactionType,
  )? onReactionTap;

  /// Called with the id of the message a reply quote points at.
  final void Function(int messageId)? onReplyTap;

  /// Called when the thread footer is tapped. Null hides the footer, which is
  /// how a thread page avoids offering a thread inside a thread.
  final void Function(Map<String, dynamic> message)? onThreadTap;

  /// Draws the message as the post a comment thread hangs off: full width,
  /// square, no avatar, no sender label and no forward line.
  ///
  /// In a discussion group the post arrives as a forward from the channel, so
  /// those three would all repeat the channel's name and make the post read as
  /// just another comment.
  final bool isThreadHeader;

  const MessageBubble({
    super.key,
    required this.message,
    required this.chat,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.onReactionTap,
    this.onReplyTap,
    this.onThreadTap,
    this.isThreadHeader = false,
  });

  /// The message's reply info when a thread is worth offering, else null.
  Map<String, dynamic>? _threadInfo() {
    if (onThreadTap == null) return null;
    final info = message['interactionInfo']?['replyInfo'];
    if (info is! Map<String, dynamic>) return null;
    if ((info['replyCount'] as int? ?? 0) <= 0) return null;
    return info;
  }

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

  static const _mediaTypes = {
    'MessagePhoto',
    'MessageVideo',
    'MessageAudio',
    'MessageVoiceNote',
    'MessageDocument',
    'MessageSticker',
    'MessageAnimation',
    'MessageVideoNote',
  };

  Widget _buildMediaContent(Map<String, dynamic> content, int messageId) {
    switch (content['@type']) {
      case 'MessagePhoto':
        return MessagePhoto(content: content, messageId: messageId);
      case 'MessageVideo':
      case 'MessageVideoNote':
        return MessageVideo(content: content);
      case 'MessageAudio':
      case 'MessageVoiceNote':
        return MessageAudio(
          content: content,
          chatId: chat['id'] as int,
          messageId: messageId,
        );
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
    if (isThreadHeader) return BorderRadius.zero;
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
    final isOutgoing = message['isOutgoing'] == true;
    final contentType = content['@type'] as String?;
    final caption = content['caption']?['text'] as String?;
    final hasCaption = caption != null && caption.isNotEmpty;
    final hasMedia = _mediaTypes.contains(contentType);

    // Group chats (basic groups and non-channel supergroups) show a sender
    // name and avatar beside incoming messages; private chats and channels do
    // not, because the sender is implied by the chat itself.
    final chatType = chat['type']?['@type'];
    final isGroupChat = chatType == 'ChatTypeBasicGroup' ||
        (chatType == 'ChatTypeSupergroup' &&
            chat['type']?['isChannel'] != true);
    final showSenderName =
        isGroupChat && !isOutgoing && isFirstInGroup && !isThreadHeader;
    final showAvatar = isGroupChat && !isOutgoing && !isThreadHeader;
    const double avatarRadius = 16;

    final radius = _bubbleRadius(isOutgoing);
    final chatColors = context.chatColors;
    final bubbleColor =
        isOutgoing ? chatColors.outgoingBubble : chatColors.incomingBubble;

    // Only a text message carries one; TDLib puts media previews in the
    // content itself.
    final linkPreview = content['linkPreview'] as Map<String, dynamic>?;
    final showPreviewAbove = linkPreview?['showAboveText'] == true;

    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    final isReply = replyTo?['@type'] == 'MessageReplyToMessage';
    final isForward = message['forwardInfo'] != null && !isThreadHeader;

    // Everything that sits above the message's own content, in Telegram's
    // order: who sent it, where it was forwarded from, what it replies to.
    final prefix = <Widget>[
      if (showSenderName)
        _SenderLabel(senderId: message['senderId'], chatId: chat['id'] as int),
      if (isForward) ForwardHeader(message: message),
      if (isReply)
        ReplyQuote(
          replyTo: replyTo!,
          chatId: chat['id'] as int,
          onTap: onReplyTap ?? (_) {},
        ),
    ];

    final interactionInfo = InteractionInfo(
      message: message,
      isOutgoing: isOutgoing,
      lastReadOutboxMessageId:
          chat['lastReadOutboxMessageId'] as int? ?? 0,
    );

    final Widget meta = interactionInfo;

    // Reactions and the thread footer belong inside the bubble, under the
    // content: outside it they read as loose chrome floating next to the
    // message.
    final reactionsList =
        message['interactionInfo']?['reactions']?['reactions'] as List?;
    final Widget? reactionsRow =
        (reactionsList == null || reactionsList.isEmpty)
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: MessageReactions(
                  reactions: reactionsList,
                  isOutgoing: isOutgoing,
                  onTap: (type) => onReactionTap?.call(message, type),
                ),
              );

    final threadInfo = _threadInfo();
    final Widget? threadFooter = threadInfo == null
        ? null
        : ThreadButton(
            replyInfo: threadInfo,
            isChannelPost: message['isChannelPost'] == true,
            onTap: () => onThreadTap!(message),
          );

    final decoration = isThreadHeader
        ? BoxDecoration(
            color: bubbleColor,
            border: Border(
              bottom: BorderSide(color: chatColors.bubbleBorder),
            ),
          )
        : BoxDecoration(
            color: bubbleColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(color: chatColors.bubbleBorder),
          );

    // Riding at the end of the text keeps a two-word message one line tall;
    // only bubbles whose content cannot host a span fall back to a row of
    // their own.
    final metaSpan = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: meta,
      ),
    );

    final Widget bubbleContent;

    if (hasMedia && !hasCaption) {
      // Bare media: the timestamp sits below the bubble so it never covers the
      // image, and the media fills the bubble unless a prefix pushes it down.
      bubbleContent = Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prefix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: prefix,
                    ),
                  ),
                ClipRRect(
                  // Anything below the media inside the bubble means the
                  // media's bottom corners have to stay square, or the image
                  // reads as floating above a separate strip.
                  borderRadius: prefix.isEmpty
                      ? (reactionsRow == null && threadFooter == null
                          ? radius
                          : BorderRadius.only(
                              topLeft: radius.topLeft,
                              topRight: radius.topRight,
                            ))
                      : BorderRadius.circular(12),
                  child: Padding(
                    padding: prefix.isEmpty
                        ? EdgeInsets.zero
                        : const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: _buildMediaContent(content, message['id'] as int),
                  ),
                ),
                if (reactionsRow != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: reactionsRow,
                  ),
                if (threadFooter != null) threadFooter,
              ],
            ),
          ),
          if (isLastInGroup)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: meta,
            ),
        ],
      );
    } else if (hasMedia) {
      bubbleContent = Container(
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prefix.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: prefix,
                ),
              ),
            ClipRRect(
              // The thread header is a square full-width band, so its media
              // must not keep the bubble's rounded shoulders.
              borderRadius: isThreadHeader
                  ? BorderRadius.zero
                  : prefix.isEmpty
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        )
                      : BorderRadius.circular(12),
              child: Padding(
                padding: prefix.isEmpty
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 4),
                child: _buildMediaContent(content, message['id'] as int),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessageText(content: content['caption']),
                  if (reactionsRow != null) reactionsRow,
                  if (isLastInGroup) ...[
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: meta),
                  ],
                ],
              ),
            ),
            if (threadFooter != null) threadFooter,
          ],
        ),
      );
    } else {
      bubbleContent = IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...prefix,
              if (contentType == 'MessageText') ...[
                if (linkPreview != null && showPreviewAbove)
                  MessageLinkPreview(linkPreview: linkPreview),
                MessageText(
                  content: content['text'],
                  trailing:
                      isLastInGroup && linkPreview == null ? metaSpan : null,
                ),
                if (linkPreview != null && !showPreviewAbove)
                  MessageLinkPreview(linkPreview: linkPreview),
              ],
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
                MessageAnimatedEmoji(content: content),
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
              if (reactionsRow != null) reactionsRow,
              if (threadFooter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: threadFooter,
                ),
              // Text already carries the meta inline; everything else still
              // needs its own row for it.
              if (isLastInGroup &&
                  (contentType != 'MessageText' || linkPreview != null)) ...[
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: meta),
              ],
            ],
          ),
        ),
      );
    }

    final replyMarkup = message['replyMarkup'] as Map<String, dynamic>?;

    final bubbleColumn = Container(
      constraints: BoxConstraints(
        maxWidth: isThreadHeader
            ? double.infinity
            : MediaQuery.of(context).size.width * 0.75,
      ),
      child: Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bubbleContent,
          if (replyMarkup != null)
            MessageKeyboard(
              replyMarkup: replyMarkup,
              chatId: chat['id'] as int,
              messageId: message['id'] as int,
            ),
        ],
      ),
    );

    final margin = isThreadHeader
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: 12,
            right: 12,
            top: isFirstInGroup ? 8 : 2,
            bottom: 1,
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
      aligned = isThreadHeader
          ? bubbleColumn
          : Align(
              alignment:
                  isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(padding: margin, child: bubbleColumn),
            );
    }

    return GestureDetector(
      onLongPress: onLongPress == null ? null : () => onLongPress!(message),
      onTap: onTap == null ? null : () => onTap!(message),
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Padding(
          padding: showAvatar
              ? EdgeInsets.only(top: isFirstInGroup ? 8 : 2, bottom: 1)
              : EdgeInsets.zero,
          child: aligned,
        ),
      ),
    );
  }
}

/// The sender's name above their first message in a group run.
///
/// Resolved asynchronously and coloured per sender, so a busy group stays
/// readable. Renders nothing until the name is known rather than flashing a
/// placeholder.
class _SenderLabel extends StatefulWidget {
  const _SenderLabel({required this.senderId, required this.chatId});

  final dynamic senderId;
  final int chatId;

  @override
  State<_SenderLabel> createState() => _SenderLabelState();
}

class _SenderLabelState extends State<_SenderLabel> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _name = SenderNames.cached(widget.senderId);
    if (_name == null) _resolve();
  }

  Future<void> _resolve() async {
    final name = await SenderNames.resolve(widget.senderId);
    if (name != null && mounted) setState(() => _name = name);
  }

  /// A stable id for colouring, so the same person keeps the same colour.
  int get _colorSeed {
    final senderId = widget.senderId;
    if (senderId is Map) {
      return (senderId['userId'] ?? senderId['chatId'] ?? widget.chatId) as int;
    }
    return widget.chatId;
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    if (name == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.chatColors.senderNameColor(
                _colorSeed,
                Theme.of(context).brightness,
              ),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
