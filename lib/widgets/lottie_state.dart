import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

/// Renders a Lottie animation from [asset], gracefully degrading to a gently
/// animated themed icon if the asset is missing or fails to parse — so a
/// missing or invalid animation file never breaks the screen.
class LottieState extends StatelessWidget {
  /// Bundled Lottie asset path, e.g. `assets/lottie/empty.json`.
  final String asset;

  /// Icon used by the animated fallback when the Lottie can't be shown.
  final IconData fallbackIcon;

  final double size;
  final bool repeat;

  const LottieState({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.size = 140,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            _AnimatedFallbackIcon(icon: fallbackIcon, size: size),
      ),
    );
  }
}

/// A breathing icon shown when a Lottie asset is unavailable.
class _AnimatedFallbackIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _AnimatedFallbackIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Icon(icon, size: size * 0.5, color: color)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 0.92,
            end: 1.08,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
          ),
    );
  }
}
