import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// A notification scope and its user-facing label.
typedef _Scope = ({String type, String label, String description});

/// The scopes TDLib keeps defaults for, in the order they are shown.
const List<String> _scopeTypes = [
  'notificationSettingsScopePrivateChats',
  'notificationSettingsScopeGroupChats',
  'notificationSettingsScopeChannelChats',
];

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
  /// The scopes with their translated labels, built per call.
  ///
  /// The types themselves live in [_scopeTypes], which stays const so the
  /// loading pass does not need a context.
  static List<_Scope> _scopesOf(BuildContext context) => [
    (
      type: _scopeTypes[0],
      label: context.l10n.privateChats,
      description: context.l10n.notifyPrivateDescription,
    ),
    (
      type: _scopeTypes[1],
      label: context.l10n.groups,
      description: context.l10n.notifyGroupsDescription,
    ),
    (
      type: _scopeTypes[2],
      label: context.l10n.channels,
      description: context.l10n.notifyChannelsDescription,
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
    for (final scope in _scopeTypes) {
      final settings = await TDLibClient.getScopeNotificationSettings(
        scope: scope,
      );
      loaded[scope] = (settings?['muteFor'] as int? ?? 0) == 0;
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
      appBar: AppBar(title: Text(context.l10n.notificationsAndSounds)),
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
                for (final scope in _scopesOf(context))
                  SwitchListTile(
                    title: Text(scope.label),
                    subtitle: Text(scope.description),
                    value: enabled[scope.type] ?? true,
                    onChanged: (value) => _setEnabled(scope.type, value),
                  ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    context.l10n.notificationScopeHint,
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
