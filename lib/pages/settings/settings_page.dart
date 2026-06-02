import 'package:flutter/material.dart';
import 'package:nullgram/main.dart' show themeModeNotifier;
import 'package:nullgram/tdlib/tdlib_client.dart';

/// App settings: theme selection and account sign-out.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, child) {
              return RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: _setMode,
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('System default'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Light'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Dark'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Log out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _setMode(ThemeMode? mode) {
    if (mode != null) themeModeNotifier.value = mode;
  }

  Future<void> _confirmLogout(BuildContext context) async {
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
          TextButton(
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
