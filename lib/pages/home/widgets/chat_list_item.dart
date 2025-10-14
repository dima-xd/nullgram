import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'chat_avatar.dart';

class ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  final int? currentFolderId;
  final Map<String, bool> fileExistsCache;
  final Map<String, Uint8List?> miniThumbnailCache;
  final Function(int) onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.currentFolderId,
    required this.fileExistsCache,
    required this.miniThumbnailCache,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
    final chatId = chat['id'] as int;
    final title = chat['title'] as String? ?? 'Unknown';
    final unreadCount = chat['unreadCount'] as int? ?? 0;

    final positions = chat['positions'] as List<dynamic>?;
    Map<String, dynamic>? currentPosition = positions?.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['list']?['chatFolderId'] == currentFolderId,
      orElse: () => null,
    );

    final isPinnedInCurrentFolder = currentPosition?['isPinned'] as bool? ?? false;

    return InkWell(
      key: ValueKey('chat_$chatId'),
      onTap: () => onTap(chatId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: ChatAvatar(
                chat: chat,
                radius: 24,
                fileExistsCache: fileExistsCache,
                miniThumbnailCache: miniThumbnailCache,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPinnedInCurrentFolder)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMessage != null)
                        Text(
                          _formatTime(lastMessage['date'] as int),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getMessagePreview(lastMessage),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 999 ? '999+' : unreadCount.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMessagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return '';

    final content = lastMessage['content'] as Map<String, dynamic>?;
    if (content == null) return '';

    final type = content['@type'] as String?;

    switch (type) {
      case 'MessageText':
        return content['text']?['text'] as String? ?? '';
      case 'MessagePhoto':
        return '📷 Photo';
      case 'MessageVideo':
        return '🎥 Video';
      case 'MessageVoiceNote':
        return '🎤 Voice message';
      case 'MessageDocument':
        return '📎 Document';
      case 'MessageSticker':
        return '🎨 Sticker';
      case 'MessageAnimation':
        return '🎬 GIF';
      default:
        return 'Message';
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year) {
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month]}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year % 100}';
    }
  }
}
