import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/l10n/app_localizations.dart';
import 'package:nullgram/main.dart';
import 'package:nullgram/pages/chat/chat_route.dart';
import 'package:nullgram/services/account_manager.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/services/language_service.dart';
import 'package:nullgram/services/notification_groups.dart';
import 'package:nullgram/services/notification_text.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

// A production filter, or a release build logs nothing at all and a failed
// render leaves nothing behind but a missing notification.
final _log = Logger(filter: ProductionFilter());

/// Renders TDLib's notification groups as Android notifications, on every
/// account, for both the running app and the push isolate.
class NotificationService {
  NotificationService._();

  /// The shared instance.
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'messages';
  static const String _channelName = 'Messages';

  final NotificationGroups _groups = NotificationGroups();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  AndroidFlutterLocalNotificationsPlugin? _android;

  AppLocalizations? _l10n;

  Locale? _l10nLocale;

  /// The chat currently on screen, a guard against a notification posted just
  /// before TDLib's own removal update lands.
  int? activeChatId;

  /// Whether this isolate draws the app. False in the push isolate, where
  /// there is no account on screen to leave unnamed.
  bool hasUi = false;

  /// A tap that arrived before the accounts were online, held until there is
  /// a client to act on it with.
  NotificationResponse? _pendingResponse;

  bool _accountsOnline = false;

  /// Initializes the plugin, the channel and the update subscription.
  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    _android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      ),
    );

    _subscription ??= TDLibClient.notificationUpdates.listen(_onUpdate);

    _log.i('NotificationService initialized');
  }

  /// Requests the runtime notification permission. Call once a foreground
  /// activity exists (Android 13+ shows no dialog when called too early).
  Future<void> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    final enabled = await _android?.areNotificationsEnabled();
    _log.i('Notifications permission granted=$granted enabled=$enabled');
  }

  Future<void> _onUpdate(Map<String, dynamic> update) async {
    try {
      final accountId =
          update['@accountId'] as int? ?? TDLibClient.activeAccountId;
      final change = _groups.apply(update, accountId);

      // A snapshot only restates notifications the user was alerted to before,
      // so it repaints the shade rather than announcing itself again.
      final silent = update['@type'] == updateActiveNotificationsConst;

      for (final removed in change.removed) {
        await _plugin.cancel(
          id: notificationId(removed.accountId, removed.groupId),
        );
      }
      for (final group in change.updated) {
        await _show(group, silent: silent);
      }
    } catch (e, s) {
      _log.e(
        'Failed to handle a notification update',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> _show(NotificationGroup group, {bool silent = false}) async {
    try {
      // Without a UI no account is on screen, so every notification names
      // the account it belongs to.
      final isActive =
          hasUi && group.accountId == TDLibClient.activeAccountId;
      if (isActive && group.chatId == activeChatId) return;

      final l10n = await _localizations();
      final chat = await _chat(group.chatId, group.accountId);
      final title = chat?['title'] as String? ?? l10n.notificationMessage;
      final isGroup = _isGroupChat(chat);

      final messages = await _messages(group, title, l10n);

      final details = AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        silent: silent || group.notifications.last.isSilent,
        // Names the account only when it is not the one on screen, and groups
        // each account's notifications together in the shade.
        subText: isActive ? null : _accountName(group.accountId),
        groupKey: 'account_${group.accountId}',
        largeIcon: await _avatar(chat, group.accountId),
        styleInformation: MessagingStyleInformation(
          Person(name: l10n.notificationYou, key: 'self'),
          conversationTitle: title,
          groupConversation: isGroup,
          messages: messages,
        ),
        actions: [
          AndroidNotificationAction(
            'reply',
            l10n.notificationReply,
            inputs: [
              AndroidNotificationActionInput(label: l10n.notificationReply),
            ],
            // Both actions come to the app: only the foreground isolate has a
            // TDLib client to act with.
            showsUserInterface: true,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'read',
            l10n.notificationMarkRead,
            showsUserInterface: true,
          ),
        ],
      );

      // Several updates for one group can be in flight, and this render has
      // awaited many round trips: drop it once a newer one superseded it.
      final current = _groups.group(group.accountId, group.groupId);
      if (current == null || !identical(current, group)) return;

      await _plugin.show(
        id: notificationId(group.accountId, group.groupId),
        title: title,
        body: messages.last.text,
        notificationDetails: NotificationDetails(android: details),
        payload: encodePayload(group),
      );
      _log.i('Notification shown for group ${group.groupId} '
          'of account ${group.accountId}');
    } catch (e, s) {
      _log.e('Failed to show a notification', error: e, stackTrace: s);
    }
  }

  /// One [Message] per notification, each attributed to its sender so that
  /// `MessagingStyle` can tell a group chat's participants apart.
  Future<List<Message>> _messages(
    NotificationGroup group,
    String title,
    AppLocalizations l10n,
  ) async {
    final resolved = <String, String>{};
    final messages = <Message>[];
    for (final entry in group.notifications) {
      final sender = await _senderOf(entry, group.accountId, title, resolved);
      messages.add(
        Message(
          notificationPreview(entry.type, l10n),
          DateTime.fromMillisecondsSinceEpoch(entry.date * 1000),
          Person(name: sender, key: 'sender_$sender'),
        ),
      );
    }
    return messages;
  }

  /// The sender's display name, or [title] when there is none. [resolved]
  /// caches the lookups, as one group holds several messages per sender.
  Future<String> _senderOf(
    NotificationEntry entry,
    int accountId,
    String title,
    Map<String, String> resolved,
  ) async {
    final pushName = notificationSender(entry.type);
    if (pushName != null) return pushName;
    if (entry.type['@type'] != 'NotificationTypeNewMessage') return title;

    final message = (entry.type['message'] as Map?)?.cast<String, dynamic>();
    final senderId = message?['senderId'];
    if (senderId is! Map) return title;

    final key = '${senderId['@type']}:'
        '${senderId['userId'] ?? senderId['chatId']}';
    final cached = resolved[key];
    if (cached != null) return cached;

    String? name;
    try {
      name = await _senderName(senderId, accountId);
    } catch (e) {
      _log.w('Notification sender $key could not be resolved: $e');
    }
    return resolved[key] = name == null || name.isEmpty ? title : name;
  }

  /// Resolves the display name of a message sender (a user or a chat).
  Future<String?> _senderName(Map<dynamic, dynamic> senderId, int accountId) {
    switch (senderId['@type']) {
      case 'MessageSenderUser':
        return _userName(senderId['userId'] as int?, accountId);
      case 'MessageSenderChat':
        return _chatTitle(senderId['chatId'] as int?, accountId);
      default:
        return Future.value();
    }
  }

  Future<String?> _userName(int? userId, int accountId) async {
    if (userId == null) return null;
    final user = await TDLibClient.getUser(
      userId: userId,
      accountId: accountId,
    );
    if (user == null) return null;
    return [user['firstName'], user['lastName']]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  Future<String?> _chatTitle(int? chatId, int accountId) async {
    if (chatId == null) return null;
    final chat = await _chat(chatId, accountId);
    return chat?['title'] as String?;
  }

  /// Resolves a chat, using the in-memory store only for the active account:
  /// another account's chat id would answer with an unrelated chat.
  Future<Map<String, dynamic>?> _chat(int chatId, int accountId) async {
    if (accountId == TDLibClient.activeAccountId) {
      final cached = ChatStore.instance.chat(chatId);
      if (cached != null) return cached;
    }
    try {
      return await TDLibClient.getChat(chatId: chatId, accountId: accountId);
    } catch (e) {
      _log.w('Notification chat $chatId could not be resolved: $e');
      return null;
    }
  }

  bool _isGroupChat(Map<String, dynamic>? chat) {
    final type = chat?['type']?['@type'];
    return type == 'ChatTypeBasicGroup' ||
        (type == 'ChatTypeSupergroup' && chat?['type']?['isChannel'] != true);
  }

  /// The chat's avatar as a file on disk, or null when it is not there yet: a
  /// notification must appear now, and the push isolate has seconds to live.
  Future<AndroidBitmap<Object>?> _avatar(
    Map<String, dynamic>? chat,
    int accountId,
  ) async {
    final fileId = chat?['photo']?['small']?['id'] as int?;
    if (fileId == null) return null;
    try {
      final file =
          await TDLibClient.getFile(fileId: fileId, accountId: accountId);
      final path = file?['local']?['path'] as String?;
      final isDownloaded = file?['local']?['isDownloadingCompleted'] == true;
      if (isDownloaded && path != null && path.isNotEmpty) {
        return FilePathAndroidBitmap(path);
      }
      // Fetched for the next notification of this chat rather than this one.
      unawaited(
        TDLibClient.downloadFile(fileId: fileId, accountId: accountId)
            .catchError((Object e) => _log.w('Avatar $fileId failed: $e')),
      );
    } catch (e) {
      _log.w('Notification avatar $fileId could not be resolved: $e');
    }
    return null;
  }

  /// The display name of an account, for a notification that did not come from
  /// the one on screen.
  String? _accountName(int accountId) {
    final name = AccountManager.instance.accountOf(accountId)?.name;
    return name == null || name.isEmpty ? null : name;
  }

  /// The strings of the chosen interface language, or of the system one.
  /// There is no BuildContext here, and none at all in the push isolate.
  Future<AppLocalizations> _localizations() async {
    final locale = localeNotifier.value ??
        Locale(PlatformDispatcher.instance.locale.languageCode);
    final cached = _l10n;
    if (cached != null && _l10nLocale == locale) return cached;
    _l10nLocale = locale;
    return _l10n = await AppLocalizations.delegate.load(locale);
  }

  /// Clears every notification of [chatId], used once its messages are read.
  Future<void> clearChat(int chatId, {int? accountId}) async {
    final target = accountId ?? TDLibClient.activeAccountId;
    for (final group in _groups.groups) {
      if (group.accountId != target || group.chatId != chatId) continue;
      await _plugin.cancel(id: notificationId(target, group.groupId));
      await TDLibClient.removeNotificationGroup(
        notificationGroupId: group.groupId,
        maxNotificationId: group.notifications.last.id,
        accountId: target,
      );
    }
  }

  /// Cancels every notification of [accountId], for a sign-out.
  Future<void> clearAccount(int accountId) async {
    for (final removed in _groups.clearAccount(accountId)) {
      await _plugin.cancel(id: notificationId(accountId, removed.groupId));
    }
  }

  void _onResponse(NotificationResponse response) {
    if (!_accountsOnline) {
      _pendingResponse = response;
      return;
    }
    unawaited(_handleResponse(response));
  }

  /// Acts on the notification the app was launched from, and on anything
  /// tapped while the accounts were still coming online. Call once they are.
  Future<void> onAccountsOnline() async {
    _accountsOnline = true;
    try {
      // A cold start never fires the response callback: the launching intent
      // is only readable through the plugin's launch details.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final launched = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && launched != null) {
        await _handleResponse(launched);
      }
    } catch (e, s) {
      _log.e('Failed to read the launch notification', error: e, stackTrace: s);
    }
    final pending = _pendingResponse;
    _pendingResponse = null;
    if (pending != null) await _handleResponse(pending);
  }

  /// Carries out a tap: a reply, a mark as read, or opening the chat.
  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = decodePayload(response.payload);
    if (payload == null) return;
    try {
      switch (response.actionId) {
        case 'reply':
          final text = response.input;
          if (text == null || text.isEmpty) break;
          await TDLibClient.sendMessage(
            chatId: payload.chatId,
            text: text,
            accountId: payload.accountId,
          );
          // The reply action keeps its notification on purpose, so a failed
          // send leaves it up; it goes once the message is away.
          await _plugin.cancel(
            id: notificationId(payload.accountId, payload.groupId),
          );
          await _markRead(payload);
          await _removeGroup(payload);
        case 'read':
          await _markRead(payload);
          await _removeGroup(payload);
        default:
          await _openChat(payload.accountId, payload.chatId);
      }
    } catch (e, s) {
      _log.e('Failed to handle a notification tap', error: e, stackTrace: s);
    }
  }

  /// Advances the chat's read inbox, which is what makes the chat read on
  /// the user's other devices too.
  Future<void> _markRead(NotificationPayload payload) async {
    if (payload.messageId == 0) return;
    await TDLibClient.viewMessages(
      chatId: payload.chatId,
      messageIds: [payload.messageId],
      forceRead: true,
      accountId: payload.accountId,
    );
  }

  Future<void> _removeGroup(NotificationPayload payload) =>
      TDLibClient.removeNotificationGroup(
        notificationGroupId: payload.groupId,
        maxNotificationId: payload.maxNotificationId,
        accountId: payload.accountId,
      );

  Future<void> _openChat(int accountId, int chatId) async {
    // A tap that started the app is handled before the first frame, when
    // there is no navigator to push onto yet.
    if (navigatorKey.currentState == null) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (accountId != TDLibClient.activeAccountId) {
      await AccountManager.instance.switchTo(accountId);
    }
    final chat = ChatStore.instance.chat(chatId) ??
        await TDLibClient.getChat(chatId: chatId);
    if (chat == null) return;
    navigatorKey.currentState?.push(
      chatRoute(chat),
    );
  }
}

/// A stable, non-negative notification id for one group of one account.
int notificationId(int accountId, int groupId) =>
    Object.hash(accountId, groupId) & 0x7fffffff;

/// What a notification's payload carries, so a tap can be acted on from the
/// payload alone: which account, chat, group and message it came from.
typedef NotificationPayload = ({
  int accountId,
  int chatId,
  int groupId,
  int maxNotificationId,
  int messageId,
});

/// Encodes [group] into the colon separated payload of its notification.
String encodePayload(NotificationGroup group) => [
      group.accountId,
      group.chatId,
      group.groupId,
      group.notifications.last.id,
      messageIdOf(group.notifications.last.type),
    ].join(':');

/// The message a notification is about, or zero when its type carries none.
int messageIdOf(Map<String, dynamic> type) {
  final message = (type['message'] as Map?)?.cast<String, dynamic>();
  return (message?['id'] as num?)?.toInt() ??
      (type['messageId'] as num?)?.toInt() ??
      0;
}

/// Decodes a notification payload, or null when it is missing or malformed.
NotificationPayload? decodePayload(String? raw) {
  final parts = raw?.split(':');
  if (parts == null || parts.length != 5) return null;
  final values = [for (final part in parts) int.tryParse(part)];
  if (values.any((value) => value == null)) return null;
  return (
    accountId: values[0]!,
    chatId: values[1]!,
    groupId: values[2]!,
    maxNotificationId: values[3]!,
    messageId: values[4]!,
  );
}
