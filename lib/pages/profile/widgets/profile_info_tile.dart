import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single row of profile information: a leading [icon], a small [label] and
/// a larger [value].
///
/// When [copyable] is set, tapping the tile copies [value] to the clipboard and
/// shows a floating "Copied" snack bar. When [onTap] is provided (e.g. for an
/// editable field) the tile becomes tappable and shows a trailing edit icon.
class ProfileInfoTile extends StatelessWidget {
  /// The leading icon describing the kind of information.
  final IconData icon;

  /// The small caption shown under the value (e.g. "Phone").
  final String label;

  /// The main text of the tile (e.g. the phone number).
  final String value;

  /// Called when the tile is tapped, typically to edit the value.
  final VoidCallback? onTap;

  /// Whether tapping copies [value] to the clipboard.
  final bool copyable;

  /// Whether to show a trailing edit affordance.
  final bool editable;

  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.copyable = false,
    this.editable = false,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final VoidCallback? effectiveOnTap = onTap ??
        (copyable ? () => _copy(context) : null);

    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(
        value,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: editable
          ? Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant)
          : null,
      onTap: effectiveOnTap,
    );
  }
}
