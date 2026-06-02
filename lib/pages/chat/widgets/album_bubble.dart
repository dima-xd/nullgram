import 'package:flutter/material.dart';
import 'message_audio.dart';
import 'message_photo.dart';
import 'message_reactions.dart';
import 'message_text.dart';
import 'message_video.dart';
import 'interaction_info.dart';

class AlbumBubble extends StatefulWidget {
  final List<Map<String, dynamic>> albumMessages;
  final Map<String, dynamic> chat;

  /// Called when the album is long-pressed, to open the context menu.
  final void Function(Map<String, dynamic> message)? onLongPress;

  /// Called when a reaction chip is tapped, to toggle that reaction.
  final void Function(Map<String, dynamic> message, String emoji)?
      onReactionTap;

  const AlbumBubble({
    super.key,
    required this.albumMessages,
    required this.chat,
    this.onLongPress,
    this.onReactionTap,
  });

  @override
  State<AlbumBubble> createState() => _AlbumBubbleState();
}

class _AlbumBubbleState extends State<AlbumBubble> {
  List<String> _getAlbumPhotoPaths() {
    return widget.albumMessages
        .where((msg) => msg['content']['@type'] == 'MessagePhoto')
        .map((msg) => msg['content']['photo']['sizes'].last['photo']['local']['path'] as String)
        .where((path) => path.isNotEmpty)
        .toList();
  }

  Widget _buildMediaContent(Map<String, dynamic> content, int messageId, int albumIndex) {
    final contentType = content['@type'];

    switch (contentType) {
      case 'MessagePhoto':
        return MessagePhoto(
          content: content,
          messageId: messageId,
          albumPaths: _getAlbumPhotoPaths(),
          albumIndex: albumIndex,
        );
      case 'MessageVideo':
        return MessageVideo(content: content);
      case 'MessageAudio':
        return MessageAudio(content: content);
      default:
        return const SizedBox.shrink();
    }
  }

  int _computeCrossAxisCount(int messageCount) {
    if (messageCount == 1) return 1;
    if (messageCount == 2 || messageCount == 4) return 2;
    if (messageCount == 3) return 3;
    return 2;
  }

  /// Reaction chips for the album, keyed off its first message (the one that
  /// carries the album's reactions in TDLib). Empty when there are none.
  Widget _reactionsRow(Map<String, dynamic> message, bool isOutgoing) {
    final reactions =
        message['interactionInfo']?['reactions']?['reactions'] as List?;
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
      child: MessageReactions(
        reactions: reactions,
        isOutgoing: isOutgoing,
        onTap: (emoji) => widget.onReactionTap?.call(message, emoji),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = widget.albumMessages.first['isOutgoing'] ?? false;
    final messageCount = widget.albumMessages.length;

    final firstContent = widget.albumMessages.first['content'];
    if (firstContent == null) {
      return const SizedBox.shrink();
    }

    final hasCaption = firstContent['caption']?['text'] != null &&
        firstContent['caption']['text'].toString().isNotEmpty;

    final isSupergroupChat = widget.chat['supergroup'] != null;
    String? senderName;

    if (isSupergroupChat && !isOutgoing) {
      senderName = widget.chat['title'];
    }

    final crossAxisCount = _computeCrossAxisCount(messageCount);

    final Map<int, int> photoIndexMap = {};
    int photoCounter = 0;
    for (int i = 0; i < widget.albumMessages.length; i++) {
      final content = widget.albumMessages[i]['content'];
      if (content != null && content['@type'] == 'MessagePhoto') {
        photoIndexMap[i] = photoCounter;
        photoCounter++;
      }
    }

    Widget buildGrid() {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: messageCount,
          itemBuilder: (context, index) {
            final message = widget.albumMessages[index];
            final content = message['content'];
            final albumIndex = photoIndexMap[index] ?? 0;
            return _buildMediaContent(content, message['id'], albumIndex);
          },
        ),
      );
    }

    final firstMessage = widget.albumMessages.first;

    if (hasCaption) {
      return GestureDetector(
        onLongPress: widget.onLongPress == null
            ? null
            : () => widget.onLongPress!(firstMessage),
        behavior: HitTestBehavior.opaque,
        child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (senderName != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            senderName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      buildGrid(),
                      Container(
                        constraints: const BoxConstraints(minWidth: double.infinity),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MessageText(content: firstContent['caption']),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InteractionInfo(
                                message: widget.albumMessages.first,
                                isOutgoing: isOutgoing,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _reactionsRow(firstMessage, isOutgoing),
            ],
          ),
        ),
      ),
      );
    }

    return GestureDetector(
      onLongPress: widget.onLongPress == null
          ? null
          : () => widget.onLongPress!(firstMessage),
      behavior: HitTestBehavior.opaque,
      child: Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isOutgoing
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  buildGrid(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: InteractionInfo(
                  message: widget.albumMessages.first,
                  isOutgoing: isOutgoing,
                ),
              ),
            ),
            _reactionsRow(firstMessage, isOutgoing),
          ],
        ),
      ),
      ),
    );
  }
}
