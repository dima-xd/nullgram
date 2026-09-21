import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/album_bubble.dart';
import 'package:nullgram/pages/chat/widgets/date_separator.dart';
import 'package:nullgram/pages/chat/widgets/message_bubble.dart';
import 'package:nullgram/pages/chat/widgets/thread_divider.dart';
import 'package:nullgram/services/message_history.dart';
import 'package:nullgram/widgets/empty_state.dart';

/// What a message list hands back to the page around it.
class MessageListCallbacks {
  const MessageListCallbacks({
    this.onLongPress,
    this.onTap,
    this.onReactionTap,
    this.onReplyTap,
    this.onThreadTap,
  });

  final void Function(Map<String, dynamic> message)? onLongPress;
  final void Function(Map<String, dynamic> message)? onTap;
  final void Function(
    Map<String, dynamic> message,
    Map<String, dynamic> reactionType,
  )? onReactionTap;

  /// Called with the id of the message a reply quote points at.
  final void Function(int messageId)? onReplyTap;

  /// Called when the "N comments" / "N replies" footer is tapped.
  final void Function(Map<String, dynamic> message)? onThreadTap;
}

/// The scrolling message list: paging, sender grouping, date separators and
/// the unread divider.
///
/// Knows nothing about which chat or thread it shows — that is the [history]
/// it is handed.
class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.history,
    required this.chat,
    required this.scrollController,
    required this.callbacks,
    this.selection,
    this.lastReadOnOpen = 0,
    this.emptyTitle,
    this.emptySubtitle,
    this.leadingMessages = const [],
    this.leadingSeparatorLabel,
    this.leadingEmptyLabel,
  });

  final MessageHistoryController history;

  /// The chat the bubbles are drawn against, for sender names and read state.
  final Map<String, dynamic> chat;

  final ScrollController scrollController;
  final MessageListCallbacks callbacks;

  /// Selected message ids while selection mode is on, else null.
  final Set<int>? selection;

  /// The last message read before this visit, which anchors the unread
  /// divider. 0 hides it.
  final int lastReadOnOpen;

  final String? emptyTitle;
  final String? emptySubtitle;

  /// Messages pinned to the top of the list, above all history and scrolling
  /// with it — a thread's root post. Newest first, like [history].
  final List<Map<String, dynamic>> leadingMessages;

  /// The label on the pill between [leadingMessages] and the history.
  final String? leadingSeparatorLabel;

  /// The label that pill carries while the history is still empty.
  final String? leadingEmptyLabel;

  /// A stable per-sender key used to group consecutive messages. Albums never
  /// group with anything, so each gets a unique key.
  String _senderKey(Map<String, dynamic> message) {
    if (message['isAlbum'] == true) return 'album_${message['id']}';
    final sender = message['senderId'];
    final id = sender?['userId'] ?? sender?['chatId'];
    if (id != null) return 'id_$id';
    return message['isOutgoing'] == true ? 'me' : 'other';
  }

  /// Two messages belong to the same group if from the same sender and sent
  /// within five minutes of each other.
  bool _sameGroup(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return false;
    if (a['isAlbum'] == true || b['isAlbum'] == true) return false;
    if (_senderKey(a) != _senderKey(b)) return false;
    final da = a['date'] as int? ?? 0;
    final db = b['date'] as int? ?? 0;
    return (da - db).abs() <= 300;
  }

  /// Whether [message] is the oldest one the user had not read when the page
  /// was opened, which is where the unread divider belongs.
  bool _isFirstUnread(
    Map<String, dynamic> message,
    Map<String, dynamic>? older,
  ) {
    if (lastReadOnOpen == 0) return false;
    if (message['isOutgoing'] == true) return false;
    final id = message['id'] as int? ?? 0;
    if (id <= lastReadOnOpen) return false;
    return older == null || (older['id'] as int? ?? 0) <= lastReadOnOpen;
  }

  Widget _buildBubble({
    required Map<String, dynamic> message,
    required bool isFirstInGroup,
    required bool isLastInGroup,
    bool isThreadHeader = false,
  }) {
    if (message['isAlbum'] == true) {
      return AlbumBubble(
        albumMessages: AlbumsGrouper.membersOf(message),
        chat: chat,
        onLongPress: callbacks.onLongPress,
        onReactionTap: callbacks.onReactionTap,
      );
    }

    return MessageBubble(
      message: message,
      chat: chat,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      isSelected: selection?.contains(message['id']) ?? false,
      onLongPress: callbacks.onLongPress,
      onTap: selection == null ? null : callbacks.onTap,
      onReactionTap: callbacks.onReactionTap,
      onReplyTap: callbacks.onReplyTap,
      onThreadTap: callbacks.onThreadTap,
      isThreadHeader: isThreadHeader,
    );
  }

  /// One of [leadingMessages], drawn as the post a thread hangs off rather
  /// than as another message, with the comments rule below the newest of them.
  ///
  /// The list is reversed, so a higher index sits higher on screen. No date
  /// pill: the post heads the screen, it is not a day boundary.
  Widget _buildLeading(int index, {required bool hasHistory}) {
    final newer = index - 1 >= 0 ? leadingMessages[index - 1] : null;
    final label = hasHistory ? leadingSeparatorLabel : leadingEmptyLabel;

    return Column(
      children: [
        _buildBubble(
          message: leadingMessages[index],
          isFirstInGroup: true,
          isLastInGroup: true,
          isThreadHeader: true,
        ),
        if (newer == null && label != null) ThreadDivider(label: label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: history,
      builder: (context, child) {
        final messages = history.messages;
        final isLoading = history.isLoading;

        if (messages.isEmpty && leadingMessages.isEmpty && !isLoading) {
          return EmptyState(
            icon: Icons.forum_outlined,
            title: emptyTitle ?? context.l10n.noMessagesYet,
            subtitle: emptySubtitle ?? context.l10n.chatEmptyHint,
            lottieAsset: 'assets/lottie/empty.json',
          );
        }

        final spinnerCount = isLoading ? 1 : 0;

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          itemCount: messages.length + spinnerCount + leadingMessages.length,
          itemBuilder: (context, index) {
            if (isLoading && index == messages.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            // Everything past the history and its spinner is the leading
            // block, which sits at the very top of the reversed list.
            if (index >= messages.length + spinnerCount) {
              return _buildLeading(
                index - messages.length - spinnerCount,
                hasHistory: messages.isNotEmpty,
              );
            }

            final message = messages[index];

            // Prefetch older history well before the user reaches the end.
            if (index >= messages.length - 20 &&
                !isLoading &&
                history.hasMore) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => history.loadMore(),
              );
            }

            // In a reverse list, lower indices are newer. "Older" sits above
            // (next index), "newer" below (previous index).
            final older =
                index + 1 < messages.length ? messages[index + 1] : null;
            final newer = index - 1 >= 0 ? messages[index - 1] : null;

            final bubble = _buildBubble(
              message: message,
              isFirstInGroup: !_sameGroup(message, older),
              isLastInGroup: !_sameGroup(message, newer),
            );

            final showDateSeparator =
                older == null ||
                !MessageFormatter.isSameDay(
                  message['date'] as int,
                  older['date'] as int,
                );
            final showUnreadDivider = _isFirstUnread(message, older);
            if (!showDateSeparator && !showUnreadDivider) return bubble;

            return Column(
              children: [
                if (showDateSeparator)
                  DateSeparator(
                    label: MessageFormatter.formatDateSeparator(
                      message['date'] as int,
                    ),
                  ),
                if (showUnreadDivider) const UnreadDivider(),
                bubble,
              ],
            );
          },
        );
      },
    );
  }
}
