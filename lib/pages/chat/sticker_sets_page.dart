import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/widgets/sticker_image.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// Browses sticker packs: the ones already installed, what Telegram is
/// promoting, and whatever a search turns up.
class StickerSetsPage extends StatefulWidget {
  const StickerSetsPage({super.key});

  @override
  State<StickerSetsPage> createState() => _StickerSetsPageState();
}

class _StickerSetsPageState extends State<StickerSetsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.stickerPacks),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.stickersInstalled),
            Tab(text: context.l10n.stickersTrending),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SetList(source: _SetSource.installed),
          _SetList(source: _SetSource.trending),
        ],
      ),
    );
  }
}

enum _SetSource { installed, trending }

/// A list of sticker sets with an install toggle, searchable by name.
class _SetList extends StatefulWidget {
  const _SetList({required this.source});

  final _SetSource source;

  @override
  State<_SetList> createState() => _SetListState();
}

class _SetListState extends State<_SetList> {
  final ValueNotifier<List<Map<String, dynamic>>> _sets =
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
    _sets.dispose();
    _isLoading.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _isLoading.value = true;
    final query = _query.text.trim();
    final sets = query.isNotEmpty
        ? await TDLibClient.searchStickerSets(query: query)
        : widget.source == _SetSource.installed
            ? await TDLibClient.getInstalledStickerSets()
            : await TDLibClient.getTrendingStickerSets();
    if (!mounted) return;
    _sets.value = sets;
    _isLoading.value = false;
  }

  Future<void> _toggle(Map<String, dynamic> set) async {
    final setId = set['id'] as int;
    final install = set['isInstalled'] != true;
    await TDLibClient.changeStickerSet(setId: setId, isInstalled: install);
    if (!mounted) return;
    _sets.value = [
      for (final current in _sets.value)
        if (current['id'] == setId)
          {...current, 'isInstalled': install}
        else
          current,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: context.l10n.searchStickerPacks,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
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
                valueListenable: _sets,
                builder: (context, sets, child) {
                  if (sets.isEmpty) {
                    return EmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: context.l10n.noStickersYet,
                    );
                  }
                  return ListView.builder(
                    padding: withBottomSafeArea(context),
                    itemCount: sets.length,
                    itemBuilder: (context, index) => _SetTile(
                      set: sets[index],
                      onToggle: () => _toggle(sets[index]),
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

/// One pack: its name, a strip of covers and the add or remove button.
class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.onToggle});

  final Map<String, dynamic> set;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final covers = set['covers'] as List? ?? const [];
    final isInstalled = set['isInstalled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set['title'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      context.l10n.stickersCount(set['size'] as int? ?? 0),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              isInstalled
                  ? OutlinedButton(
                      onPressed: onToggle,
                      child: Text(context.l10n.remove),
                    )
                  : FilledButton(
                      onPressed: onToggle,
                      child: Text(context.l10n.add),
                    ),
            ],
          ),
          if (covers.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final cover in covers.take(6))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StickerImage(
                        sticker: Map<String, dynamic>.from(cover as Map),
                        size: 56,
                        animate: false,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
