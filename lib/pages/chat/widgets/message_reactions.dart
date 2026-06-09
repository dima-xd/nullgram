import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nullgram/theme/motion.dart';
import '../utils/message_formatter.dart';

/// The row of reaction chips shown beneath a message bubble.
///
/// Built from a TDLib `MessageReactions` object's `reactions` list. Each chip
/// shows the emoji and its count; the current user's chosen reaction is
/// highlighted. Tapping a chip reports its emoji so the caller can toggle it.
class MessageReactions extends StatelessWidget {
  final List<dynamic> reactions;
  final bool isOutgoing;
  final void Function(String emoji) onTap;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.isOutgoing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: isOutgoing ? WrapAlignment.end : WrapAlignment.start,
      children: [
        for (final reaction in reactions)
          if (reaction['type']?['@type'] == 'ReactionTypeEmoji')
            _ReactionChip(
              emoji: reaction['type']['emoji'] as String,
              count: reaction['totalCount'] as int? ?? 0,
              isChosen: reaction['isChosen'] == true,
              onTap: onTap,
            ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isChosen;
  final void Function(String emoji) onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isChosen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        isChosen ? scheme.primary : scheme.surfaceContainerHighest;
    final foreground = isChosen ? scheme.onPrimary : scheme.onSurface;
    final radius = BorderRadius.circular(14);

    final countStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: foreground,
        );

    final chip = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: () => onTap(emoji),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                AnimatedDefaultTextStyle(
                  duration: Motion.fast,
                  curve: Motion.standard,
                  style: countStyle ?? const TextStyle(),
                  child: Text(MessageFormatter.formatCount(count)),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!isChosen) return chip;

    return chip
        .animate(key: ValueKey(isChosen))
        .scaleXY(
          begin: 1,
          end: 1.12,
          duration: Motion.fast,
          curve: Motion.emphasized,
        )
        .then()
        .scaleXY(
          begin: 1.12,
          end: 1,
          duration: Motion.fast,
          curve: Motion.standard,
        );
  }
}
