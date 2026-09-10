import 'package:flutter/material.dart';
import 'package:nullgram/pages/home/archive_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_view.dart';
import 'package:nullgram/pages/home/widgets/connection_banner.dart';
import 'package:nullgram/pages/home/widgets/new_chat_sheet.dart';
import 'package:nullgram/services/chat_store.dart';
import '../chat/chat_page.dart';
import '../search/search_page.dart';
import 'menu.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The chat list: one tab per chat folder, with the archive reachable from a
/// row above the main list.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ChatStore _store = ChatStore.instance;

  /// One entry per tab. The first is the implicit "All chats" tab, which has
  /// no folder id and therefore shows the whole main list.
  ///
  /// Its title is null rather than a translated string: the tabs are rebuilt
  /// from `initState`, where reading an inherited widget — which is what a
  /// localization lookup is — is not allowed. The label is resolved in
  /// `build` instead.
  List<({int? id, String? title})> _tabs = [(id: null, title: null)];

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.start();
    _syncTabs();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    _syncTabs();
    setState(() {});
  }

  /// Rebuilds the tab list from the store's folders, recreating the controller
  /// only when the number of tabs actually changed (recreating it on every
  /// update would reset the selected tab).
  void _syncTabs() {
    final tabs = <({int? id, String? title})>[
      (id: null, title: null),
      for (final folder in _store.folders)
        (id: folder['id'] as int, title: folder['title'] as String),
    ];
    _tabs = tabs;

    if (_tabController?.length != tabs.length) {
      final previousIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabController = TabController(
        length: tabs.length,
        initialIndex: previousIndex.clamp(0, tabs.length - 1),
        vsync: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolders = _tabs.length > 1;
    final controller = _tabController;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const ConnectionTitle(title: 'Nullgram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.l10n.search,
            onPressed: _openSearch,
          ),
        ],
        bottom: hasFolders && controller != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: controller,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      for (final tab in _tabs)
                        Tab(
                          child: _FolderTab(
                            folderId: tab.id,
                            title: tab.title ?? context.l10n.all,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      drawer: const HomeMenu(),
      floatingActionButton: FloatingActionButton(
        onPressed: _composeNewChat,
        tooltip: context.l10n.newMessage,
        child: const Icon(Icons.edit_outlined),
      ),
      body: hasFolders && controller != null
          ? TabBarView(
              controller: controller,
              children: [
                for (final tab in _tabs)
                  ChatListView(
                    folderId: tab.id,
                    onChatTap: _openChat,
                    header: tab.id == null ? _archiveHeader() : null,
                  ),
              ],
            )
          : ChatListView(
              onChatTap: _openChat,
              header: _archiveHeader(),
            ),
    );
  }

  /// The archive entry row, or null when the archive is empty (Telegram hides
  /// it entirely in that case).
  Widget? _archiveHeader() {
    if (!_store.hasArchivedChats) return null;
    return _ArchiveRow(
      unreadCount: _store.unreadChatCount(kind: ChatListKind.archive),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ArchivePage()),
      ),
    );
  }

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchPage()),
      );

  void _composeNewChat() => showNewChatSheet(context);

  void _openChat(int chatId) {
    final chat = _store.chat(chatId);
    if (chat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
    );
  }
}

/// A folder tab label with its unread-chat badge.
class _FolderTab extends StatelessWidget {
  const _FolderTab({required this.folderId, required this.title});

  final int? folderId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final count = ChatStore.instance.unreadChatCount(
      kind: ChatListKind.main,
      folderId: folderId,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Badge(label: Text('$count')),
        ],
      ],
    );
  }
}

/// The row above the main list that opens the archive.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
      ),
      title: Text(context.l10n.archivedChats),
      trailing: unreadCount > 0 ? Badge(label: Text('$unreadCount')) : null,
      onTap: onTap,
    );
  }
}
