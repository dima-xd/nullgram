import 'package:flutter/material.dart';
import 'message_audio.dart';
import 'message_photo.dart';
import 'message_text.dart';
import 'message_video.dart';
import 'interaction_info.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final Map<String, dynamic> chat;

  const MessageBubble({
    super.key,
    required this.message,
    required this.chat,
  });

  Widget _buildMediaContent(Map<String, dynamic> content, int messageId) {
    final contentType = content['@type'];

    switch (contentType) {
      case 'MessagePhoto':
        return MessagePhoto(content: content, messageId: messageId);
      case 'MessageVideo':
        return MessageVideo(content: content);
      case 'MessageAudio':
        return MessageAudio(content: content);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message['isOutgoing'] ?? false;
    final content = message['content'];
    final contentType = content['@type'];
    final hasCaption = content['caption']?['text'] != null &&
        content['caption']['text'].toString().isNotEmpty;

    final hasMedia = contentType == 'MessagePhoto' ||
        contentType == 'MessageVideo' ||
        contentType == 'MessageAudio';

    final isSupergroupChat = chat['supergroup'] != null;
    String? senderName;

    if (isSupergroupChat && !isOutgoing) {
      senderName = chat['title'];
    }

    if (hasMedia && !hasCaption) {
      return Align(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildMediaContent(content, message['id']),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InteractionInfo(
                    message: message,
                    isOutgoing: isOutgoing,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
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
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: _buildMediaContent(content, message['id']),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: double.infinity),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              )
            else
              IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
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
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      if (contentType == 'MessageText')
                        MessageText(content: content['text']),
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
              ),
          ],
        ),
      ),
    );
  }
}
