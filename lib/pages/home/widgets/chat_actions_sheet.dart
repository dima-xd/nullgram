import 'package:flutter/material.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The long-press action sheet for a chat row.
///
/// Every action is applied straight away through TDLib; the resulting updates
/// flow back into [ChatStore], so nothing here has to touch view state.
Future<void> showChatActionsSheet({
  required BuildContext context,
  required Map<String, dynamic> chat,
  required ChatListKind kind,
  int? folderId,
}) async {
  final chatId = chat['id'] as int;
  final muted = isChatMuted(chat);
  final position = ChatStore.positionIn(chat, kind, folderId: folderId);
  final isPinned = position?['isPinned'] == true;
  final isArchived = kind == ChatListKind.archive;
  final hasUnread = (chat['unreadCount'] as int? ?? 0) > 0 ||
      chat['isMarkedAsUnread'] == true;
  final chatType = chat['type']?['@type'] as String?;
  final isPrivate =
      chatType == 'ChatTypePrivate' || chatType == 'ChatTypeSecret';

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              chat['title'] as String? ?? 'Chat',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            dense: true,
          ),
          const Divider(height: 1),
          _Action(
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: isPinned ? 'Unpin' : 'Pin to top',
            onTap: () => TDLibClient.toggleChatIsPinned(
              chatId: chatId,
              isPinned: !isPinned,
              archived: isArchived,
            ),
          ),
          _Action(
            icon: muted ? Icons.volume_up : Icons.volume_off,
            label: muted ? 'Unmute' : 'Mute',
            onTap: () => TDLibClient.setChatNotificationSettings(
              chatId: chatId,
              muteFor: muted ? 0 : TDLibClient.muteForever,
            ),
          ),
          _Action(
            icon: hasUnread
                ? Icons.mark_chat_read_outlined
                : Icons.mark_chat_unread_outlined,
            label: hasUnread ? 'Mark as read' : 'Mark as unread',
            onTap: () async {
              if (hasUnread) {
                final lastMessageId = chat['lastMessage']?['id'] as int?;
                if (lastMessageId != null) {
                  await TDLibClient.viewMessages(
                    chatId: chatId,
                    messageIds: [lastMessageId],
                  );
                }
                await TDLibClient.toggleChatIsMarkedAsUnread(
                  chatId: chatId,
                  isMarkedAsUnread: false,
                );
              } else {
                await TDLibClient.toggleChatIsMarkedAsUnread(
                  chatId: chatId,
                  isMarkedAsUnread: true,
                );
              }
            },
          ),
          _Action(
            icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: isArchived ? 'Remove from archive' : 'Archive',
            onTap: () => TDLibClient.addChatToList(
              chatId: chatId,
              archived: !isArchived,
            ),
          ),
          const Divider(height: 1),
          _Action(
            icon: Icons.cleaning_services_outlined,
            label: context.l10n.clearHistory,
            destructive: true,
            confirm: (
              title: context.l10n.clearHistoryQuestion,
              body: 'All messages in this chat will be removed for you.',
              action: 'Clear',
            ),
            onTap: () => TDLibClient.deleteChatHistory(chatId: chatId),
          ),
          _Action(
            icon: Icons.delete_outline,
            label: isPrivate ? 'Delete chat' : 'Leave chat',
            destructive: true,
            confirm: (
              title: isPrivate ? 'Delete chat?' : 'Leave chat?',
              body: isPrivate
                  ? 'The chat and its history will be removed for you.'
                  : 'You will stop receiving messages from this chat.',
              action: isPrivate ? 'Delete' : 'Leave',
            ),
            onTap: () async {
              if (isPrivate) {
                await TDLibClient.deleteChatHistory(
                  chatId: chatId,
                  removeFromChatList: true,
                );
              } else {
                await TDLibClient.leaveChat(chatId: chatId);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// A confirmation prompt for a destructive action.
typedef _Confirmation = ({String title, String body, String action});

/// One row of the sheet. Closes the sheet before running [onTap] so the action
/// never races the closing animation, and asks for confirmation first when
/// [confirm] is set.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.confirm,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool destructive;
  final _Confirmation? confirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : null;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () async {
        final navigator = Navigator.of(context);
        final prompt = confirm;
        if (prompt != null && !await _ask(context, prompt)) return;
        navigator.pop();
        await onTap();
      },
    );
  }

  Future<bool> _ask(BuildContext context, _Confirmation prompt) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(prompt.title),
        content: Text(prompt.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(prompt.action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
