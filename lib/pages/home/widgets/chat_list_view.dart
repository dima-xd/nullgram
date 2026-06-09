import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'chat_list_item.dart';

class ChatListView extends StatefulWidget {
  final ValueNotifier<Map<int, Map<String, dynamic>>> chatsNotifier;
  final int? folderId;
  final Map<String, bool> fileExistsCache;
  final Map<String, Uint8List?> miniThumbnailCache;
  final Function(int) onChatTap;

  /// Whether the initial chat sync is still in progress. While loading and the
  /// list is empty, skeleton rows are shown instead of the empty state.
  final ValueNotifier<bool>? isLoading;

  const ChatListView({
    super.key,
    required this.chatsNotifier,
    required this.folderId,
    required this.fileExistsCache,
    required this.miniThumbnailCache,
    required this.onChatTap,
    this.isLoading,
  });

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  @override
  void initState() {
    super.initState();
    widget.chatsNotifier.addListener(_onChatsUpdated);
    widget.isLoading?.addListener(_onChatsUpdated);
  }

  @override
  void dispose() {
    widget.chatsNotifier.removeListener(_onChatsUpdated);
    widget.isLoading?.removeListener(_onChatsUpdated);
    super.dispose();
  }

  void _onChatsUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final chats = _getFilteredAndSortedChats();

    if (chats.isEmpty) {
      if (widget.isLoading?.value ?? false) {
        return const _ChatListSkeleton();
      }
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No chats yet',
        subtitle: 'Your conversations will appear here.',
        lottieAsset: 'assets/lottie/empty.json',
      );
    }

    return ListView.separated(
      key: PageStorageKey('chat_list_${widget.folderId}'),
      itemCount: chats.length,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 80,
      ),
      addAutomaticKeepAlives: true,
      cacheExtent: 1000,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 72,
        endIndent: 16,
      ),
      itemBuilder: (context, index) => ChatListItem(
        chat: chats[index],
        currentFolderId: widget.folderId,
        fileExistsCache: widget.fileExistsCache,
        miniThumbnailCache: widget.miniThumbnailCache,
        onTap: widget.onChatTap,
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredAndSortedChats() {
    var allChats = widget.chatsNotifier.value.values.toList();

    if (widget.folderId != null && widget.folderId != -1) {
      allChats = allChats
          .where((chat) => (chat['folderIds'] as List?)?.contains(widget.folderId) ?? false)
          .toList();
    }

    allChats.sort((a, b) {
      final aPositions = a['positions'] as List<dynamic>?;
      final bPositions = b['positions'] as List<dynamic>?;

      Map<String, dynamic>? aPosition = aPositions?.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['list']?['chatFolderId'] == widget.folderId,
        orElse: () => null,
      );

      Map<String, dynamic>? bPosition = bPositions?.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['list']?['chatFolderId'] == widget.folderId,
        orElse: () => null,
      );

      final aIsPinned = aPosition?['isPinned'] as bool? ?? false;
      final bIsPinned = bPosition?['isPinned'] as bool? ?? false;

      if (aIsPinned != bIsPinned) return bIsPinned ? 1 : -1;

      if (aIsPinned && bIsPinned) {
        final aOrder = int.tryParse(aPosition?['order']?.toString() ?? '0') ?? 0;
        final bOrder = int.tryParse(bPosition?['order']?.toString() ?? '0') ?? 0;
        return bOrder.compareTo(aOrder);
      }

      final aDate = a['lastMessage']?['date'] as int? ?? 0;
      final bDate = b['lastMessage']?['date'] as int? ?? 0;
      return bDate.compareTo(aDate);
    });

    return allChats;
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
