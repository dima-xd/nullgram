import 'package:flutter/animation.dart';

/// Centralized motion tokens so every animation in the app shares one
/// vocabulary of durations and curves instead of ad-hoc literals.
abstract final class Motion {
  /// Quick state-layer / toggle feedback (≈ M3 short duration).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard component transition (banners, switchers, list inserts).
  static const Duration medium = Duration(milliseconds: 250);

  /// Larger, expressive transitions (poll fills, page-level motion).
  static const Duration slow = Duration(milliseconds: 400);

  /// Default easing for entering/settling elements.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasized easing for expressive, attention-drawing motion.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}
