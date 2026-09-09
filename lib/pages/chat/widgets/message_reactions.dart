import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nullgram/pages/chat/widgets/custom_emoji.dart';
import 'package:nullgram/theme/motion.dart';
import '../utils/message_formatter.dart';

/// The row of reaction chips shown beneath a message bubble.
///
/// Built from a TDLib `MessageReactions` object's `reactions` list. Each chip
/// shows the reaction and its count; the current user's chosen reaction is
/// highlighted. Tapping a chip reports its reaction type so the caller can
/// toggle it — a type rather than an emoji string, because a custom (premium)
/// reaction is identified by an id and has no text form.
class MessageReactions extends StatelessWidget {
  final List<dynamic> reactions;
  final bool isOutgoing;
  final void Function(Map<String, dynamic> reactionType) onTap;

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
          if (reaction['type'] case final Map<String, dynamic> type)
            _ReactionChip(
              type: type,
              count: reaction['totalCount'] as int? ?? 0,
              isChosen: reaction['isChosen'] == true,
              onTap: onTap,
            ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final Map<String, dynamic> type;
  final int count;
  final bool isChosen;
  final void Function(Map<String, dynamic> reactionType) onTap;

  const _ReactionChip({
    required this.type,
    required this.count,
    required this.isChosen,
    required this.onTap,
  });

  /// The id of a custom (premium) reaction, or null for a standard emoji one.
  int? get _customEmojiId => type['customEmojiId'] as int?;

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
        onTap: () => onTap(type),
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
              if (_customEmojiId case final customEmojiId?)
                CustomEmoji(
                  customEmojiId: customEmojiId,
                  size: 16,
                  fallback: '\u2b50',
                  color: foreground,
                )
              else
                Text(
                  type['emoji'] as String? ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
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
