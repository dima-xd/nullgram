import 'package:flutter/material.dart';

/// Builds the app-wide Material 3 type scale on top of the platform default
/// [base] typography.
///
/// Keeps the system font (Roboto/SF) but gives titles deliberate weight and
/// tunes message-body line-height (~1.4) for readability per the design system.
TextTheme buildAppTextTheme(TextTheme base) {
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    labelSmall: base.labelSmall?.copyWith(letterSpacing: 0.2),
  );
}
