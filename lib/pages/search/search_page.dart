import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

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
  final TextEditingController _controller = TextEditingController();
  final ValueNotifier<List<Map<String, dynamic>>> _results = ValueNotifier([]);
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);

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
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
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
      final chats = <Map<String, dynamic>>[];
      for (final id in chatIds) {
        final chat = await TDLibClient.getChat(chatId: id);
        if (chat != null) chats.add(chat);
      }
      // A newer query started while we were awaiting; drop these stale results.
      if (token != _queryToken || !mounted) return;
      _results.value = chats;
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
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search chats...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isSearching,
        builder: (context, isSearching, child) {
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _results,
            builder: (context, results, child) {
              if (results.isEmpty) {
                return Center(
                  child: Text(
                    isSearching
                        ? 'Searching...'
                        : _controller.text.trim().isEmpty
                            ? 'Type to search chats'
                            : 'No chats found',
                  ),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
