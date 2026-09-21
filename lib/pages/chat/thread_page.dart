import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/widgets/message_list_view.dart';
import 'package:nullgram/services/message_history.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// One message thread: a channel post's comments, or a reply thread in a
/// supergroup.
///
/// The thread of a channel post lives in the channel's linked discussion
/// supergroup, so [chat] and `threadInfo['chatId']` are that supergroup — not
/// the channel the user came from.
class ThreadPage extends StatefulWidget {
  const ThreadPage({
    super.key,
    required this.chat,
    required this.threadInfo,
    this.history,
    this.canPostInitially = true,
    this.title,
  });

  /// The chat the thread lives in.
  final Map<String, dynamic> chat;

  /// TDLib's `messageThreadInfo`.
  final Map<String, dynamic> threadInfo;

  /// Injected by tests; the page builds its own from [threadInfo] otherwise.
  final MessageHistoryController? history;

  /// Whether the composer is offered before the first send is attempted.
  final bool canPostInitially;

  /// Replaces the "Comments" heading, which a forum topic names itself.
  final String? title;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late final ValueNotifier<bool> _canPost = ValueNotifier(
    widget.canPostInitially,
  );

  late final MessageHistoryController _history =
      widget.history ??
      MessageHistoryController(
        source: ThreadHistorySource(
          chatId: _chatId,
          messageThreadId: _threadId,
        ),
      );

  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;

  int get _chatId => widget.threadInfo['chatId'] as int;
  int get _threadId => widget.threadInfo['messageThreadId'] as int;

  /// The messages the thread starts from, newest first, as TDLib returns them.
  ///
  /// They head the comment list rather than sitting in a panel of their own,
  /// so the post reads as the first message of the thread.
  late final List<Map<String, dynamic>> _rootMessages = [
    for (final message in widget.threadInfo['messages'] as List? ?? const [])
      Map<String, dynamic>.from(message as Map),
  ];

  /// How many comments the thread had when it was opened, for the app bar.
  late final int _replyCount =
      widget.threadInfo['replyInfo']?['replyCount'] as int? ?? 0;

  /// The last reply read before this visit, which anchors the unread divider.
  late final int _lastReadOnOpen =
      widget.threadInfo['replyInfo']?['lastReadInboxMessageId'] as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _messagesSubscription = TDLibClient.messsagesUpdates.listen(
      _onMessageUpdate,
    );
    // A test injects its own controller and drives it directly.
    if (widget.history == null) _history.loadMore();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _canPost.dispose();
    if (widget.history == null) _history.dispose();
    super.dispose();
  }

  void _onMessageUpdate(Map<String, dynamic> update) {
    if (!mounted) return;
    final added = _history.applyUpdate(update);
    if (added == null || added['isOutgoing'] == true) return;

    TDLibClient.viewMessages(
      chatId: _chatId,
      messageIds: [added['id'] as int],
      source: const {"@type": "messageSourceMessageThreadHistory"},
    );
  }

  Future<void> _send() async {
    final raw = _messageController.text.trim();
    if (raw.isEmpty) return;

    // Parse MarkdownV2 server-side; on malformed markdown fall back to the raw
    // text so the comment is never dropped.
    final parsed = await TDLibClient.parseTextEntities(text: raw);
    if (!mounted) return;
    final text = parsed?['text'] as String? ?? raw;
    final entities = (parsed?['entities'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _messageController.clear();

    final error = await TDLibClient.sendMessage(
      chatId: _chatId,
      messageThreadId: _threadId,
      text: text,
      entities: entities,
    );
    if (!mounted || error == null) return;

    // A non-member is refused outright; offering the join button is more
    // useful than an error toast, and the text is handed back so it is not
    // lost.
    if (error.contains('FORBIDDEN')) {
      _canPost.value = false;
      _messageController.text = text;
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _join() async {
    await TDLibClient.joinChat(chatId: _chatId);
    if (!mounted) return;
    _canPost.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title ?? context.l10n.comments),
            if (_replyCount > 0)
              Text(
                context.l10n.commentsCount(_replyCount),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageListView(
              history: _history,
              chat: widget.chat,
              scrollController: _scrollController,
              lastReadOnOpen: _lastReadOnOpen,
              emptyTitle: widget.title == null
                  ? context.l10n.noCommentsYet
                  : context.l10n.noMessagesYet,
              emptySubtitle: widget.title == null
                  ? context.l10n.noCommentsHint
                  : context.l10n.chatEmptyHint,
              leadingMessages: _rootMessages,
              leadingSeparatorLabel: context.l10n.comments,
              leadingEmptyLabel: context.l10n.noCommentsYet,
              callbacks: MessageListCallbacks(
                onReplyTap: _history.loadWindowAround,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _canPost,
            builder: (context, canPost, child) => canPost
                ? _ThreadComposer(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    onSend: _send,
                  )
                : _JoinBar(onJoin: _join),
          ),
        ],
      ),
    );
  }
}

/// A one-line composer. Attachments, voice and stickers stay out of threads
/// for now.
class _ThreadComposer extends StatelessWidget {
  const _ThreadComposer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: context.l10n.leaveComment,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              // The send button stays quiet until there is something to send,
              // so an empty composer is not shouting a filled circle.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final canSend = value.text.trim().isNotEmpty;
                  return IconButton(
                    onPressed: canSend ? onSend : null,
                    icon: Icon(
                      Icons.send,
                      color: canSend ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the composer to someone who has not joined the discussion
/// group; TDLib refuses their messages until they do.
class _JoinBar extends StatelessWidget {
  const _JoinBar({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onJoin,
            child: Text(context.l10n.joinDiscussion),
          ),
        ),
      ),
    );
  }
}
