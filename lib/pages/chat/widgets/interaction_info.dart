import 'package:flutter/material.dart';
import '../utils/message_formatter.dart';

class InteractionInfo extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isOutgoing;

  const InteractionInfo({
    super.key,
    required this.message,
    required this.isOutgoing,
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

    final hasInteraction = (viewCount != null && viewCount > 0) ||
        (forwardCount != null && forwardCount > 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasInteraction) ...[
          if (viewCount != null && viewCount > 0) ...[
            Icon(
              Icons.visibility_outlined,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              MessageFormatter.formatCount(viewCount),
              style: metaStyle,
            ),
          ],
          if (forwardCount != null && forwardCount > 0) ...[
            if (viewCount != null && viewCount > 0) const SizedBox(width: 12),
            Icon(
              Icons.forward,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              MessageFormatter.formatCount(forwardCount),
              style: metaStyle,
            ),
          ],
          const SizedBox(width: 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((message['editDate'] as int? ?? 0) > 0) ...[
              Text(
                'edited',
                style: metaStyle?.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              MessageFormatter.formatTime(message['date']!),
              style: metaStyle,
            ),
            if (isOutgoing) ...[
              const SizedBox(width: 4),
              _DeliveryTick(
                sendingState: message['sendingState']?['@type'] as String?,
                scheme: scheme,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The outgoing-message delivery indicator: a clock while pending, an error
/// glyph on failure, otherwise the sent/read double-check.
class _DeliveryTick extends StatelessWidget {
  final String? sendingState;
  final ColorScheme scheme;

  const _DeliveryTick({required this.sendingState, required this.scheme});

  @override
  Widget build(BuildContext context) {
    switch (sendingState) {
      case 'MessageSendingStatePending':
        return Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant);
      case 'MessageSendingStateFailed':
        return Icon(Icons.error_outline, size: 16, color: scheme.error);
      default:
        return Icon(Icons.done_all, size: 16, color: scheme.primary);
    }
  }
}
