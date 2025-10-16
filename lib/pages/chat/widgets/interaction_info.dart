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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              MessageFormatter.formatCount(viewCount),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          if (forwardCount != null && forwardCount > 0) ...[
            if (viewCount != null && viewCount > 0) const SizedBox(width: 12),
            Icon(
              Icons.forward,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              MessageFormatter.formatCount(forwardCount),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(width: 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MessageFormatter.formatTime(message['date']!),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            if (isOutgoing) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.done_all,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
