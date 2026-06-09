import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'app_text_theme.dart';
import 'call_colors.dart';
import 'chat_colors.dart';

/// Builds the light theme from an optional dynamic (Material You) [dynamicScheme],
/// falling back to a blue seed when the platform exposes no palette.
ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  final scheme = dynamicScheme?.harmonized() ??
      ColorScheme.fromSeed(seedColor: Colors.blue);
  return _themeFrom(scheme);
}

/// Builds the dark theme. When [amoled] is set, surfaces collapse to near-black
/// for OLED screens.
ThemeData buildDarkTheme(ColorScheme? dynamicScheme, {bool amoled = false}) {
  var scheme = dynamicScheme?.harmonized() ??
      ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
  // Dynamic / fromSeed dark schemes compress the surface tones so tightly that
  // bubbles, cards and dividers blend into the background (shadows are invisible
  // in the dark). Force an explicit, well-separated surface ladder so depth is
  // visible regardless of the source palette.
  scheme = amoled ? _amoled(scheme) : _boostDarkSurfaces(scheme);
  return _themeFrom(scheme);
}

/// A dark surface ladder with clearly distinct steps and a more visible outline,
/// so tonal elevation (bubbles, cards, composer, dividers) reads on any palette.
ColorScheme _boostDarkSurfaces(ColorScheme scheme) => scheme.copyWith(
      surface: const Color(0xFF131316),
      surfaceContainerLowest: const Color(0xFF0E0E11),
      surfaceContainerLow: const Color(0xFF1A1A1E),
      surfaceContainer: const Color(0xFF1E1E23),
      surfaceContainerHigh: const Color(0xFF282A30),
      surfaceContainerHighest: const Color(0xFF32333A),
      outlineVariant: const Color(0xFF45474E),
    );

/// Collapses a dark scheme's surfaces toward true black for OLED displays.
ColorScheme _amoled(ColorScheme scheme) => scheme.copyWith(
      surface: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF262626),
      outlineVariant: const Color(0xFF3A3A3A),
    );

ThemeData _themeFrom(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final textTheme = buildAppTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 3,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        // A hairline outline gives cards an edge in the dark, where tonal
        // elevation alone is hard to perceive and shadows don't show.
        side: scheme.brightness == Brightness.dark
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: Colors.transparent,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: [
      ChatColors.harmonized(scheme),
      CallColors.harmonized(scheme),
    ],
  );
}

/// Convenient theme-extension accessors for the chat/call token sets.
extension ThemeTokens on BuildContext {
  /// The chat color tokens for the current theme.
  ChatColors get chatColors => Theme.of(this).extension<ChatColors>()!;

  /// The call color tokens for the current theme.
  CallColors get callColors => Theme.of(this).extension<CallColors>()!;
}
