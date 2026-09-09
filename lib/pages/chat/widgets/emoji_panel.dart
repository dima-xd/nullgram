import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'sticker_image.dart';

/// The composer's emoji and sticker panel.
///
/// Slides in below the composer instead of opening a modal sheet, so the
/// message being written stays visible while picking — the behaviour Telegram
/// has.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.onGif,
    required this.onBackspace,
  });

  /// Called with the emoji to insert at the caret.
  final void Function(String emoji) onEmoji;

  /// Called with the file id of the sticker to send.
  final void Function(int fileId) onSticker;

  /// Called with the file id of the saved GIF to send.
  final void Function(int fileId) onGif;

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
                _GifGrid(onGif: widget.onGif),
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
            tooltip: 'Backspace',
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stickers.dispose();
    _isLoading.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _stickers,
      builder: (context, stickers, child) {
        if (stickers.isEmpty) {
          return ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, isLoading, child) => Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      'No stickers yet',
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
    );
  }
}

/// A grid of the user's saved GIFs.
class _GifGrid extends StatefulWidget {
  const _GifGrid({required this.onGif});

  final void Function(int fileId) onGif;

  @override
  State<_GifGrid> createState() => _GifGridState();
}

class _GifGridState extends State<_GifGrid> {
  final ValueNotifier<List<Map<String, dynamic>>> _animations =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _animations.dispose();
    _isLoading.dispose();
    super.dispose();
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
                      'No saved GIFs',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: animations.length,
          itemBuilder: (context, index) => _GifTile(
            animation: animations[index],
            onTap: () {
              final fileId = animations[index]['animation']?['id'] as int?;
              if (fileId != null) widget.onGif(fileId);
            },
          ),
        );
      },
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
