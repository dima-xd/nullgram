import 'package:flutter/material.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'chat_actions_sheet.dart';
import 'chat_list_item.dart';

/// A scrolling chat list backed by [ChatStore].
///
/// Which chats appear is decided entirely by [kind] and [folderId]: the store
/// holds every known chat once, and each view filters it down to the chats
/// TDLib placed in the corresponding list.
class ChatListView extends StatelessWidget {
  final ChatListKind kind;
  final int? folderId;
  final void Function(int chatId) onChatTap;

  /// An optional row pinned above the list, used for the archive entry.
  final Widget? header;

  const ChatListView({
    super.key,
    required this.onChatTap,
    this.kind = ChatListKind.main,
    this.folderId,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final store = ChatStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final chats = store.visibleChats(kind: kind, folderId: folderId);

        if (chats.isEmpty) {
          if (store.isLoading) return const _ChatListSkeleton();
          return Column(
            children: [
              if (header != null) header!,
              const Expanded(
                child: EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No chats yet',
                  subtitle: 'Your conversations will appear here.',
                  lottieAsset: 'assets/lottie/empty.json',
                ),
              ),
            ],
          );
        }

        final headerCount = header == null ? 0 : 1;

        return ListView.separated(
          key: PageStorageKey('chat_list_${kind.name}_$folderId'),
          itemCount: chats.length + headerCount,
          // The extra room is for the compose button floating over the list.
          padding: withBottomSafeArea(
            context,
            const EdgeInsets.only(bottom: 80),
          ),
          cacheExtent: 1000,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            thickness: 0.5,
            indent: 72,
            endIndent: 16,
          ),
          itemBuilder: (context, index) {
            if (index < headerCount) return header!;
            final chat = chats[index - headerCount];
            return ChatListItem(
              chat: chat,
              kind: kind,
              folderId: folderId,
              onTap: onChatTap,
              onLongPress: (chat) => showChatActionsSheet(
                context: context,
                chat: chat,
                kind: kind,
                folderId: folderId,
              ),
            );
          },
        );
      },
    );
  }
}

/// Static placeholder rows shown while the first chat sync is in flight.
class _ChatListSkeleton extends StatelessWidget {
  const _ChatListSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.builder(
      itemCount: 9,
      padding: const EdgeInsets.symmetric(vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(radius: 24, backgroundColor: base),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(width: 140, color: base),
                  const SizedBox(height: 8),
                  _Bar(width: 220, color: base),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final Color color;

  const _Bar({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
