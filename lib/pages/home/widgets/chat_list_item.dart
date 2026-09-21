import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/td_bytes.dart';
import '../../chat/widgets/chat_avatar.dart';
import '../../chat/widgets/emoji_status.dart';

/// One row of a chat list: avatar, title, last-message preview and the
/// unread/muted/pinned indicators Telegram shows in the same places.
class ChatListItem extends StatelessWidget {
  final Map<String, dynamic> chat;

  /// The list this row is being shown in, which decides whether the pin badge
  /// and pin ordering refer to the main list, the archive or a folder.
  final ChatListKind kind;
  final int? folderId;

  final void Function(int chatId) onTap;
  final void Function(Map<String, dynamic> chat)? onLongPress;

  /// When set, occurrences of this query within the title are emphasized.
  ///
  /// Defaults to null so non-search call sites render plain titles.
  final String? highlightQuery;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
    this.kind = ChatListKind.main,
    this.folderId,
    this.onLongPress,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatId = chat['id'] as int;
    final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
    final draft = chat['draftMessage'] as Map<String, dynamic>?;
    final unreadCount = chat['unreadCount'] as int? ?? 0;
    final mentionCount = chat['unreadMentionCount'] as int? ?? 0;
    final markedUnread = chat['isMarkedAsUnread'] == true;
    final muted = isChatMuted(chat);
    final hasUnread = unreadCount > 0 || markedUnread;

    final position = ChatStore.positionIn(chat, kind, folderId: folderId);
    final isPinned = position?['isPinned'] == true;

    return InkWell(
      key: ValueKey('chat_$chatId'),
      onTap: () => onTap(chatId),
      onLongPress:
          onLongPress == null ? null : () => onLongPress!(chat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(child: ChatAvatar(chat: chat, radius: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // One flexible child only: a Spacer here would be a
                      // second one and split the free space with the title,
                      // cutting long names in half.
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _ChatTitle(
                                title: chat['title'] as String? ?? 'Unknown',
                                hasUnread: hasUnread,
                                highlightQuery: highlightQuery,
                              ),
                            ),
                            EmojiStatusBadge(chat: chat, size: 15),
                          ],
                        ),
                      ),
                      if (muted)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.volume_off,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (lastMessage != null) ...[
                        const SizedBox(width: 6),
                        if (lastMessage['isOutgoing'] == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Icon(
                              _isRead(lastMessage) ? Icons.done_all : Icons.done,
                              size: 15,
                              color: scheme.primary,
                            ),
                          ),
                        Text(
                          _formatTime(
                            lastMessage['date'] as int,
                            Localizations.localeOf(context).toLanguageTag(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (draft == null &&
                          chat['lastMessageAlbum'] == null &&
                          _previewIcon(lastMessage) != null) ...[
                        Icon(
                          _previewIcon(lastMessage),
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: _Preview(
                          chat: chat,
                          lastMessage: lastMessage,
                          draft: draft,
                          hasUnread: hasUnread,
                        ),
                      ),
                      if (mentionCount > 0)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Badge(label: Text('@')),
                        ),
                      if (hasUnread)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Badge(
                            backgroundColor:
                                muted ? scheme.outline : scheme.primary,
                            label: Text(
                              unreadCount == 0
                                  ? ' '
                                  : unreadCount > 999
                                      ? '999+'
                                      : '$unreadCount',
                            ),
                          ),
                        )
                      else if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.push_pin,
                            size: 15,
                            color: scheme.onSurfaceVariant,
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

  /// Whether the peer has read our own last message. TDLib reports this as the
  /// highest message id the other side has seen, so anything at or below it is
  /// read.
  bool _isRead(Map<String, dynamic> lastMessage) {
    final lastRead = chat['lastReadOutboxMessageId'] as int? ?? 0;
    return (lastMessage['id'] as int? ?? 0) <= lastRead;
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
      case 'MessageVideoNote':
        return Icons.video_camera_front_outlined;
      case 'MessageAudio':
        return Icons.music_note_outlined;
      case 'MessageDocument':
        return Icons.insert_drive_file_outlined;
      case 'MessageSticker':
        return Icons.emoji_emotions_outlined;
      case 'MessageAnimation':
        return Icons.gif_box_outlined;
      case 'MessageCall':
        return Icons.call_outlined;
      case 'MessagePoll':
        return Icons.poll_outlined;
      case 'MessageLocation':
      case 'MessageVenue':
        return Icons.location_on_outlined;
      default:
        return null;
    }
  }

  /// Today's messages show a clock, this year's a day and month, older ones a
  /// numeric date — all in the app's locale rather than hand-rolled English.
  String _formatTime(int timestamp, String locale) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat.Hm(locale).format(date);
    }
    if (date.year == now.year) return DateFormat.MMMd(locale).format(date);
    return DateFormat.yMd(locale).format(date);
  }
}

/// The second line of a chat row: the unsent draft when there is one, else the
/// last message, prefixed with its sender in group chats.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.chat,
    required this.lastMessage,
    required this.draft,
    required this.hasUnread,
  });

  final Map<String, dynamic> chat;
  final Map<String, dynamic>? lastMessage;
  final Map<String, dynamic>? draft;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
    );

    if (draft != null) {
      final text = draft?['inputMessageText']?['text']?['text'] as String?;
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: 'Draft: ',
              style: TextStyle(color: scheme.error),
            ),
            TextSpan(text: text ?? ''),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final prefix = _senderPrefix();
    final album = chat['lastMessageAlbum'] as List?;

    if (album != null && album.isNotEmpty) {
      final members = List<Map<String, dynamic>>.from(album);
      if (prefix == null) {
        return _AlbumPreview(members: members, style: style);
      }
      // Keep the "You:" / sender prefix outside the album span, so the
      // thumbnails still line up after it.
      return Row(
        children: [
          Text('$prefix: ', style: style?.copyWith(color: scheme.onSurface)),
          Expanded(child: _AlbumPreview(members: members, style: style)),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (prefix != null)
            TextSpan(
              text: '$prefix: ',
              style: TextStyle(color: scheme.onSurface),
            ),
          TextSpan(text: messagePreviewText(lastMessage)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// "You" for our own messages, or the sender's name in a group; null in a
  /// private chat where the sender is implied by the row itself.
  String? _senderPrefix() {
    final message = lastMessage;
    if (message == null) return null;
    if (message['isOutgoing'] == true) return 'You';

    final chatType = chat['type']?['@type'];
    final isGroup = chatType == 'ChatTypeBasicGroup' ||
        (chatType == 'ChatTypeSupergroup' &&
            chat['type']?['isChannel'] != true);
    if (!isGroup) return null;

    // TDLib sends an empty authorSignature rather than null for most group
    // messages, which `??` would happily pass through as a bare ": ".
    final signature = message['authorSignature'] as String?;
    if (signature != null && signature.isNotEmpty) return signature;

    final name = _senderName(message['senderId']);
    return (name == null || name.isEmpty) ? null : name;
  }

  String? _senderName(dynamic senderId) {
    if (senderId is! Map) return null;
    if (senderId['@type'] != 'MessageSenderUser') return null;
    return ChatStore.instance.userName(senderId['userId'] as int);
  }
}

/// A short human-readable description of a message's content.
String messagePreviewText(Map<String, dynamic>? message) {
  final content = message?['content'] as Map<String, dynamic>?;
  if (content == null) return '';

  final caption = content['caption']?['text'] as String?;

  // An album member without the caption would otherwise read as a lone
  // "Photo", which is what makes an unresolved album row look wrong.
  if (ChatStore.albumIdOf(message) != null &&
      (caption == null || caption.isEmpty)) {
    return 'Album';
  }

  switch (content['@type'] as String?) {
    case 'MessageText':
      return content['text']?['text'] as String? ?? '';
    case 'MessagePhoto':
      return caption?.isNotEmpty == true ? caption! : 'Photo';
    case 'MessageVideo':
      return caption?.isNotEmpty == true ? caption! : 'Video';
    case 'MessageVoiceNote':
      return 'Voice message';
    case 'MessageVideoNote':
      return 'Video message';
    case 'MessageAudio':
      return 'Audio';
    case 'MessageDocument':
      return caption?.isNotEmpty == true ? caption! : 'Document';
    case 'MessageSticker':
      return '${content['sticker']?['emoji'] ?? ''} Sticker';
    case 'MessageAnimation':
      return 'GIF';
    case 'MessagePoll':
      return content['poll']?['question']?['text'] as String? ?? 'Poll';
    case 'MessageLocation':
      return 'Location';
    case 'MessageVenue':
      return content['venue']?['title'] as String? ?? 'Location';
    case 'MessageContact':
      return 'Contact';
    case 'MessageCall':
      return content['isVideo'] == true ? 'Video call' : 'Call';
    case 'MessageChatJoinByLink':
      return 'joined the chat';
    case 'MessageChatAddMembers':
      return 'joined the chat';
    case 'MessageChatDeleteMember':
      return 'left the chat';
    case 'MessagePinMessage':
      return 'pinned a message';
    case 'MessageChatChangeTitle':
      return 'changed the chat title';
    case 'MessageChatChangePhoto':
      return 'changed the chat photo';
    default:
      return 'Message';
  }
}


/// The chat-list preview for an album: a few tiny thumbnails followed by the
/// album's caption.
///
/// Telegram treats an album as several messages that share a `mediaAlbumId`,
/// and only one of them carries the caption. Showing the caption next to the
/// thumbnails is what makes an album row readable — the last member on its own
/// says nothing but "Photo".
class _AlbumPreview extends StatelessWidget {
  const _AlbumPreview({
    required this.members,
    required this.style,
  });

  final List<Map<String, dynamic>> members;
  final TextStyle? style;

  /// How many thumbnails fit before the text without crowding the row.
  static const int _maxThumbnails = 3;
  static const double _thumbnailSize = 16;

  @override
  Widget build(BuildContext context) {
    final thumbnails = [
      for (final member in members.take(_maxThumbnails))
        if (albumThumbnailBytes(member) case final bytes?) bytes,
    ];

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final bytes in thumbnails)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.memory(
                    bytes,
                    width: _thumbnailSize,
                    height: _thumbnailSize,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          if (thumbnails.isNotEmpty) const TextSpan(text: ' '),
          TextSpan(text: _albumText()),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The album's caption, or a count when nobody wrote one.
  String _albumText() {
    for (final member in members) {
      final caption = member['content']?['caption']?['text'] as String?;
      if (caption != null && caption.isNotEmpty) return caption;
    }
    return '${members.length} ${_kindLabel()}';
  }

  /// What the album is made of, so the fallback reads "4 photos" rather than
  /// the generic "Album".
  String _kindLabel() {
    final types = {
      for (final member in members) member['content']?['@type'] as String?,
    };
    if (types.length == 1) {
      return switch (types.single) {
        'MessagePhoto' => members.length == 1 ? 'photo' : 'photos',
        'MessageVideo' => members.length == 1 ? 'video' : 'videos',
        'MessageDocument' => members.length == 1 ? 'file' : 'files',
        'MessageAudio' => members.length == 1 ? 'track' : 'tracks',
        _ => 'items',
      };
    }
    return 'items';
  }
}

/// The minithumbnail of an album member, whatever media it holds.
///
/// TDLib nests the minithumbnail under the content's own media field, which is
/// named differently per type.
Uint8List? albumThumbnailBytes(Map<String, dynamic> message) {
  final content = message['content'] as Map<String, dynamic>?;
  final media = content?['photo'] ??
      content?['video'] ??
      content?['document'] ??
      content?['audio'] ??
      content?['animation'];
  return TdBytes.decode(media?['minithumbnail']?['data']);
}

/// Chat title that optionally emphasizes the substring matching a search query.
class _ChatTitle extends StatelessWidget {
  const _ChatTitle({
    required this.title,
    required this.hasUnread,
    this.highlightQuery,
  });

  final String title;
  final bool hasUnread;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
    );

    final query = highlightQuery?.trim() ?? '';
    final start =
        query.isEmpty ? -1 : title.toLowerCase().indexOf(query.toLowerCase());

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
