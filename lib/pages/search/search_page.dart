import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/lottie_state.dart';

/// Global chat search: type a query, see matching chats, tap to open one.
///
/// Queries [TDLibClient.searchChats] (debounced) and resolves each result to a
/// full chat via [TDLibClient.getChat], reusing [ChatListItem] for the rows.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController _controller = SearchController();
  final ValueNotifier<List<Map<String, dynamic>>> _results = ValueNotifier([]);
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<String> _query = ValueNotifier('');

  // Shared caches required by ChatListItem; empty here since search rows are
  // transient and avatars re-resolve from the chat's own file paths.
  final Map<String, bool> _fileExistsCache = {};
  final Map<String, Uint8List?> _miniThumbnailCache = {};

  Timer? _debounce;
  int _queryToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _results.dispose();
    _isSearching.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _query.value = query;
    if (query.isEmpty) {
      _results.value = [];
      _isSearching.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_queryToken;
    _isSearching.value = true;
    try {
      final chatIds = await TDLibClient.searchChats(query: query);
      // Resolve all chats concurrently while preserving the result ordering.
      final resolved = await Future.wait(
        chatIds.map((id) => TDLibClient.getChat(chatId: id)),
      );
      // A newer query started while we were awaiting; drop these stale results.
      if (token != _queryToken || !mounted) return;
      _results.value = [
        for (final chat in resolved)
          if (chat != null) chat,
      ];
    } finally {
      if (token == _queryToken && mounted) _isSearching.value = false;
    }
  }

  void _openChat(int chatId) {
    final chat = _results.value.firstWhere(
      (c) => c['id'] == chatId,
      orElse: () => const {},
    );
    if (chat.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _controller,
          autoFocus: true,
          hintText: 'Search chats...',
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          leading: const Icon(Icons.search),
          trailing: [
            ValueListenableBuilder<String>(
              valueListenable: _query,
              builder: (context, query, child) {
                if (query.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                );
              },
            ),
          ],
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isSearching,
        builder: (context, isSearching, child) {
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _results,
            builder: (context, results, child) {
              if (results.isEmpty) {
                return _SearchPlaceholder(
                  isSearching: isSearching,
                  query: _query.value,
                );
              }
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) => ChatListItem(
                  chat: results[index],
                  currentFolderId: null,
                  fileExistsCache: _fileExistsCache,
                  miniThumbnailCache: _miniThumbnailCache,
                  onTap: _openChat,
                  highlightQuery: _query.value,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The state shown while there are no results: prompt, spinner, or empty set.
class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder({required this.isSearching, required this.query});

  final bool isSearching;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Center(
        child: LottieState(
          asset: 'assets/lottie/loading.json',
          fallbackIcon: Icons.search,
          size: 90,
        ),
      );
    }
    if (query.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search chats',
        subtitle: 'Type a name to find a chat.',
      );
    }
    return const EmptyState(
      icon: Icons.search_off,
      title: 'No chats found',
      subtitle: 'Try a different search term.',
    );
  }
}
