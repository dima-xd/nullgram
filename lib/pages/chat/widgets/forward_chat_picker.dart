import 'package:flutter/material.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Presents a bottom sheet listing the user's chats and resolves to the chat
/// id chosen as a forward destination, or null if dismissed.
Future<int?> showForwardChatPicker(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ForwardChatPicker(),
  );
}

class _ForwardChatPicker extends StatefulWidget {
  const _ForwardChatPicker();

  @override
  State<_ForwardChatPicker> createState() => _ForwardChatPickerState();
}

class _ForwardChatPickerState extends State<_ForwardChatPicker> {
  final ValueNotifier<List<Map<String, dynamic>>> _chats = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<String> _filter = ValueNotifier('');
  final SearchController _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    // The store already holds every chat in list order, so the picker opens
    // instantly instead of re-resolving each chat over the bridge.
    _chats.value =
        ChatStore.instance.visibleChats(kind: ChatListKind.main);
    _isLoading.value = false;
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> chats,
    String filter,
  ) {
    final query = filter.trim().toLowerCase();
    if (query.isEmpty) return chats;
    return [
      for (final chat in chats)
        if (((chat['title'] as String?) ?? '').toLowerCase().contains(query))
          chat,
    ];
  }

  @override
  void dispose() {
    _chats.dispose();
    _isLoading.dispose();
    _filter.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.forwardTo, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SearchBar(
                    controller: _searchController,
                    hintText: context.l10n.searchChatsHint,
                    leading: const Icon(Icons.search),
                    onChanged: (value) => _filter.value = value,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoading,
                builder: (context, isLoading, child) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _chats,
                    builder: (context, chats, child) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _filter,
                        builder: (context, filter, child) {
                          final visible = _applyFilter(chats, filter);
                          if (visible.isEmpty) {
                            return EmptyState(
                              icon: Icons.search_off,
                              title: filter.trim().isEmpty
                                  ? 'No chats'
                                  : 'No chats found',
                              subtitle: filter.trim().isEmpty
                                  ? null
                                  : 'Try a different search term.',
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            padding: withBottomSafeArea(context),
                            itemCount: visible.length,
                            itemBuilder: (context, index) => ChatListItem(
                              chat: visible[index],
                              onTap: (chatId) =>
                                  Navigator.of(context).pop(chatId),
                              highlightQuery: filter,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
