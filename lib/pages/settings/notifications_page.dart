import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// A notification scope and its user-facing label.
typedef _Scope = ({String type, String label, String description});

/// Default notification settings per chat scope.
///
/// These are the defaults a chat inherits unless it was muted individually;
/// TDLib keeps them server-side so they follow the account across devices.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const List<_Scope> _scopes = [
    (
      type: 'notificationSettingsScopePrivateChats',
      label: 'Private chats',
      description: 'Messages from people and bots',
    ),
    (
      type: 'notificationSettingsScopeGroupChats',
      label: 'Groups',
      description: 'Messages in groups you are a member of',
    ),
    (
      type: 'notificationSettingsScopeChannelChats',
      label: 'Channels',
      description: 'Posts from channels you follow',
    ),
  ];

  /// Whether each scope is currently enabled, by scope type. Absent while the
  /// setting is still loading.
  final ValueNotifier<Map<String, bool>> _enabled = ValueNotifier(const {});
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _enabled.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = <String, bool>{};
    for (final scope in _scopes) {
      final settings = await TDLibClient.getScopeNotificationSettings(
        scope: scope.type,
      );
      loaded[scope.type] = (settings?['muteFor'] as int? ?? 0) == 0;
    }
    if (!mounted) return;
    _enabled.value = loaded;
    _isLoading.value = false;
  }

  Future<void> _setEnabled(String scope, bool enabled) async {
    _enabled.value = {..._enabled.value, scope: enabled};
    await TDLibClient.setScopeNotificationSettings(
      scope: scope,
      muteFor: enabled ? 0 : TDLibClient.muteForever,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications and sounds')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<Map<String, bool>>(
            valueListenable: _enabled,
            builder: (context, enabled, child) => ListView(
              padding: withBottomSafeArea(context),
              children: [
                for (final scope in _scopes)
                  SwitchListTile(
                    title: Text(scope.label),
                    subtitle: Text(scope.description),
                    value: enabled[scope.type] ?? true,
                    onChanged: (value) => _setEnabled(scope.type, value),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Individual chats keep their own mute setting, which '
                    'overrides these defaults.',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
