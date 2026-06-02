import 'package:flutter/material.dart';

/// Actions offered by the message context menu.
enum MessageMenuAction { reply, copy, forward, delete }

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
}) {
  return showGeneralDialog<MessageMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Message actions',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, animation, secondaryAnimation) => _MessageMenu(
      availableReactions: availableReactions,
      canDelete: canDelete,
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

  const _MessageMenu({
    required this.availableReactions,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReactionBar(reactions: availableReactions),
          const SizedBox(height: 12),
          _MenuList(canDelete: canDelete),
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
                  for (final emoji in emojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context)
                          .pop(MessageMenuResult.react(emoji)),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
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

  const _MenuList({required this.canDelete});

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
              style: TextStyle(fontSize: 16, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
