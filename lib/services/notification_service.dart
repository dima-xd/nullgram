import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/main.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

final _log = Logger();

/// Shows a local notification for each incoming Telegram message.
///
/// Listens to [TDLibClient.messsagesUpdates] for `updateNewMessage` and posts a
/// notification unless the message is outgoing, its chat is muted, or its chat
/// is the one currently open on screen. Tapping a notification opens the chat.
class NotificationService {
  NotificationService._();

  /// The shared instance.
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'messages';
  static const String _channelName = 'Messages';

  StreamSubscription<Map<String, dynamic>>? _subscription;

  /// The chat currently open on screen, whose messages should not notify.
  /// Set by [ChatPage] while it is mounted.
  int? activeChatId;

  AndroidFlutterLocalNotificationsPlugin? _android;

  /// Whether each notification scope is muted by default, cached after the
  /// first lookup. A scope default rarely changes and would otherwise cost a
  /// bridge round trip per incoming message.
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
    _log.i('NotificationService initialized');
  }

  /// Requests the runtime notification permission. Call once a foreground
  /// activity exists (Android 13+ shows no dialog when called too early).
  Future<void> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    final enabled = await _android?.areNotificationsEnabled();
    _log.i('Notifications permission granted=$granted enabled=$enabled');
  }

  /// Starts listening for incoming messages. Call once the user is authorized.
  void start() {
    if (_subscription != null) return;
    _subscription = TDLibClient.messsagesUpdates.listen(_onMessagesUpdate);
    _log.i('NotificationService started listening');
  }

  Future<void> _onMessagesUpdate(Map<String, dynamic> update) async {
    try {
      if (update['@type'] != updateNewMessageConst) return;

      final message = update['message'] as Map<String, dynamic>?;
      if (message == null || message['isOutgoing'] == true) return;

      final chatId = message['chatId'] as int?;
      if (chatId == null || chatId == activeChatId) return;

      final chat = ChatStore.instance.chat(chatId) ??
          await TDLibClient.getChat(chatId: chatId);
      if (chat == null) {
        _log.w('Notification skipped: chat $chatId is unknown');
        return;
      }

      if (await _isMuted(chat)) return;

      final title = chat['title'] as String? ?? 'New message';
      await _show(
        chatId: chatId,
        title: title,
        body: await _buildBody(message, chat),
      );
    } catch (e, s) {
      _log.e('Failed to show notification', error: e, stackTrace: s);
    }
  }

  /// Whether the chat should stay silent.
  ///
  /// A chat can be muted on its own, or inherit the mute state of its scope
  /// (private chats / groups / channels) — TDLib signals the latter with
  /// `useDefaultMuteFor`, in which case its own `muteFor` is meaningless.
  Future<bool> _isMuted(Map<String, dynamic> chat) async {
    final settings = chat['notificationSettings'];
    if (settings?['useDefaultMuteFor'] != true) {
      return (settings?['muteFor'] as int? ?? 0) > 0;
    }

    final scope = _scopeOf(chat);
    final cached = _scopeMuted[scope];
    if (cached != null) return cached;

    final defaults = await TDLibClient.getScopeNotificationSettings(
      scope: scope,
    );
    final muted = (defaults?['muteFor'] as int? ?? 0) > 0;
    _scopeMuted[scope] = muted;
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
  ) async {
    final preview = messagePreviewText(message);

    final chatType = chat['type']?['@type'];
    final isGroup = chatType == 'ChatTypeBasicGroup' ||
        (chatType == 'ChatTypeSupergroup' &&
            chat['type']?['isChannel'] != true);
    if (!isGroup) return preview;

    final sender = await _senderName(message['senderId']);
    return sender == null || sender.isEmpty ? preview : '$sender: $preview';
  }

  /// Resolves the display name of a message sender (a user or a chat).
  Future<String?> _senderName(dynamic senderId) async {
    if (senderId is! Map) return null;
    switch (senderId['@type']) {
      case 'MessageSenderUser':
        final userId = senderId['userId'] as int?;
        if (userId == null) return null;
        final user = await TDLibClient.getUser(userId: userId);
        if (user == null) return null;
        return [user['firstName'], user['lastName']]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' ');
      case 'MessageSenderChat':
        final senderChatId = senderId['chatId'] as int?;
        if (senderChatId == null) return null;
        final senderChat = await TDLibClient.getChat(chatId: senderChatId);
        return senderChat?['title'] as String?;
      default:
        return null;
    }
  }

  Future<void> _show({
    required int chatId,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    // One notification per chat: a stable id derived from the chat id means a
    // newer message replaces the previous one for that chat.
    await _plugin.show(
      id: chatId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: '$chatId',
    );
    _log.i('Notification shown for chat $chatId: $title — $body');
  }

  /// Clears the notification for [chatId], used once its messages are read.
  Future<void> clear(int chatId) =>
      _plugin.cancel(id: chatId.hashCode & 0x7fffffff);

  void _onTap(NotificationResponse response) {
    final chatId = int.tryParse(response.payload ?? '');
    if (chatId != null) _openChat(chatId);
  }

  Future<void> _openChat(int chatId) async {
    final chat = ChatStore.instance.chat(chatId) ??
        await TDLibClient.getChat(chatId: chatId);
    if (chat == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatPage(chat: chat)),
    );
  }
}
