import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// The user's chat folders: create, rename, re-scope, reorder and delete.
class ChatFoldersPage extends StatefulWidget {
  const ChatFoldersPage({super.key});

  @override
  State<ChatFoldersPage> createState() => _ChatFoldersPageState();
}

class _ChatFoldersPageState extends State<ChatFoldersPage> {
  final ChatStore _store = ChatStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FolderEditorPage()),
    );
  }

  Future<void> _edit(Map<String, dynamic> folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderEditorPage(
          folderId: folder['id'] as int,
          initialTitle: folder['title'] as String? ?? '',
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteFolderQuestion(
          folder['title'] as String? ?? '',
        )),
        content: Text(context.l10n.deleteFolderExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TDLibClient.deleteChatFolder(chatFolderId: folder['id'] as int);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final folders = [..._store.folders];
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = folders.removeAt(oldIndex);
    folders.insert(target, moved);
    await TDLibClient.reorderChatFolders(
      chatFolderIds: [for (final folder in folders) folder['id'] as int],
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = _store.folders;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.chatFolders)),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: folders.isEmpty
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: context.l10n.noFoldersYet,
              subtitle: context.l10n.foldersExplanation,
            )
          : ReorderableListView.builder(
              padding: withBottomSafeArea(context),
              itemCount: folders.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  key: ValueKey(folder['id']),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder['title'] as String? ?? ''),
                  onTap: () => _edit(folder),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(folder),
                  ),
                );
              },
            ),
    );
  }
}

/// Creates a folder, or edits the one named by [folderId].
class FolderEditorPage extends StatefulWidget {
  const FolderEditorPage({
    super.key,
    this.folderId,
    this.initialTitle = '',
  });

  final int? folderId;
  final String initialTitle;

  @override
  State<FolderEditorPage> createState() => _FolderEditorPageState();
}

class _FolderEditorPageState extends State<FolderEditorPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialTitle);

  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<Set<int>> _included = ValueNotifier(const {});
  final ValueNotifier<Set<int>> _excluded = ValueNotifier(const {});
  final ValueNotifier<Map<String, bool>> _flags = ValueNotifier(const {});

  /// The folder as TDLib returned it, so fields this editor does not touch
  /// survive a save.
  Map<String, dynamic> _folder = {'@type': 'chatFolder'};

  static const _includeFlags = [
    'includeContacts',
    'includeNonContacts',
    'includeBots',
    'includeGroups',
    'includeChannels',
  ];

  static const _excludeFlags = [
    'excludeMuted',
    'excludeRead',
    'excludeArchived',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _isLoading.dispose();
    _included.dispose();
    _excluded.dispose();
    _flags.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final folderId = widget.folderId;
    if (folderId != null) {
      final folder = await TDLibClient.getChatFolder(chatFolderId: folderId);
      if (!mounted) return;
      if (folder != null) {
        _folder = folder;
        _included.value = _idsOf(folder['includedChatIds']);
        _excluded.value = _idsOf(folder['excludedChatIds']);
      }
    }
    _flags.value = {
      for (final flag in [..._includeFlags, ..._excludeFlags])
        flag: _folder[flag] == true,
    };
    _isLoading.value = false;
  }

  static Set<int> _idsOf(dynamic raw) => {
        for (final id in raw as List? ?? const []) (id as num).toInt(),
      };

  Future<void> _pickChats(ValueNotifier<Set<int>> target) async {
    final chosen = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChatMultiPicker(selected: target.value),
    );
    if (chosen != null) target.value = chosen;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final emptyNameMessage = context.l10n.folderNameRequired;
    final emptyFolderMessage = context.l10n.folderNeedsChats;

    if (name.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(emptyNameMessage)));
      return;
    }

    final flags = _flags.value;
    final hasContent = _included.value.isNotEmpty ||
        _includeFlags.any((flag) => flags[flag] == true);
    if (!hasContent) {
      messenger.showSnackBar(SnackBar(content: Text(emptyFolderMessage)));
      return;
    }

    final folder = {
      ..._folder,
      '@type': 'chatFolder',
      'name': {
        '@type': 'chatFolderName',
        'text': {'@type': 'formattedText', 'text': name, 'entities': const []},
        'animateCustomEmoji': false,
      },
      'includedChatIds': _included.value.toList(),
      'excludedChatIds': _excluded.value.toList(),
      'pinnedChatIds': _folder['pinnedChatIds'] ?? const <int>[],
      for (final flag in [..._includeFlags, ..._excludeFlags])
        flag: flags[flag] == true,
    };

    final folderId = widget.folderId;
    if (folderId == null) {
      await TDLibClient.createChatFolder(folder: folder);
    } else {
      await TDLibClient.editChatFolder(
        chatFolderId: folderId,
        folder: folder,
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderId == null
              ? context.l10n.newFolder
              : context.l10n.editFolder,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: withBottomSafeArea(context),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.l10n.folderName,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              _Header(context.l10n.includedChats),
              _ChatsTile(
                label: context.l10n.chats,
                selection: _included,
                onTap: () => _pickChats(_included),
              ),
              for (final flag in _includeFlags)
                _FlagSwitch(
                  flags: _flags,
                  flag: flag,
                  label: _flagLabel(context, flag),
                ),
              _Header(context.l10n.excludedChats),
              _ChatsTile(
                label: context.l10n.chats,
                selection: _excluded,
                onTap: () => _pickChats(_excluded),
              ),
              for (final flag in _excludeFlags)
                _FlagSwitch(
                  flags: _flags,
                  flag: flag,
                  label: _flagLabel(context, flag),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _flagLabel(BuildContext context, String flag) {
    switch (flag) {
      case 'includeContacts':
        return context.l10n.contacts;
      case 'includeNonContacts':
        return context.l10n.folderNonContacts;
      case 'includeBots':
        return context.l10n.folderBots;
      case 'includeGroups':
        return context.l10n.groups;
      case 'includeChannels':
        return context.l10n.channels;
      case 'excludeMuted':
        return context.l10n.folderMuted;
      case 'excludeRead':
        return context.l10n.folderRead;
      case 'excludeArchived':
        return context.l10n.archivedChats;
      default:
        return flag;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _ChatsTile extends StatelessWidget {
  const _ChatsTile({
    required this.label,
    required this.selection,
    required this.onTap,
  });

  final String label;
  final ValueNotifier<Set<int>> selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: selection,
      builder: (context, chats, child) => ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(label),
        subtitle: Text('${chats.length}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _FlagSwitch extends StatelessWidget {
  const _FlagSwitch({
    required this.flags,
    required this.flag,
    required this.label,
  });

  final ValueNotifier<Map<String, bool>> flags;
  final String flag;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: flags,
      builder: (context, values, child) => SwitchListTile(
        title: Text(label),
        value: values[flag] == true,
        onChanged: (value) => flags.value = {...values, flag: value},
      ),
    );
  }
}

/// A sheet that toggles chats on and off, resolving to the chosen ids.
class _ChatMultiPicker extends StatefulWidget {
  const _ChatMultiPicker({required this.selected});

  final Set<int> selected;

  @override
  State<_ChatMultiPicker> createState() => _ChatMultiPickerState();
}

class _ChatMultiPickerState extends State<_ChatMultiPicker> {
  late final ValueNotifier<Set<int>> _selected =
      ValueNotifier({...widget.selected});

  late final List<Map<String, dynamic>> _chats = [
    ...ChatStore.instance.visibleChats(kind: ChatListKind.main),
    ...ChatStore.instance.visibleChats(kind: ChatListKind.archive),
  ];

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, scrollController) => Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            title: Text(context.l10n.chats),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => Navigator.pop(context, _selected.value),
              ),
            ],
          ),
          Expanded(
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: _selected,
              builder: (context, selected, child) => ListView.builder(
                controller: scrollController,
                padding: withBottomSafeArea(context),
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  final id = chat['id'] as int;
                  return CheckboxListTile(
                    value: selected.contains(id),
                    title: Text(chat['title'] as String? ?? ''),
                    onChanged: (checked) {
                      final next = {...selected};
                      if (checked == true) {
                        next.add(id);
                      } else {
                        next.remove(id);
                      }
                      _selected.value = next;
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
