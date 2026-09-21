import 'package:flutter/material.dart';
import '../utils/message_formatter.dart';

/// The metadata line inside a bubble: view/forward counts, an "edited" marker,
/// the timestamp and, for our own messages, the delivery state.
class InteractionInfo extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isOutgoing;

  /// The highest message id the other side has read, from the chat.
  ///
  /// TDLib reports read state per chat, not per message, so the bubble can only
  /// tell "sent" from "read" by comparing against this.
  final int lastReadOutboxMessageId;

  const InteractionInfo({
    super.key,
    required this.message,
    required this.isOutgoing,
    this.lastReadOutboxMessageId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final interactionInfo = message['interactionInfo'];
    final viewCount = interactionInfo?['viewCount'] as int?;
    final forwardCount = interactionInfo?['forwardCount'] as int?;
    final hasViews = viewCount != null && viewCount > 0;
    final hasForwards = forwardCount != null && forwardCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasViews) ...[
          Icon(
            Icons.visibility_outlined,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(MessageFormatter.formatCount(viewCount), style: metaStyle),
        ],
        if (hasForwards) ...[
          if (hasViews) const SizedBox(width: 12),
          Icon(Icons.forward, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(MessageFormatter.formatCount(forwardCount), style: metaStyle),
        ],
        if (hasViews || hasForwards) const SizedBox(width: 12),
        if ((message['editDate'] as int? ?? 0) > 0) ...[
          Icon(Icons.edit, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
        ],
        Text(MessageFormatter.formatTime(message['date']!), style: metaStyle),
        if (isOutgoing) ...[
          const SizedBox(width: 4),
          _DeliveryTick(
            sendingState: message['sendingState']?['@type'] as String?,
            isRead: (message['id'] as int? ?? 0) <= lastReadOutboxMessageId,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}

/// The outgoing-message delivery indicator: a clock while pending, an error
/// glyph on failure, a single check once delivered and a double check once the
/// other side has read it.
class _DeliveryTick extends StatelessWidget {
  final String? sendingState;
  final bool isRead;
  final ColorScheme scheme;

  const _DeliveryTick({
    required this.sendingState,
    required this.isRead,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    switch (sendingState) {
      case 'MessageSendingStatePending':
        return Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant);
      case 'MessageSendingStateFailed':
        return Icon(Icons.error_outline, size: 16, color: scheme.error);
      default:
        return Icon(
          isRead ? Icons.done_all : Icons.done,
          size: 16,
          color: scheme.primary,
        );
    }
  }
}
