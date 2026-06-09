import 'package:flutter/material.dart';

/// Shared visual building blocks for the authentication screens.
///
/// Centralizing these keeps every auth page (phone, code, password) on a
/// single, consistent Telegram-like look and removes the duplicated
/// container/shadow/button code that used to live in each page.

/// Standard full-screen layout for an auth page: tinted background, optional
/// transparent app bar with a back button, and a centered, width-constrained,
/// scrollable body.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.showBackButton = false,
    this.onBack,
    super.key,
  });

  /// The page content, typically a [Column].
  final Widget child;

  /// Whether to render a transparent app bar. When [onBack] is null the
  /// framework supplies the default pop affordance for pushed routes.
  final bool showBackButton;

  /// Custom back handler. When provided, overrides the default pop button.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final showAppBar = showBackButton || onBack != null;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: onBack != null ? BackButton(onPressed: onBack) : null,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular accent badge, headline, and optional subtitle shown at the top of
/// every auth page.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    this.subtitle,
    this.icon = Icons.send_rounded,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary,
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 42, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Tonal container that wraps an input. Highlights in the error color when
/// [hasError] is true.
///
/// Uses a flat Material 3 tonal surface ([ColorScheme.surfaceContainerHigh])
/// instead of a shadowed card.
class AuthInputContainer extends StatelessWidget {
  const AuthInputContainer({
    required this.child,
    this.hasError = false,
    this.padding,
    super.key,
  });

  final Widget child;
  final bool hasError;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: hasError ? Border.all(color: scheme.error, width: 1.5) : null,
      ),
      child: child,
    );
  }
}

/// Borderless [InputDecoration] tuned for use inside an [AuthInputContainer].
///
/// The fill is transparent so the input blends into its surrounding
/// [AuthInputContainer]; standalone fields should use a plain
/// [InputDecoration] and inherit the global filled style instead.
InputDecoration authInputDecoration({
  String? hintText,
  Widget? prefixIcon,
  String? counterText,
}) {
  const transparent = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    counterText: counterText,
    border: transparent,
    enabledBorder: transparent,
    focusedBorder: transparent,
    filled: true,
    fillColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
  );
}

/// Shows a friendly, error-tinted [SnackBar] on the [ColorScheme.errorContainer]
/// surface.
///
/// Keeps raw exception strings out of the UI; pass a user-facing [message].
void showAuthError(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        backgroundColor: scheme.errorContainer,
      ),
    );
}

/// Shows a neutral informational [SnackBar].
void showAuthInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Full-width primary action button with a built-in loading state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: loading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ],
            ),
    );
  }
}
