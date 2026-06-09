import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Chat-specific color tokens that have no standard [ColorScheme] role:
/// bubble fills, the in-bubble link color, the presence dot, the inline-code
/// background, the date-separator pill, and the deterministic avatar palette.
///
/// Built via [ChatColors.harmonized] so fixed accent hues are blended toward
/// the active (possibly dynamic / Material You) palette, and [lerp] lets the
/// tokens cross-fade smoothly when the theme changes.
@immutable
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.bubbleLink,
    required this.onlineDot,
    required this.codeBackground,
    required this.dateSeparatorBg,
    required this.avatarPalette,
    required this.bubbleBorder,
  });

  /// Fill for incoming (received) message bubbles.
  final Color incomingBubble;

  /// Fill for outgoing (sent) message bubbles.
  final Color outgoingBubble;

  /// Color for links rendered inside message text.
  final Color bubbleLink;

  /// The online-presence indicator dot.
  final Color onlineDot;

  /// Background for inline code / pre spans.
  final Color codeBackground;

  /// Background pill behind the in-history date separator.
  final Color dateSeparatorBg;

  /// Deterministic background palette for letter (default) avatars. Each entry
  /// is dark enough that an estimated on-color stays legible (>= 4.5:1).
  final List<Color> avatarPalette;

  /// A hairline border drawn around message bubbles. Transparent in light
  /// themes (tonal fills suffice); a visible outline in the dark, where bubbles
  /// would otherwise blend into the background.
  final Color bubbleBorder;

  /// Derives chat tokens from [scheme], harmonizing fixed accent hues toward the
  /// active palette so they sit comfortably under Material You dynamic color.
  factory ChatColors.harmonized(ColorScheme scheme) {
    Color h(int value) => Color(value).harmonizeWith(scheme.primary);
    return ChatColors(
      incomingBubble: scheme.surfaceContainerHigh,
      outgoingBubble: scheme.primaryContainer,
      bubbleLink: scheme.primary,
      onlineDot: const Color(0xFF34C759).harmonizeWith(scheme.primary),
      codeBackground: scheme.surfaceContainerHighest,
      dateSeparatorBg: scheme.surfaceContainerHighest,
      avatarPalette: [
        h(0xFFD32F2F),
        h(0xFFE64A19),
        h(0xFF00897B),
        h(0xFF388E3C),
        h(0xFF1976D2),
        h(0xFF512DA8),
        h(0xFFC2185B),
        h(0xFF5D4037),
      ],
      bubbleBorder: scheme.brightness == Brightness.dark
          ? scheme.outlineVariant
          : Colors.transparent,
    );
  }

  @override
  ChatColors copyWith({
    Color? incomingBubble,
    Color? outgoingBubble,
    Color? bubbleLink,
    Color? onlineDot,
    Color? codeBackground,
    Color? dateSeparatorBg,
    List<Color>? avatarPalette,
    Color? bubbleBorder,
  }) {
    return ChatColors(
      incomingBubble: incomingBubble ?? this.incomingBubble,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      bubbleLink: bubbleLink ?? this.bubbleLink,
      onlineDot: onlineDot ?? this.onlineDot,
      codeBackground: codeBackground ?? this.codeBackground,
      dateSeparatorBg: dateSeparatorBg ?? this.dateSeparatorBg,
      avatarPalette: avatarPalette ?? this.avatarPalette,
      bubbleBorder: bubbleBorder ?? this.bubbleBorder,
    );
  }

  @override
  ChatColors lerp(covariant ThemeExtension<ChatColors>? other, double t) {
    if (other is! ChatColors) return this;
    return ChatColors(
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      bubbleLink: Color.lerp(bubbleLink, other.bubbleLink, t)!,
      onlineDot: Color.lerp(onlineDot, other.onlineDot, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      dateSeparatorBg: Color.lerp(dateSeparatorBg, other.dateSeparatorBg, t)!,
      avatarPalette: _lerpPalette(avatarPalette, other.avatarPalette, t),
      bubbleBorder: Color.lerp(bubbleBorder, other.bubbleBorder, t)!,
    );
  }

  static List<Color> _lerpPalette(List<Color> a, List<Color> b, double t) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return [for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
  }

  /// The avatar background for [seed] (e.g. a chat id), and a legible on-color.
  ({Color background, Color foreground}) avatarColors(int seed) {
    final background = avatarPalette[seed.abs() % avatarPalette.length];
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return (background: background, foreground: foreground);
  }
}
