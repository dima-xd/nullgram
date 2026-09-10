import 'package:flutter/material.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/l10n/l10n.dart';

/// What the chat's overflow menu asked for.
enum ChatMenuAction {
  openProfile,
  search,
  selectMessages,
  scheduledMessages,
  toggleMute,
  autoDelete,
  clearHistory,
  toggleBlock,
  deleteChat,
  leaveChat,
}

/// Opens the chat's overflow menu and resolves to the chosen action.
///
/// Only the state-free actions are decided here; the caller applies them, since
/// several need chat state or navigation it owns.
Future<ChatMenuAction?> showChatMenu({
  required BuildContext context,
  required Map<String, dynamic> chat,
  required bool isBlocked,
}) {
  final muted = isChatMuted(chat);
  final chatType = chat['type']?['@type'] as String?;
  final isPrivate =
      chatType == 'ChatTypePrivate' || chatType == 'ChatTypeSecret';
  final isSaved = chat['id'] == chat['type']?['userId'] &&
      chat['type']?['@type'] == 'ChatTypePrivate' &&
      chat['isSavedMessages'] == true;

  return showModalBottomSheet<ChatMenuAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Item(
            icon: Icons.info_outline,
            label: isPrivate ? 'View profile' : 'Chat info',
            action: ChatMenuAction.openProfile,
          ),
          _Item(
            icon: Icons.search,
            label: context.l10n.searchInChat,
            action: ChatMenuAction.search,
          ),
          _Item(
            icon: Icons.checklist,
            label: context.l10n.selectMessages,
            action: ChatMenuAction.selectMessages,
          ),
          _Item(
            icon: Icons.schedule_send_outlined,
            label: context.l10n.scheduledMessages,
            action: ChatMenuAction.scheduledMessages,
          ),
          _Item(
            icon: muted ? Icons.volume_up : Icons.volume_off,
            label: muted ? 'Unmute' : 'Mute',
            action: ChatMenuAction.toggleMute,
          ),
          _Item(
            icon: Icons.auto_delete_outlined,
            label: autoDeleteLabel(sheetContext, chat),
            action: ChatMenuAction.autoDelete,
          ),
          const Divider(height: 1),
          _Item(
            icon: Icons.cleaning_services_outlined,
            label: context.l10n.clearHistory,
            action: ChatMenuAction.clearHistory,
            destructive: true,
          ),
          if (isPrivate && !isSaved)
            _Item(
              icon: isBlocked ? Icons.lock_open : Icons.block,
              label: isBlocked ? 'Unblock user' : 'Block user',
              action: ChatMenuAction.toggleBlock,
              destructive: !isBlocked,
            ),
          if (isPrivate)
            _Item(
              icon: Icons.delete_outline,
              label: context.l10n.deleteChat,
              action: ChatMenuAction.deleteChat,
              destructive: true,
            )
          else
            _Item(
              icon: Icons.logout,
              label: context.l10n.leaveChat,
              action: ChatMenuAction.leaveChat,
              destructive: true,
            ),
        ],
      ),
    ),
  );
}

/// The menu label for the chat's self-destruct timer, stating the current
/// setting so the menu itself answers "is this on?".
String autoDeleteLabel(BuildContext context, Map<String, dynamic> chat) {
  final seconds = (chat['messageAutoDeleteTime'] as num?)?.toInt() ?? 0;
  if (seconds <= 0) return context.l10n.autoDeleteOff;
  if (seconds % 86400 == 0) {
    return context.l10n.autoDeleteAfterDays(seconds ~/ 86400);
  }
  return context.l10n.autoDeleteOn;
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final ChatMenuAction action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

/// Whether the peer of a private chat is currently blocked.
///
/// TDLib exposes this only through the blocked-senders list, so it is looked up
/// once when the chat opens.
Future<bool> isUserBlocked(int userId) async {
  final blocked = await TDLibClient.getBlockedMessageSenders();
  return blocked.any(
    (sender) =>
        sender['@type'] == 'MessageSenderUser' && sender['userId'] == userId,
  );
}
