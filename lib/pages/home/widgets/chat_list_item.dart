import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../chat/widgets/chat_avatar.dart';

class ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chat;
  final int? currentFolderId;
  final Map<String, bool> fileExistsCache;
  final Map<String, Uint8List?> miniThumbnailCache;
  final Function(int) onTap;

  /// When set, occurrences of this query within the title are emphasized.
  ///
  /// Defaults to null so non-search call sites render plain titles.
  final String? highlightQuery;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.currentFolderId,
    required this.fileExistsCache,
    required this.miniThumbnailCache,
    required this.onTap,
    this.highlightQuery,
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
                        child: _ChatTitle(
                          title: title,
                          unreadCount: unreadCount,
                          highlightQuery: highlightQuery,
                        ),
                      ),
                      if (lastMessage != null)
                        Text(
                          _formatTime(lastMessage['date'] as int),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_previewIcon(lastMessage) != null) ...[
                        Icon(
                          _previewIcon(lastMessage),
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _getMessagePreview(lastMessage),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Badge(
                            label: Text(unreadCount > 999 ? '999+' : '$unreadCount'),
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

  /// A leading icon describing the last message's type, or null for plain text.
  IconData? _previewIcon(Map<String, dynamic>? lastMessage) {
    switch (lastMessage?['content']?['@type'] as String?) {
      case 'MessagePhoto':
        return Icons.photo_outlined;
      case 'MessageVideo':
        return Icons.videocam_outlined;
      case 'MessageVoiceNote':
        return Icons.mic_none;
      case 'MessageDocument':
        return Icons.insert_drive_file_outlined;
      case 'MessageSticker':
        return Icons.emoji_emotions_outlined;
      case 'MessageAnimation':
        return Icons.gif_box_outlined;
      default:
        return null;
    }
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
        return 'Photo';
      case 'MessageVideo':
        return 'Video';
      case 'MessageVoiceNote':
        return 'Voice message';
      case 'MessageDocument':
        return 'Document';
      case 'MessageSticker':
        return 'Sticker';
      case 'MessageAnimation':
        return 'GIF';
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

/// Chat title that optionally emphasizes the substring matching a search query.
class _ChatTitle extends StatelessWidget {
  const _ChatTitle({
    required this.title,
    required this.unreadCount,
    this.highlightQuery,
  });

  final String title;
  final int unreadCount;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
    );

    final query = highlightQuery?.trim() ?? '';
    if (query.isEmpty) {
      return Text(
        title,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final start = title.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      return Text(
        title,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (start > 0) TextSpan(text: title.substring(0, start)),
          TextSpan(
            text: title.substring(start, end),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (end < title.length) TextSpan(text: title.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
