import 'package:flutter/material.dart';
import 'package:nullgram/app_info.dart';
import 'package:nullgram/main.dart' show themeModeNotifier, amoledNotifier;
import 'package:nullgram/pages/settings/notifications_page.dart';
import 'package:nullgram/pages/settings/auto_download_page.dart';
import 'package:nullgram/pages/settings/chat_folders_page.dart';
import 'package:nullgram/pages/settings/proxy_page.dart';
import 'package:nullgram/services/language_service.dart';
import 'package:nullgram/pages/settings/privacy_page.dart';
import 'package:nullgram/pages/settings/sessions_page.dart';
import 'package:nullgram/pages/settings/storage_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The settings hub: appearance, notifications, privacy, storage and account.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: withBottomSafeArea(
          context,
          const EdgeInsets.only(bottom: 24),
        ),
        children: [
          const _SectionHeader('Appearance'),
          const _ThemeModeSelector(),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: amoledNotifier,
                builder: (context, amoled, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.contrast),
                    title: Text(context.l10n.amoledDark),
                    subtitle: Text(context.l10n.amoledDarkSubtitle),
                    value: amoled,
                    onChanged: mode == ThemeMode.light
                        ? null
                        : (value) => amoledNotifier.value = value,
                  );
                },
              );
            },
          ),
          const _SectionHeader('Preferences'),
          _NavigationTile(
            icon: Icons.notifications_outlined,
            title: context.l10n.notificationsAndSounds,
            page: () => const NotificationsPage(),
          ),
          _NavigationTile(
            icon: Icons.folder_outlined,
            title: context.l10n.chatFolders,
            page: () => const ChatFoldersPage(),
          ),
          _NavigationTile(
            icon: Icons.lock_outline,
            title: context.l10n.privacyAndSecurity,
            page: () => const PrivacyPage(),
          ),
          _NavigationTile(
            icon: Icons.devices_outlined,
            title: context.l10n.devices,
            page: () => const SessionsPage(),
          ),
          _NavigationTile(
            icon: Icons.storage_outlined,
            title: context.l10n.dataAndStorage,
            page: () => const StoragePage(),
          ),
          _NavigationTile(
            icon: Icons.download_outlined,
            title: context.l10n.automaticMediaDownload,
            page: () => const AutoDownloadPage(),
          ),
          _NavigationTile(
            icon: Icons.vpn_key_outlined,
            title: context.l10n.proxy,
            page: () => const ProxyPage(),
          ),
          const _LanguageTile(),
          const _SectionHeader('Account'),
          const _LogoutTile(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              context.l10n.appVersionLabel(appVersion),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A primary-tinted section title.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// A row that pushes a settings subpage.
class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.title,
    required this.page,
  });

  final IconData icon;
  final String title;
  final Widget Function() page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page()),
      ),
    );
  }
}

/// The interface language, with an option to follow the system.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(context.l10n.interfaceLanguage),
        subtitle: Text(
          appLanguages[locale?.languageCode] ?? context.l10n.followSystem,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pick(context, locale),
      ),
    );
  }

  Future<void> _pick(BuildContext context, Locale? current) async {
    // A sentinel for "follow the system": the picker's value is nullable, and
    // a null result would otherwise be indistinguishable from a dismissal.
    const followSystem = '';

    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current?.languageCode ?? followSystem,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<String>(
                value: followSystem,
                title: Text(sheetContext.l10n.followSystem),
              ),
              for (final entry in appLanguages.entries)
                RadioListTile<String>(
                  value: entry.key,
                  title: Text(entry.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await setAppLanguage(chosen == followSystem ? null : chosen);
  }
}

/// A segmented control bound to [themeModeNotifier].
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, child) {
          return SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(context.l10n.system),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(context.l10n.light),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(context.l10n.dark),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                themeModeNotifier.value = selection.first,
          );
        },
      ),
    );
  }
}

/// An error-tinted card that signs the current user out after confirmation.
class _LogoutTile extends StatelessWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.logout, color: scheme.onErrorContainer),
          title: Text(
            context.l10n.logOut,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: scheme.onErrorContainer),
          ),
          onTap: () => _confirmLogout(context),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logOutQuestion),
        content: Text(context.l10n.logOutWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.logOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // The auth-state listener in main.dart routes back to the login flow once
      // TDLib reports the logged-out state.
      await TDLibClient.logOut();
    }
  }
}
