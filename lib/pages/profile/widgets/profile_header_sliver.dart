import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';

/// A collapsing profile header sliver.
///
/// When expanded it shows a large centered [ChatAvatar], the [title] in
/// `headlineSmall` and an optional [subtitle] in `bodyMedium`. As the user
/// scrolls it collapses to a standard app bar showing [title] alone.
class ProfileHeaderSliver extends StatelessWidget {
  /// The chat-shaped map passed to [ChatAvatar].
  final Map<String, dynamic> chat;

  /// The name shown both in the expanded block and as the collapsed title.
  final String title;

  /// An optional status line shown under the name while expanded.
  final String? subtitle;

  /// Actions rendered on the trailing edge of the app bar.
  final List<Widget>? actions;

  const ProfileHeaderSliver({
    super.key,
    required this.chat,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const expandedHeight = 280.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context.dependOnInheritedWidgetOfExactType<
              FlexibleSpaceBarSettings>();
          final deltaExtent = expandedHeight - kToolbarHeight;
          final current = (settings?.currentExtent ?? expandedHeight);
          // 0 when fully expanded, 1 when fully collapsed.
          final t = deltaExtent <= 0
              ? 1.0
              : (1 - ((current - kToolbarHeight) / deltaExtent))
                  .clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            centerTitle: true,
            titlePadding: EdgeInsets.zero,
            title: Opacity(
              opacity: t,
              child: SizedBox(
                height: kToolbarHeight,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ),
            background: SafeArea(
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'chat_avatar_${chat['id']}',
                        child: ChatAvatar(chat: chat, radius: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
