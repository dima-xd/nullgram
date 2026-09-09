import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/lottie_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// Global search across chats and messages.
///
/// Runs three TDLib searches per query — the user's own chats, public chats
/// they haven't joined, and message text across every chat — and splits the
/// results into a "Chats" and a "Messages" tab, the way Telegram does.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final SearchController _controller = SearchController();
  final ValueNotifier<List<Map<String, dynamic>>> _chats = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> _messages = ValueNotifier([]);
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<String> _query = ValueNotifier('');

  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  Timer? _debounce;

  /// Incremented per query so results of a superseded search are discarded.
  int _queryToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _chats.dispose();
    _messages.dispose();
    _isSearching.dispose();
    _query.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _query.value = query;
    if (query.isEmpty) {
      _queryToken++;
      _chats.value = [];
      _messages.value = [];
      _isSearching.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_queryToken;
    _isSearching.value = true;
    try {
      final results = await Future.wait([
        TDLibClient.searchChats(query: query),
        TDLibClient.searchPublicChats(query: query),
      ]);
      if (token != _queryToken || !mounted) return;

      // Own chats first, then public ones, without repeating a chat that
      // matched both searches.
      final ordered = <int>[
        ...results[0],
        ...results[1].where((id) => !results[0].contains(id)),
      ];

      final resolved = await Future.wait(
        ordered.map(
          (id) async =>
              ChatStore.instance.chat(id) ??
              await TDLibClient.getChat(chatId: id),
        ),
      );
      if (token != _queryToken || !mounted) return;
      _chats.value = [
        for (final chat in resolved)
          if (chat != null) chat,
      ];

      final found = await TDLibClient.searchMessages(query: query);
      if (token != _queryToken || !mounted) return;
      _messages.value = found?.messages ?? const [];
    } finally {
      if (token == _queryToken && mounted) _isSearching.value = false;
    }
  }

  void _openChat(int chatId) {
    final chat = _chats.value.firstWhere(
      (candidate) => candidate['id'] == chatId,
      orElse: () => const {},
    );
    if (chat.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }

  Future<void> _openMessage(Map<String, dynamic> message) async {
    final chatId = message['chatId'] as int;
    final chat = ChatStore.instance.chat(chatId) ??
        await TDLibClient.getChat(chatId: chatId);
    if (!mounted || chat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chat: chat,
          initialMessageId: message['id'] as int?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _controller,
          autoFocus: true,
          hintText: 'Search chats and messages',
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          elevation: const WidgetStatePropertyAll(0),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chats'), Tab(text: 'Messages')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatResults(), _buildMessageResults()],
      ),
    );
  }

  Widget _buildChatResults() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _chats,
      builder: (context, chats, child) {
        if (chats.isEmpty) return _placeholder('chats');
        return ListView.builder(
          padding: withBottomSafeArea(context),
          itemCount: chats.length,
          itemBuilder: (context, index) => ChatListItem(
            chat: chats[index],
            onTap: _openChat,
            highlightQuery: _query.value,
          ),
        );
      },
    );
  }

  Widget _buildMessageResults() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _messages,
      builder: (context, messages, child) {
        if (messages.isEmpty) return _placeholder('messages');
        return ListView.separated(
          padding: withBottomSafeArea(context),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final message = messages[index];
            final chat = ChatStore.instance.chat(message['chatId'] as int);
            return ListTile(
              leading: chat == null
                  ? const CircleAvatar(radius: 22, child: Icon(Icons.chat))
                  : ChatAvatar(chat: chat, radius: 22),
              title: Text(
                chat?['title'] as String? ?? 'Chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                messagePreviewText(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                MessageFormatter.formatDateSeparator(message['date'] as int),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => _openMessage(message),
            );
          },
        );
      },
    );
  }

  Widget _placeholder(String what) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSearching,
      builder: (context, isSearching, child) {
        if (isSearching) {
          return const Center(
            child: LottieState(
              asset: 'assets/lottie/loading.json',
              fallbackIcon: Icons.search,
              size: 90,
            ),
          );
        }
        return ValueListenableBuilder<String>(
          valueListenable: _query,
          builder: (context, query, child) {
            if (query.isEmpty) {
              return EmptyState(
                icon: Icons.search,
                title: 'Search $what',
                subtitle: 'Type to search across Telegram.',
              );
            }
            return EmptyState(
              icon: Icons.search_off,
              title: 'No $what found',
              subtitle: 'Try a different search term.',
            );
          },
        );
      },
    );
  }
}
