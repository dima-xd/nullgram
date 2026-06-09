import 'package:flutter/material.dart';
import 'package:nullgram/widgets/lottie_state.dart';

/// A centered placeholder for empty or no-result states.
///
/// Shows a large outlined [icon] above a [title] and optional [subtitle],
/// styled from the current theme. When [lottieAsset] is set, an animated
/// [LottieState] replaces the static icon (falling back to the icon if the
/// asset can't be loaded).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.lottieAsset,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? lottieAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lottieAsset != null)
              LottieState(asset: lottieAsset!, fallbackIcon: icon, size: 150)
            else
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
