import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nullgram/theme/motion.dart';

/// Actions offered by the message context menu.
enum MessageMenuAction { reply, edit, copy, forward, pin, unpin, delete }

/// The outcome of a message long-press.
///
/// Exactly one of [action] or [reactEmoji] is set: [reactEmoji] when the user
/// picked an emoji from the quick-reaction bar, [action] otherwise.
class MessageMenuResult {
  final MessageMenuAction? action;
  final String? reactEmoji;

  const MessageMenuResult.action(this.action) : reactEmoji = null;
  const MessageMenuResult.react(this.reactEmoji) : action = null;
}

/// Shows the Telegram-style long-press overlay for a message: a floating
/// quick-reaction bar above a context menu (Reply / Copy / Forward / Delete).
///
/// [availableReactions] resolves to the emoji the chat allows; the bar appears
/// once it completes. Returns the chosen [MessageMenuResult], or null if
/// dismissed.
Future<MessageMenuResult?> showMessageContextMenu({
  required BuildContext context,
  required Future<List<String>> availableReactions,
  required bool canDelete,
  bool canEdit = false,
  bool canPin = false,
  bool isPinned = false,
}) {
  return showGeneralDialog<MessageMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Message actions',
    barrierColor:
        Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, animation, secondaryAnimation) => _MessageMenu(
      availableReactions: availableReactions,
      canDelete: canDelete,
      canEdit: canEdit,
      canPin: canPin,
      isPinned: isPinned,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _MessageMenu extends StatelessWidget {
  final Future<List<String>> availableReactions;
  final bool canDelete;
  final bool canEdit;
  final bool canPin;
  final bool isPinned;

  const _MessageMenu({
    required this.availableReactions,
    required this.canDelete,
    required this.canEdit,
    required this.canPin,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReactionBar(reactions: availableReactions),
          const SizedBox(height: 12),
          _MenuList(
            canDelete: canDelete,
            canEdit: canEdit,
            canPin: canPin,
            isPinned: isPinned,
          ),
        ],
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  final Future<List<String>> reactions;

  const _ReactionBar({required this.reactions});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: reactions,
      builder: (context, snapshot) {
        final emojis = snapshot.data ?? const [];
        if (emojis.isEmpty) return const SizedBox.shrink();

        return Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, emoji) in emojis.indexed)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context)
                          .pop(MessageMenuResult.react(emoji)),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    )
                        .animate()
                        .scale(
                          delay: (index * 40).ms,
                          duration: Motion.fast,
                          curve: Motion.emphasized,
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1.0, 1.0),
                        )
                        .fadeIn(
                          delay: (index * 40).ms,
                          duration: Motion.fast,
                          curve: Motion.standard,
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuList extends StatelessWidget {
  final bool canDelete;
  final bool canEdit;
  final bool canPin;
  final bool isPinned;

  const _MenuList({
    required this.canDelete,
    required this.canEdit,
    required this.canPin,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              icon: Icons.reply,
              label: 'Reply',
              onTap: () => Navigator.of(context)
                  .pop(const MessageMenuResult.action(MessageMenuAction.reply)),
            ),
            if (canEdit)
              _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => Navigator.of(context)
                    .pop(const MessageMenuResult.action(MessageMenuAction.edit)),
              ),
            _MenuItem(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () => Navigator.of(context)
                  .pop(const MessageMenuResult.action(MessageMenuAction.copy)),
            ),
            _MenuItem(
              icon: Icons.forward,
              label: 'Forward',
              onTap: () => Navigator.of(context).pop(
                  const MessageMenuResult.action(MessageMenuAction.forward)),
            ),
            if (canPin)
              _MenuItem(
                icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: isPinned ? 'Unpin' : 'Pin',
                onTap: () => Navigator.of(context).pop(MessageMenuResult.action(
                    isPinned
                        ? MessageMenuAction.unpin
                        : MessageMenuAction.pin)),
              ),
            if (canDelete)
              _MenuItem(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: scheme.error,
                onTap: () => Navigator.of(context).pop(
                    const MessageMenuResult.action(MessageMenuAction.delete)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
