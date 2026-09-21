import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/sticker_sets_page.dart';
import 'package:nullgram/services/gif_search.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'sticker_image.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The composer's emoji and sticker panel.
///
/// Slides in below the composer instead of opening a modal sheet, so the
/// message being written stays visible while picking — the behaviour Telegram
/// has.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.chatId,
    required this.onEmoji,
    required this.onSticker,
    required this.onGif,
    required this.onInlineGif,
    required this.onBackspace,
  });

  /// The chat the picker sends into, which an inline GIF query is scoped to.
  final int chatId;

  /// Called with the emoji to insert at the caret.
  final void Function(String emoji) onEmoji;

  /// Called with the file id of the sticker to send.
  final void Function(int fileId) onSticker;

  /// Called with the file id of the saved GIF to send.
  final void Function(int fileId) onGif;

  /// Called with a GIF an inline bot returned, which is sent by query id.
  final void Function(int queryId, String resultId) onInlineGif;

  /// Called when the panel's backspace key is pressed.
  final VoidCallback onBackspace;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel>
    with SingleTickerProviderStateMixin {
  static const double _height = 280;

  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.emoji_emotions_outlined), height: 40),
              Tab(icon: Icon(Icons.auto_awesome_outlined), height: 40),
              Tab(icon: Icon(Icons.gif_box_outlined), height: 40),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EmojiGrid(
                  onEmoji: widget.onEmoji,
                  onBackspace: widget.onBackspace,
                ),
                _StickerGrid(onSticker: widget.onSticker),
                _GifGrid(
                  chatId: widget.chatId,
                  onGif: widget.onGif,
                  onInlineGif: widget.onInlineGif,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid of Unicode emoji, grouped by category.
///
/// The list is bundled rather than fetched: TDLib only serves *custom* emoji,
/// and a static table keeps the picker instant and offline.
class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.onEmoji, required this.onBackspace});

  final void Function(String emoji) onEmoji;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 56),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 44,
          ),
          itemCount: emojiCatalog.length,
          itemBuilder: (context, index) {
            final emoji = emojiCatalog[index];
            return InkWell(
              onTap: () => onEmoji(emoji),
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            );
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: onBackspace,
            tooltip: context.l10n.backspace,
            child: const Icon(Icons.backspace_outlined),
          ),
        ),
      ],
    );
  }
}

/// A grid of the user's recent and installed stickers.
class _StickerGrid extends StatefulWidget {
  const _StickerGrid({required this.onSticker});

  final void Function(int fileId) onSticker;

  @override
  State<_StickerGrid> createState() => _StickerGridState();
}

class _StickerGridState extends State<_StickerGrid> {
  final ValueNotifier<List<Map<String, dynamic>>> _stickers =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stickers.dispose();
    _isLoading.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Loads recents first, then fills the grid out with the installed sets.
  ///
  /// Sticker set *info* only carries a few covers, so each set has to be
  /// fetched to get its stickers; only the first few sets are loaded to keep
  /// opening the panel fast.
  Future<void> _load() async {
    final collected = <int, Map<String, dynamic>>{};

    for (final sticker in await TDLibClient.getRecentStickers()) {
      final id = sticker['sticker']?['id'] as int?;
      if (id != null) collected[id] = sticker;
    }
    if (mounted && collected.isNotEmpty) {
      _stickers.value = collected.values.toList();
      _isLoading.value = false;
    }

    final sets = await TDLibClient.getInstalledStickerSets();
    for (final info in sets.take(8)) {
      final set = await TDLibClient.getStickerSet(setId: info['id'] as int);
      for (final sticker in (set?['stickers'] as List? ?? const [])) {
        final id = sticker['sticker']?['id'] as int?;
        if (id != null) {
          collected[id] = Map<String, dynamic>.from(sticker as Map);
        }
      }
      if (!mounted) return;
      _stickers.value = collected.values.toList();
      _isLoading.value = false;
    }

    if (mounted) _isLoading.value = false;
  }

  /// Replaces the grid with the stickers matching [emoji], or restores the
  /// installed ones when the box is cleared.
  Future<void> _search(String emoji) async {
    final query = emoji.trim();
    if (query.isEmpty) {
      _isLoading.value = true;
      _stickers.value = const [];
      await _load();
      return;
    }
    _isLoading.value = true;
    final found = await TDLibClient.getStickersByEmoji(emoji: query);
    if (!mounted) return;
    _stickers.value = found;
    _isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchStickersHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: context.l10n.stickerPacks,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StickerSetsPage()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _stickers,
            builder: (context, stickers, child) {
              if (stickers.isEmpty) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, child) => Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            context.l10n.noStickersYet,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 76,
                ),
                itemCount: stickers.length,
                itemBuilder: (context, index) {
                  final sticker = stickers[index];
                  return InkWell(
                    onTap: () {
                      final fileId = sticker['sticker']?['id'] as int?;
                      if (fileId != null) widget.onSticker(fileId);
                    },
                    child: StickerImage(
                      sticker: sticker,
                      size: 64,
                      animate: false,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A grid of the user's saved GIFs, or of what the GIF bot returns.
class _GifGrid extends StatefulWidget {
  const _GifGrid({
    required this.chatId,
    required this.onGif,
    required this.onInlineGif,
  });

  final int chatId;
  final void Function(int fileId) onGif;
  final void Function(int queryId, String resultId) onInlineGif;

  @override
  State<_GifGrid> createState() => _GifGridState();
}

class _GifGridState extends State<_GifGrid> {
  final ValueNotifier<List<Map<String, dynamic>>> _animations =
      ValueNotifier(const []);
  final ValueNotifier<List<GifResult>> _results = ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _animations.dispose();
    _results.dispose();
    _isLoading.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Runs a GIF search, or drops back to the saved GIFs on an empty box.
  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _results.value = const [];
      return;
    }
    _isLoading.value = true;
    final results = await GifSearch.search(
      chatId: widget.chatId,
      query: trimmed,
    );
    if (!mounted) return;
    _results.value = results;
    _isLoading.value = false;

    for (final result in results) {
      final thumbnailId = result.animation['thumbnail']?['file']?['id'] as int?;
      if (thumbnailId != null) {
        TDLibClient.downloadFile(fileId: thumbnailId).catchError((_) {});
      }
    }
  }

  Future<void> _load() async {
    final animations = await TDLibClient.getSavedAnimations();
    if (!mounted) return;
    _animations.value = animations;
    _isLoading.value = false;

    // Only the thumbnails are fetched here; the GIF itself is sent by file id
    // and never has to reach this device.
    for (final animation in animations) {
      final thumbnailId = animation['thumbnail']?['file']?['id'] as int?;
      if (thumbnailId != null) {
        TDLibClient.downloadFile(fileId: thumbnailId).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: context.l10n.searchGifsHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<GifResult>>(
            valueListenable: _results,
            builder: (context, results, child) {
              if (results.isNotEmpty) {
                return _grid(
                  count: results.length,
                  builder: (index) => _GifTile(
                    animation: results[index].animation,
                    onTap: () => widget.onInlineGif(
                      results[index].queryId,
                      results[index].resultId,
                    ),
                  ),
                );
              }
              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _animations,
                builder: (context, animations, child) {
                  if (animations.isEmpty) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isLoading,
                      builder: (context, isLoading, child) => Center(
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                context.l10n.noSavedGifs,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                      ),
                    );
                  }
                  return _grid(
                    count: animations.length,
                    builder: (index) => _GifTile(
                      animation: animations[index],
                      onTap: () {
                        final fileId =
                            animations[index]['animation']?['id'] as int?;
                        if (fileId != null) widget.onGif(fileId);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid({
    required int count,
    required Widget Function(int index) builder,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: count,
      itemBuilder: (context, index) => builder(index),
    );
  }
}

/// One saved GIF, drawn as its static thumbnail.
class _GifTile extends StatefulWidget {
  const _GifTile({required this.animation, required this.onTap});

  final Map<String, dynamic> animation;
  final VoidCallback onTap;

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  StreamSubscription<Map<String, dynamic>>? _fileSubscription;

  int? get _thumbnailId =>
      widget.animation['thumbnail']?['file']?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      if (file['id'] != _thumbnailId || !mounted) return;
      widget.animation['thumbnail']['file'] = file;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = widget.animation['thumbnail']?['file']?['local'];
    final path = local?['isDownloadingCompleted'] == true
        ? local['path'] as String?
        : null;

    return InkWell(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: path == null || path.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.gif_box_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}

/// The emoji offered by the picker, in Telegram's category order.
const List<String> emojiCatalog = [
  // Smileys and people
  '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
  '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
  '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
  '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
  '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
  '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐',
  '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧',
  '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓',
  '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈', '👿', '💀',
  '💩', '🤡', '👻', '👽', '🤖', '😺', '😸', '😹', '😻', '😼',
  '🙈', '🙉', '🙊', '💋', '💌', '💘', '💝', '💖', '💗', '💓',
  '💞', '💕', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  // Gestures and body
  '👋', '🤚', '✋', '🖖', '👌', '🤌', '✌️', '🤞', '🤟', '🤘',
  '👈', '👉', '👆', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛',
  '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '💪', '🦾', '🖐️',
  '👀', '👁️', '👅', '👄', '🧠', '🦴', '👶', '🧒', '👦', '👧',
  '🧑', '👨', '👩', '🧓', '👴', '👵', '🙋', '🤦', '🤷', '💁',
  // Animals and nature
  '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
  '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🦆',
  '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋',
  '🐌', '🐞', '🐜', '🕷️', '🐢', '🐍', '🦎', '🐙', '🦑', '🦐',
  '🐠', '🐟', '🐬', '🐳', '🦈', '🐊', '🐅', '🐘', '🦒', '🐫',
  '🌵', '🌲', '🌳', '🌴', '🌱', '🌿', '☘️', '🍀', '🍁', '🍂',
  '🌷', '🌹', '🥀', '🌺', '🌸', '🌼', '🌻', '🌞', '🌝', '🌚',
  '🌙', '⭐', '🌟', '✨', '⚡', '🔥', '💥', '☀️', '⛅', '☁️',
  '🌧️', '⛈️', '🌈', '❄️', '⛄', '💧', '🌊', '🌍', '🌎', '🌏',
  // Food and drink
  '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈',
  '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦',
  '🌽', '🥕', '🥔', '🍞', '🥐', '🥖', '🧀', '🥚', '🍳', '🥓',
  '🍔', '🍟', '🍕', '🌭', '🥪', '🌮', '🌯', '🥗', '🍝', '🍜',
  '🍣', '🍱', '🍚', '🍛', '🍤', '🍦', '🍰', '🎂', '🍫', '🍬',
  '🍿', '🍩', '🍪', '☕', '🍵', '🥤', '🍺', '🍻', '🥂', '🍷',
  // Activities and objects
  '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱', '🏓', '🏸',
  '🥊', '🎯', '🎮', '🕹️', '🎲', '🧩', '🎸', '🎹', '🎺', '🎻',
  '🥁', '🎤', '🎧', '🎬', '🎨', '🎭', '🏆', '🥇', '🥈', '🥉',
  '📱', '💻', '⌨️', '🖥️', '🖨️', '📷', '📹', '📼', '💡', '🔋',
  '💰', '💳', '📦', '📫', '📝', '📚', '📖', '🔑', '🔒', '🔓',
  '🔨', '🪛', '⚙️', '🧲', '🧪', '💊', '🩹', '🚪', '🛏️', '🚿',
  // Travel and symbols
  '🚗', '🚕', '🚌', '🚑', '🚓', '🚒', '🚚', '🚜', '🏍️', '🚲',
  '✈️', '🚀', '🛸', '🚁', '⛵', '🚢', '🗺️', '🏔️', '🏕️', '🏖️',
  '🏠', '🏢', '🏥', '🏦', '🏨', '🏫', '⛪', '🕌', '🗼', '🗽',
  '✅', '❌', '❓', '❗', '💯', '🔔', '🔕', '➕', '➖', '➗',
  '⏰', '⌛', '🎉', '🎊', '🎁', '🎈', '🏁', '🚩', '💤', '🆗',
];
