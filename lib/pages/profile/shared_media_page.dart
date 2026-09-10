import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/link_resolver.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// One tab of the shared-media browser.
typedef _MediaTab = ({String label, String filter, bool isGrid});

/// Everything shared in a chat, grouped the way Telegram groups it.
///
/// Each tab is one `searchChatMessages` call with a different
/// `SearchMessagesFilter`, which is how TDLib exposes a chat's media without a
/// dedicated endpoint.
class SharedMediaPage extends StatelessWidget {
  const SharedMediaPage({super.key, required this.chat});

  final Map<String, dynamic> chat;

  /// The tabs, built per call because their labels are translated.
  static List<_MediaTab> _tabsOf(BuildContext context) => [
    (
      label: context.l10n.media,
      filter: 'searchMessagesFilterPhotoAndVideo',
      isGrid: true,
    ),
    (
      label: context.l10n.files,
      filter: 'searchMessagesFilterDocument',
      isGrid: false,
    ),
    (
      label: context.l10n.links,
      filter: 'searchMessagesFilterUrl',
      isGrid: false,
    ),
    (
      label: context.l10n.music,
      filter: 'searchMessagesFilterAudio',
      isGrid: false,
    ),
    (
      label: context.l10n.voice,
      filter: 'searchMessagesFilterVoiceNote',
      isGrid: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsOf(context);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.sharedMedia),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              _MediaList(
                chat: chat,
                filter: tab.filter,
                isGrid: tab.isGrid,
                emptyTitle: context.l10n.nothingSharedYet,
              ),
          ],
        ),
      ),
    );
  }
}

/// The contents of one tab, paged as the user scrolls.
class _MediaList extends StatefulWidget {
  const _MediaList({
    required this.chat,
    required this.filter,
    required this.isGrid,
    required this.emptyTitle,
  });

  final Map<String, dynamic> chat;
  final String filter;
  final bool isGrid;
  final String emptyTitle;

  @override
  State<_MediaList> createState() => _MediaListState();
}

class _MediaListState extends State<_MediaList> {
  static const int _pageSize = 60;

  final ValueNotifier<List<Map<String, dynamic>>> _messages =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ScrollController _scrollController = ScrollController();

  bool _hasMore = true;

  int get _chatId => widget.chat['id'] as int;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messages.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading.value || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading.value && _messages.value.isNotEmpty) return;
    _isLoading.value = true;

    // Paging is by "from this message id, going older", so the oldest loaded
    // message is the cursor.
    final fromMessageId =
        _messages.value.isEmpty ? 0 : _messages.value.last['id'] as int;

    final result = await TDLibClient.searchChatMessages(
      chatId: _chatId,
      fromMessageId: fromMessageId,
      limit: _pageSize,
      filter: {"@type": widget.filter},
    );
    if (!mounted) return;

    final fresh = result?.messages ?? const <Map<String, dynamic>>[];
    final known = {for (final message in _messages.value) message['id']};
    final added = [
      for (final message in fresh)
        if (!known.contains(message['id'])) message,
    ];

    _hasMore = added.isNotEmpty;
    if (added.isNotEmpty) _messages.value = [..._messages.value, ...added];
    _isLoading.value = false;
  }

  void _openInChat(Map<String, dynamic> message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chat: widget.chat,
          initialMessageId: message['id'] as int,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _messages,
      builder: (context, messages, child) {
        if (messages.isEmpty) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) => isLoading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.perm_media_outlined,
                    title: widget.emptyTitle,
                    subtitle: context.l10n.sharedMediaEmpty,
                  ),
          );
        }

        if (widget.isGrid) {
          return GridView.builder(
            controller: _scrollController,
            padding: withBottomSafeArea(context, const EdgeInsets.all(2)),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) => _MediaThumbnail(
              message: messages[index],
              onTap: () => _openInChat(messages[index]),
            ),
          );
        }

        return ListView.separated(
          controller: _scrollController,
          padding: withBottomSafeArea(context),
          itemCount: messages.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
          itemBuilder: (context, index) => _MediaRow(
            message: messages[index],
            onTap: () => _openInChat(messages[index]),
          ),
        );
      },
    );
  }
}

/// A photo or video tile in the media grid.
///
/// Only already-downloaded files are drawn from disk; the rest fall back to
/// their minithumbnail, so opening the tab never kicks off dozens of
/// downloads.
class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.message, required this.onTap});

  final Map<String, dynamic> message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = message['content'] as Map<String, dynamic>?;
    final isVideo = content?['@type'] == 'MessageVideo';
    final path = _thumbnailPath(content);

    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path != null)
            Image.file(
              File(path),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: scheme.surfaceContainerHighest),
            )
          else
            ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (isVideo)
            Positioned(
              left: 4,
              bottom: 4,
              child: Icon(
                Icons.play_circle_fill,
                size: 20,
                color: scheme.surface,
              ),
            ),
        ],
      ),
    );
  }

  /// The on-disk path of the best already-downloaded thumbnail, or null.
  String? _thumbnailPath(Map<String, dynamic>? content) {
    final candidates = <dynamic>[
      content?['video']?['thumbnail']?['file'],
      ...?(content?['photo']?['sizes'] as List?)?.map((size) => size['photo']),
    ];
    for (final file in candidates) {
      final local = file?['local'];
      if (local?['isDownloadingCompleted'] != true) continue;
      final path = local['path'] as String?;
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }
}

/// A file, link, music or voice row in the media list.
class _MediaRow extends StatelessWidget {
  const _MediaRow({required this.message, required this.onTap});

  final Map<String, dynamic> message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = message['content'] as Map<String, dynamic>?;
    final url = _firstUrl(content);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(_icon(content), color: scheme.onSurfaceVariant),
      ),
      title: Text(
        _title(content) ?? messagePreviewText(message),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        MessageFormatter.formatDateSeparator(message['date'] as int),
      ),
      // A link row opens the link itself; everything else jumps to the message
      // it came from, where it can be played or downloaded.
      onTap: url == null ? onTap : () => openLink(context, url),
      trailing: url == null
          ? null
          : IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: context.l10n.showInChat,
              onPressed: onTap,
            ),
    );
  }

  IconData _icon(Map<String, dynamic>? content) =>
      switch (content?['@type'] as String?) {
        'MessageDocument' => Icons.insert_drive_file_outlined,
        'MessageAudio' => Icons.music_note_outlined,
        'MessageVoiceNote' => Icons.mic_none,
        _ => Icons.link,
      };

  String? _title(Map<String, dynamic>? content) => switch (content?['@type']) {
        'MessageDocument' => content?['document']?['fileName'] as String?,
        'MessageAudio' => content?['audio']?['title'] as String?,
        _ => null,
      };

  /// The first URL in a message's text entities, for the Links tab.
  String? _firstUrl(Map<String, dynamic>? content) {
    final text = content?['text'];
    final body = text?['text'] as String?;
    if (body == null) return null;

    for (final entity in (text?['entities'] as List? ?? const [])) {
      final type = entity['type'];
      if (type?['@type'] == 'TextEntityTypeTextUrl') {
        return type['url'] as String?;
      }
      if (type?['@type'] == 'TextEntityTypeUrl') {
        final offset = entity['offset'] as int;
        final length = entity['length'] as int;
        return body.substring(offset, offset + length);
      }
    }
    return null;
  }
}
