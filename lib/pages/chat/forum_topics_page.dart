import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/thread_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// The topic list of a forum supergroup, which stands in for its chat history.
class ForumTopicsPage extends StatefulWidget {
  const ForumTopicsPage({super.key, required this.chat});

  final Map<String, dynamic> chat;

  @override
  State<ForumTopicsPage> createState() => _ForumTopicsPageState();
}

class _ForumTopicsPageState extends State<ForumTopicsPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _topics =
      ValueNotifier(const []);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  int get _chatId => widget.chat['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _topics.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  /// Pages until TDLib runs out, since it answers with fewer topics than the
  /// limit by design.
  Future<void> _load() async {
    final collected = <Map<String, dynamic>>[];
    var offsetDate = 0;
    var offsetMessageId = 0;
    var offsetThreadId = 0;

    while (collected.length < 200) {
      final page = await TDLibClient.getForumTopics(
        chatId: _chatId,
        offsetDate: offsetDate,
        offsetMessageId: offsetMessageId,
        offsetMessageThreadId: offsetThreadId,
      );
      final topics = page?['topics'] as List? ?? const [];
      if (topics.isEmpty) break;

      collected.addAll([
        for (final topic in topics) Map<String, dynamic>.from(topic as Map),
      ]);
      offsetDate = page?['nextOffsetDate'] as int? ?? 0;
      offsetMessageId = page?['nextOffsetMessageId'] as int? ?? 0;
      offsetThreadId = page?['nextOffsetMessageThreadId'] as int? ?? 0;
      if (offsetMessageId == 0) break;
    }

    if (!mounted) return;
    _topics.value = collected;
    _isLoading.value = false;
  }

  void _open(Map<String, dynamic> topic) {
    final info = topic['info'] as Map<String, dynamic>?;
    if (info == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadPage(
          chat: widget.chat,
          title: info['name'] as String?,
          threadInfo: {
            'chatId': _chatId,
            'messageThreadId': info['messageThreadId'],
            'messages': const [],
            'replyInfo': {
              'replyCount': 0,
              'lastReadInboxMessageId': topic['lastReadInboxMessageId'] ?? 0,
            },
          },
        ),
      ),
    );
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.newTopic),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: dialogContext.l10n.topicName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(dialogContext.l10n.create),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    await TDLibClient.createForumTopic(chatId: _chatId, name: name);
    if (!mounted) return;
    _isLoading.value = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat['title'] as String? ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.newTopic,
            onPressed: _create,
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _topics,
            builder: (context, topics, child) {
              if (topics.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_outlined,
                  title: context.l10n.noTopicsYet,
                );
              }
              return ListView.builder(
                padding: withBottomSafeArea(context),
                itemCount: topics.length,
                itemBuilder: (context, index) => _TopicTile(
                  topic: topics[index],
                  onTap: () => _open(topics[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One topic row: its coloured dot, name, last message and unread badge.
class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onTap});

  final Map<String, dynamic> topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = topic['info'] as Map<String, dynamic>? ?? const {};
    final unread = topic['unreadCount'] as int? ?? 0;
    final lastMessage = topic['lastMessage'] as Map<String, dynamic>?;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Color(
          0xFF000000 | (info['icon']?['color'] as int? ?? 0x6FB9F0),
        ),
        child: Icon(
          info['isClosed'] == true ? Icons.lock_outline : Icons.tag,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        info['name'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: lastMessage == null
          ? null
          : Text(
              messagePreviewText(lastMessage),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: unread == 0
          ? null
          : Badge(
              label: Text('$unread'),
              backgroundColor: theme.colorScheme.primary,
            ),
    );
  }
}
