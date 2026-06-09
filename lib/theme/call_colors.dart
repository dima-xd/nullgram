import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Call-screen color tokens. Accept/decline accents are harmonized toward the
/// active palette; the call surface is an immersive dark tone used behind the
/// caller avatar.
@immutable
class CallColors extends ThemeExtension<CallColors> {
  const CallColors({
    required this.accept,
    required this.decline,
    required this.callSurface,
    required this.onCallSurface,
  });

  /// Accept / answer action color.
  final Color accept;

  /// Decline / hang-up action color.
  final Color decline;

  /// Immersive background surface for the call screen.
  final Color callSurface;

  /// Foreground (text/icon) color on [callSurface].
  final Color onCallSurface;

  factory CallColors.harmonized(ColorScheme scheme) {
    return CallColors(
      accept: const Color(0xFF34C759).harmonizeWith(scheme.primary),
      decline: scheme.error,
      callSurface: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.06),
        const Color(0xFF101014),
      ),
      onCallSurface: Colors.white,
    );
  }

  @override
  CallColors copyWith({
    Color? accept,
    Color? decline,
    Color? callSurface,
    Color? onCallSurface,
  }) {
    return CallColors(
      accept: accept ?? this.accept,
      decline: decline ?? this.decline,
      callSurface: callSurface ?? this.callSurface,
      onCallSurface: onCallSurface ?? this.onCallSurface,
    );
  }

  @override
  CallColors lerp(covariant ThemeExtension<CallColors>? other, double t) {
    if (other is! CallColors) return this;
    return CallColors(
      accept: Color.lerp(accept, other.accept, t)!,
      decline: Color.lerp(decline, other.decline, t)!,
      callSurface: Color.lerp(callSurface, other.callSurface, t)!,
      onCallSurface: Color.lerp(onCallSurface, other.onCallSurface, t)!,
    );
  }
}
