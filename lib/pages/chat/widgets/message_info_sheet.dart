import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/chat/widgets/custom_emoji.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Who reacted to a message and who has read it.
///
/// Telegram shows both behind the same long-press entry, so they share one
/// sheet here too.
Future<void> showMessageInfoSheet(
  BuildContext context, {
  required int chatId,
  required int messageId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _MessageInfoSheet(
      chatId: chatId,
      messageId: messageId,
    ),
  );
}

/// One person and what they did to the message.
typedef _Entry = ({
  int userId,
  Map<String, dynamic>? user,
  Map<String, dynamic>? reactionType,
  int date,
});

class _MessageInfoSheet extends StatefulWidget {
  const _MessageInfoSheet({required this.chatId, required this.messageId});

  final int chatId;
  final int messageId;

  @override
  State<_MessageInfoSheet> createState() => _MessageInfoSheetState();
}

class _MessageInfoSheetState extends State<_MessageInfoSheet> {
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<List<_Entry>> _reactions = ValueNotifier(const []);
  final ValueNotifier<List<_Entry>> _viewers = ValueNotifier(const []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _reactions.dispose();
    _viewers.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final added = await TDLibClient.getMessageAddedReactions(
      chatId: widget.chatId,
      messageId: widget.messageId,
    );
    final viewers = await TDLibClient.getMessageViewers(
      chatId: widget.chatId,
      messageId: widget.messageId,
    );
    if (!mounted) return;

    _reactions.value = await _resolveReactions(added);
    _viewers.value = await _resolveViewers(viewers);
    if (!mounted) return;
    _isLoading.value = false;
  }

  Future<List<_Entry>> _resolveReactions(Map<String, dynamic>? added) async {
    final reactions = added?['reactions'] as List? ?? const [];
    final entries = <_Entry>[];
    for (final reaction in reactions) {
      final sender = reaction['senderId'] as Map<String, dynamic>?;
      final userId = (sender?['userId'] as num?)?.toInt();
      // A channel reacting as itself has no user to show, so it is skipped
      // rather than rendered as a blank row.
      if (userId == null) continue;
      entries.add((
        userId: userId,
        user: await TDLibClient.getUser(userId: userId),
        reactionType: reaction['type'] as Map<String, dynamic>?,
        date: (reaction['date'] as num?)?.toInt() ?? 0,
      ));
    }
    return entries;
  }

  Future<List<_Entry>> _resolveViewers(
    List<Map<String, dynamic>> viewers,
  ) async {
    final entries = <_Entry>[];
    for (final viewer in viewers) {
      final userId = (viewer['userId'] as num?)?.toInt();
      if (userId == null) continue;
      entries.add((
        userId: userId,
        user: await TDLibClient.getUser(userId: userId),
        reactionType: null,
        date: (viewer['viewDate'] as num?)?.toInt() ?? 0,
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetBottomPadding(context),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ListenableBuilder(
            listenable: Listenable.merge([_reactions, _viewers]),
            builder: (context, child) => _buildBody(),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final reactions = _reactions.value;
    final viewers = _viewers.value;

    if (reactions.isEmpty && viewers.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Text(
          context.l10n.noInteractionInfo,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (reactions.isNotEmpty) ...[
            _SectionHeader(
              context.l10n.reactionsWithCount(reactions.length),
            ),
            for (final entry in reactions) _EntryTile(entry: entry),
          ],
          if (viewers.isNotEmpty) ...[
            _SectionHeader(context.l10n.readByWithCount(viewers.length)),
            for (final entry in viewers) _EntryTile(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// One row: the person, when they acted, and their reaction if any.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final user = entry.user;
    final name = [user?['firstName'], user?['lastName']]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');

    return ListTile(
      leading: ChatAvatar(
        chat: {
          'id': entry.userId,
          'title': name.isEmpty ? 'User' : name,
          'photo': user?['profilePhoto'],
          'user': user,
        },
        radius: 20,
      ),
      title: Text(name.isEmpty ? 'User ${entry.userId}' : name),
      subtitle: entry.date == 0
          ? null
          : Text(MessageFormatter.formatTime(entry.date)),
      trailing: entry.reactionType == null
          ? null
          : _ReactionBadge(type: entry.reactionType!),
    );
  }
}

/// The reaction someone left, emoji or custom emoji.
class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.type});

  final Map<String, dynamic> type;

  @override
  Widget build(BuildContext context) {
    final customEmojiId = (type['customEmojiId'] as num?)?.toInt();
    if (customEmojiId != null) {
      return CustomEmoji(
        customEmojiId: customEmojiId,
        size: 24,
        fallback: '',
        color: Theme.of(context).colorScheme.onSurface,
      );
    }
    return Text(
      type['emoji'] as String? ?? '',
      style: const TextStyle(fontSize: 22),
    );
  }
}
