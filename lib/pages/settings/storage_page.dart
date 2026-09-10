import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Data and storage: how much space downloaded media takes, and clearing it.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final ValueNotifier<Map<String, dynamic>?> _stats = ValueNotifier(null);
  final ValueNotifier<bool> _isBusy = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stats.dispose();
    _isBusy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _isBusy.value = true;
    final stats = await TDLibClient.getStorageStatisticsFast();
    if (!mounted) return;
    _stats.value = stats;
    _isBusy.value = false;
  }

  Future<void> _clearCache() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.clearCacheQuestion),
        content: Text(
          context.l10n.clearCacheExplanation,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _isBusy.value = true;
    await TDLibClient.optimizeStorage();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dataAndStorage)),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isBusy,
        builder: (context, isBusy, child) {
          if (isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _stats,
            builder: (context, stats, child) => ListView(
              padding: withBottomSafeArea(context),
              children: [
                _StatTile(
                  icon: Icons.perm_media_outlined,
                  label: context.l10n.downloadedMedia,
                  value: _formatBytes(stats?['filesSize']),
                  detail: '${stats?['fileCount'] ?? 0} files',
                ),
                _StatTile(
                  icon: Icons.dataset_outlined,
                  label: context.l10n.localDatabase,
                  value: _formatBytes(stats?['databaseSize']),
                ),
                _StatTile(
                  icon: Icons.translate,
                  label: context.l10n.languagePacks,
                  value: _formatBytes(stats?['languagePackDatabaseSize']),
                ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton.tonalIcon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(context.l10n.clearCache),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    context.l10n.clearCacheNote,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Formats a byte count the way a storage screen should read: whole units,
  /// one decimal place, binary steps.
  static String _formatBytes(dynamic bytes) {
    final value = (bytes as num?)?.toDouble() ?? 0;
    if (value < 1024) return '${value.toInt()} B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var size = value / 1024;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(1)} ${units[unit]}';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: detail == null ? null : Text(detail!),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
