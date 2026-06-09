import 'package:flutter/material.dart';
import 'package:nullgram/main.dart' show themeModeNotifier, amoledNotifier;
import 'package:nullgram/tdlib/tdlib_client.dart';

/// App settings: theme selection and account sign-out.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Theme'),
          const _ThemeModeSelector(),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: amoledNotifier,
                builder: (context, amoled, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.contrast),
                    title: const Text('AMOLED dark'),
                    subtitle: const Text('Use true black surfaces'),
                    value: amoled,
                    onChanged: mode == ThemeMode.light
                        ? null
                        : (value) => amoledNotifier.value = value,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Account'),
          const _LogoutTile(),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
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
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
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
            'Log out',
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
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
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
