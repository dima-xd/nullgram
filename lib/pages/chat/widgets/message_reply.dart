import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/utils/sender_names.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// The quoted block above a message that replies to another one.
///
/// TDLib gives a reply only as `replyTo`, which sometimes carries the quoted
/// content inline and sometimes just an id, so this resolves the missing case
/// through [TDLibClient.getMessage].
class ReplyQuote extends StatefulWidget {
  const ReplyQuote({
    super.key,
    required this.replyTo,
    required this.chatId,
    required this.onTap,
  });

  /// The message's `replyTo` object.
  final Map<String, dynamic> replyTo;

  /// The chat the replying message lives in, used when the reply target is in
  /// the same chat (the common case).
  final int chatId;

  /// Called with the quoted message's id, to jump to it.
  final void Function(int messageId) onTap;

  @override
  State<ReplyQuote> createState() => _ReplyQuoteState();
}

class _ReplyQuoteState extends State<ReplyQuote> {
  String? _senderName;
  String? _preview;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  int get _messageId => (widget.replyTo['messageId'] as int?) ?? 0;

  Future<void> _resolve() async {
    // A quote the user selected, or content TDLib inlined, avoids a round trip.
    final quote = widget.replyTo['quote']?['text']?['text'] as String?;
    final inlineContent = widget.replyTo['content'] as Map<String, dynamic>?;

    var preview = quote?.isNotEmpty == true
        ? quote
        : inlineContent == null
            ? null
            : messagePreviewText({'content': inlineContent});

    var senderName = await SenderNames.resolve(widget.replyTo['origin'] == null
        ? null
        : _senderIdOfOrigin(widget.replyTo['origin']));

    if (preview == null || senderName == null) {
      final message = await TDLibClient.getMessage(
        chatId: (widget.replyTo['chatId'] as int?) ?? widget.chatId,
        messageId: _messageId,
      );
      if (message != null) {
        preview ??= messagePreviewText(message);
        senderName ??= message['isOutgoing'] == true
            ? 'You'
            : await SenderNames.resolve(message['senderId']);
      }
    }

    if (!mounted) return;
    setState(() {
      _preview = preview ?? 'Message';
      _senderName = senderName;
    });
  }

  /// Maps a `MessageOrigin` onto the `MessageSender` shape [SenderNames] takes.
  Map<String, dynamic>? _senderIdOfOrigin(dynamic origin) =>
      switch (origin['@type']) {
        'MessageOriginUser' => {
            '@type': 'MessageSenderUser',
            'userId': origin['senderUserId'],
          },
        'MessageOriginChat' => {
            '@type': 'MessageSenderChat',
            'chatId': origin['senderChatId'],
          },
        'MessageOriginChannel' => {
            '@type': 'MessageSenderChat',
            'chatId': origin['chatId'],
          },
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _messageId == 0 ? null : () => widget.onTap(_messageId),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: scheme.primary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _senderName ?? 'Reply',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              _preview ?? '…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Forwarded from X" line above a forwarded message.
class ForwardHeader extends StatefulWidget {
  const ForwardHeader({super.key, required this.message});

  final Map<String, dynamic> message;

  @override
  State<ForwardHeader> createState() => _ForwardHeaderState();
}

class _ForwardHeaderState extends State<ForwardHeader> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _name = forwardOriginName(widget.message);
    if (_name == null) return;
    // The cached lookup may have fallen back to a generic label; resolving the
    // real name fills it in as soon as TDLib answers.
    _resolve();
  }

  Future<void> _resolve() async {
    final origin = widget.message['forwardInfo']?['origin'];
    if (origin == null) return;
    final senderId = switch (origin['@type']) {
      'MessageOriginUser' => {
          '@type': 'MessageSenderUser',
          'userId': origin['senderUserId'],
        },
      'MessageOriginChat' => {
          '@type': 'MessageSenderChat',
          'chatId': origin['senderChatId'],
        },
      'MessageOriginChannel' => {
          '@type': 'MessageSenderChat',
          'chatId': origin['chatId'],
        },
      _ => null,
    };
    if (senderId == null) return;
    final resolved = await SenderNames.resolve(senderId);
    if (resolved != null && mounted) setState(() => _name = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    if (name == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply_all, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Forwarded from $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
