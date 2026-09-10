import 'package:flutter/material.dart';
import 'package:nullgram/services/auto_download.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// What the app is allowed to fetch on its own, per connection.
class AutoDownloadPage extends StatelessWidget {
  const AutoDownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AutoDownloadService.instance;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.automaticMediaDownload)),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, child) => ListView(
          padding: withBottomSafeArea(
            context,
            const EdgeInsets.only(bottom: 24),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.autoDownloadExplanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final network in AutoDownloadNetwork.values)
              _NetworkSection(
                network: network,
                rules: service.rulesFor(network),
                isActive: service.current == network,
                onChanged: (rules) => service.update(network, rules),
              ),
          ],
        ),
      ),
    );
  }
}

/// The block of controls for one connection.
class _NetworkSection extends StatelessWidget {
  const _NetworkSection({
    required this.network,
    required this.rules,
    required this.isActive,
    required this.onChanged,
  });

  final AutoDownloadNetwork network;
  final AutoDownloadRules rules;

  /// Whether this is the connection in use, which the header points out so
  /// the settings that matter right now are obvious.
  final bool isActive;

  final ValueChanged<AutoDownloadRules> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(
                _networkLabel(context, network),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Text(
                  context.l10n.proxyInUse,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.downloadAutomatically),
          value: rules.isEnabled,
          onChanged: (value) => onChanged(rules.copyWith(isEnabled: value)),
        ),
        _LimitTile(
          title: context.l10n.photos,
          icon: Icons.photo_outlined,
          bytes: rules.maxPhotoBytes,
          isEnabled: rules.isEnabled,
          steps: _photoSteps,
          onChanged: (bytes) => onChanged(rules.copyWith(maxPhotoBytes: bytes)),
        ),
        _LimitTile(
          title: context.l10n.videos,
          icon: Icons.videocam_outlined,
          bytes: rules.maxVideoBytes,
          isEnabled: rules.isEnabled,
          steps: _videoSteps,
          onChanged: (bytes) => onChanged(rules.copyWith(maxVideoBytes: bytes)),
        ),
        _LimitTile(
          title: context.l10n.filesAndVoice,
          icon: Icons.insert_drive_file_outlined,
          bytes: rules.maxOtherBytes,
          isEnabled: rules.isEnabled,
          steps: _otherSteps,
          onChanged: (bytes) => onChanged(rules.copyWith(maxOtherBytes: bytes)),
        ),
      ],
    );
  }

  /// The ceilings offered per kind, in bytes. Zero means "never".
  static const List<int> _photoSteps = [
    0,
    512 * 1024,
    2 * 1024 * 1024,
    10 * 1024 * 1024,
  ];
  static const List<int> _videoSteps = [
    0,
    2 * 1024 * 1024,
    15 * 1024 * 1024,
    100 * 1024 * 1024,
  ];
  static const List<int> _otherSteps = [
    0,
    1024 * 1024,
    3 * 1024 * 1024,
    20 * 1024 * 1024,
  ];
}

/// One size ceiling, chosen from a short list rather than a free slider.
///
/// A slider over a byte range invites values nobody wants; Telegram offers a
/// handful of steps and so does this.
class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.title,
    required this.icon,
    required this.bytes,
    required this.isEnabled,
    required this.steps,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final int bytes;
  final bool isEnabled;
  final List<int> steps;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: isEnabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(formatLimit(context, bytes)),
      trailing: PopupMenuButton<int>(
        enabled: isEnabled,
        icon: const Icon(Icons.edit_outlined),
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final step in _choices)
            PopupMenuItem(
              value: step,
              child: Text(formatLimit(context, step)),
            ),
        ],
      ),
    );
  }

  /// The offered steps, plus whatever value is stored, so a limit that came
  /// from another client is still selectable and visible.
  List<int> get _choices {
    final choices = {...steps, bytes}.toList()..sort();
    return choices;
  }
}

/// The name of a connection, as the settings list shows it.
String _networkLabel(BuildContext context, AutoDownloadNetwork network) =>
    switch (network) {
      AutoDownloadNetwork.mobile => context.l10n.mobileData,
      AutoDownloadNetwork.wifi => context.l10n.wifi,
    };

/// Renders a byte ceiling the way the settings list shows it.
String formatLimit(BuildContext context, int bytes) {
  if (bytes <= 0) return context.l10n.never;
  if (bytes < 1024 * 1024) {
    return context.l10n.upToSize('${(bytes / 1024).round()} KB');
  }
  final megabytes = bytes / (1024 * 1024);
  final rounded = megabytes >= 10
      ? megabytes.round().toString()
      : megabytes.toStringAsFixed(1);
  return context.l10n.upToSize('$rounded MB');
}
