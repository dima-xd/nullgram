import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The footer inside a bubble that opens the message's thread.
///
/// A channel post calls them comments, a group message calls them replies —
/// TDLib reports both through the same `messageReplyInfo`.
class ThreadButton extends StatelessWidget {
  const ThreadButton({
    super.key,
    required this.replyInfo,
    required this.isChannelPost,
    required this.onTap,
  });

  /// The message's `interactionInfo.replyInfo`.
  final Map<String, dynamic> replyInfo;

  final bool isChannelPost;
  final VoidCallback onTap;

  /// Whether replies arrived that the user has not seen.
  bool get _hasUnread {
    final last = replyInfo['lastMessageId'] as int? ?? 0;
    final read = replyInfo['lastReadInboxMessageId'] as int? ?? 0;
    return last > read;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = replyInfo['replyCount'] as int? ?? 0;
    final label = isChannelPost
        ? context.l10n.commentsCount(count)
        : context.l10n.repliesCount(count);

    // A full-width row closing the bubble, the way Telegram ends a channel
    // post: rule, label on the left, chevron pinned to the right edge.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.mode_comment_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                // Label and dot share one flexible slot; a Spacer beside a
                // Flexible would split the free space and halve the label.
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                      if (_hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: const Key('threadUnreadDot'),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
