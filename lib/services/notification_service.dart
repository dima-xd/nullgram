import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/main.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/account_manager.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

final _log = Logger();

/// Shows a local notification for each incoming Telegram message, on every
/// signed-in account.
///
/// The account on screen is fed by [TDLibClient.messsagesUpdates]; the others
/// by [TDLibClient.backgroundUpdates], which is the whole point of keeping
/// their clients online. A notification names its account whenever it did not
/// come from the one on screen, and tapping it switches over before opening
/// the chat.
class NotificationService {
  NotificationService._();

  /// The shared instance.
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'messages';
  static const String _channelName = 'Messages';

  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _backgroundSubscription;

  /// The chat currently open on screen, whose messages should not notify.
  /// Set by [ChatPage] while it is mounted.
  int? activeChatId;

  AndroidFlutterLocalNotificationsPlugin? _android;

  /// Whether each notification scope is muted by default, cached after the
  /// first lookup and keyed by account: a scope default rarely changes and
  /// would otherwise cost a bridge round trip per incoming message.
  final Map<String, bool> _scopeMuted = {};

  /// Initializes the plugin, the Android notification channel, and runtime
  /// permission. Safe to call more than once.
  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onTap,
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

    // Background accounts notify for as long as the app runs, independently of
    // which account is signed in on screen, so this subscription is never
    // stopped by a switch.
    _backgroundSubscription ??=
        TDLibClient.backgroundUpdates.listen(_onBackgroundUpdate);

    _log.i('NotificationService initialized');
  }

  /// Requests the runtime notification permission. Call once a foreground
  /// activity exists (Android 13+ shows no dialog when called too early).
  Future<void> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    final enabled = await _android?.areNotificationsEnabled();
    _log.i('Notifications permission granted=$granted enabled=$enabled');
  }

  /// Starts listening for the active account's incoming messages. Call once
  /// the user is authorized.
  void start() {
    if (_subscription != null) return;
    _subscription = TDLibClient.messsagesUpdates.listen(_onMessagesUpdate);
    _log.i('NotificationService started listening');
  }

  /// Stops listening to the active account, before a switch replaces it.
  ///
  /// The account left behind keeps notifying through the background stream, so
  /// nothing is lost by dropping this subscription.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onMessagesUpdate(Map<String, dynamic> update) =>
      _onNewMessage(update, TDLibClient.activeAccountId);

  Future<void> _onBackgroundUpdate(Map<String, dynamic> update) async {
    final accountId = update['@accountId'] as int?;
    if (accountId == null) return;
    await _onNewMessage(update, accountId);
  }

  Future<void> _onNewMessage(
    Map<String, dynamic> update,
    int accountId,
  ) async {
    try {
      if (update['@type'] != updateNewMessageConst) return;

      final message = update['message'] as Map<String, dynamic>?;
      if (message == null || message['isOutgoing'] == true) return;

      final chatId = message['chatId'] as int?;
      if (chatId == null) return;
      // Only the account on screen can have a chat open on screen.
      final isActive = accountId == TDLibClient.activeAccountId;
      if (isActive && chatId == activeChatId) return;

      final chat = await _chat(chatId, accountId);
      if (chat == null) {
        _log.w('Notification skipped: chat $chatId is unknown');
        return;
      }

      if (await _isMuted(chat, accountId)) return;

      await _show(
        accountId: accountId,
        chatId: chatId,
        title: chat['title'] as String? ?? 'New message',
        body: await _buildBody(message, chat, accountId),
        accountName: isActive ? null : _accountName(accountId),
      );
    } catch (e, s) {
      _log.e('Failed to show notification', error: e, stackTrace: s);
    }
  }

  /// Resolves a chat, using the in-memory store only for the active account.
  ///
  /// [ChatStore] describes the account on screen; asking it about another
  /// account's chat id would answer with an unrelated chat.
  Future<Map<String, dynamic>?> _chat(int chatId, int accountId) async {
    if (accountId == TDLibClient.activeAccountId) {
      final cached = ChatStore.instance.chat(chatId);
      if (cached != null) return cached;
    }
    return TDLibClient.getChat(chatId: chatId, accountId: accountId);
  }

  /// The display name of an account, for a notification that did not come from
  /// the one on screen.
  String? _accountName(int accountId) {
    final name = AccountManager.instance.accountOf(accountId)?.name;
    return name == null || name.isEmpty ? null : name;
  }

  /// Whether the chat should stay silent.
  ///
  /// A chat can be muted on its own, or inherit the mute state of its scope
  /// (private chats / groups / channels) — TDLib signals the latter with
  /// `useDefaultMuteFor`, in which case its own `muteFor` is meaningless.
  Future<bool> _isMuted(Map<String, dynamic> chat, int accountId) async {
    final settings = chat['notificationSettings'];
    if (settings?['useDefaultMuteFor'] != true) {
      return (settings?['muteFor'] as int? ?? 0) > 0;
    }

    final scope = _scopeOf(chat);
    final key = '$accountId:$scope';
    final cached = _scopeMuted[key];
    if (cached != null) return cached;

    final defaults = await TDLibClient.getScopeNotificationSettings(
      scope: scope,
      accountId: accountId,
    );
    final muted = (defaults?['muteFor'] as int? ?? 0) > 0;
    _scopeMuted[key] = muted;
    return muted;
  }

  /// The TDLib notification scope a chat belongs to.
  String _scopeOf(Map<String, dynamic> chat) {
    final type = chat['type']?['@type'];
    if (type == 'ChatTypeSupergroup' && chat['type']?['isChannel'] == true) {
      return 'notificationSettingsScopeChannelChats';
    }
    if (type == 'ChatTypeBasicGroup' || type == 'ChatTypeSupergroup') {
      return 'notificationSettingsScopeGroupChats';
    }
    return 'notificationSettingsScopePrivateChats';
  }

  /// Builds the notification body, prefixing the sender name in group chats.
  Future<String> _buildBody(
    Map<String, dynamic> message,
    Map<String, dynamic> chat,
    int accountId,
  ) async {
    final preview = messagePreviewText(message);

    final chatType = chat['type']?['@type'];
    final isGroup = chatType == 'ChatTypeBasicGroup' ||
        (chatType == 'ChatTypeSupergroup' &&
            chat['type']?['isChannel'] != true);
    if (!isGroup) return preview;

    final sender = await _senderName(message['senderId'], accountId);
    return sender == null || sender.isEmpty ? preview : '$sender: $preview';
  }

  /// Resolves the display name of a message sender (a user or a chat).
  Future<String?> _senderName(dynamic senderId, int accountId) async {
    if (senderId is! Map) return null;
    switch (senderId['@type']) {
      case 'MessageSenderUser':
        final userId = senderId['userId'] as int?;
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
      case 'MessageSenderChat':
        final senderChatId = senderId['chatId'] as int?;
        if (senderChatId == null) return null;
        final senderChat = await TDLibClient.getChat(
          chatId: senderChatId,
          accountId: accountId,
        );
        return senderChat?['title'] as String?;
      default:
        return null;
    }
  }

  Future<void> _show({
    required int accountId,
    required int chatId,
    required String title,
    required String body,
    String? accountName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      // Names the account only when it is not the one on screen, and groups
      // each account's notifications together in the shade.
      subText: accountName,
      groupKey: 'account_$accountId',
    );

    // One notification per chat per account: a stable id means a newer message
    // replaces the previous one for that chat, and two accounts that share a
    // chat id do not overwrite each other.
    await _plugin.show(
      id: _notificationId(accountId, chatId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: '$accountId:$chatId',
    );
    _log.i('Notification shown for chat $chatId of account $accountId');
  }

  /// A stable, non-negative notification id for one chat of one account.
  int _notificationId(int accountId, int chatId) =>
      Object.hash(accountId, chatId) & 0x7fffffff;

  /// Clears the notification for [chatId], used once its messages are read.
  Future<void> clear(int chatId, {int? accountId}) => _plugin.cancel(
        id: _notificationId(accountId ?? TDLibClient.activeAccountId, chatId),
      );

  void _onTap(NotificationResponse response) {
    final payload = response.payload?.split(':');
    if (payload == null || payload.length != 2) return;
    final accountId = int.tryParse(payload.first);
    final chatId = int.tryParse(payload.last);
    if (accountId == null || chatId == null) return;
    _openChat(accountId, chatId);
  }

  Future<void> _openChat(int accountId, int chatId) async {
    if (accountId != TDLibClient.activeAccountId) {
      await AccountManager.instance.switchTo(accountId);
    }
    final chat = ChatStore.instance.chat(chatId) ??
        await TDLibClient.getChat(chatId: chatId);
    if (chat == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatPage(chat: chat)),
    );
  }
}
