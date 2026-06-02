import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/main.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
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

  AndroidFlutterLocalNotificationsPlugin? _android;

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

      final chat = await TDLibClient.getChat(chatId: chatId);
      if (chat == null) {
        _log.w('Notification skipped: getChat($chatId) returned null');
        return;
      }

      final muteFor = chat['notificationSettings']?['muteFor'] as int? ?? 0;
      if (muteFor > 0) return;

      final title = chat['title'] as String? ?? 'New message';
      final body = await _buildBody(message, chat);

      await _show(chatId: chatId, title: title, body: body);
      _log.i('Notification shown for chat $chatId: $title — $body');
    } catch (e, s) {
      _log.e('Failed to show notification', error: e, stackTrace: s);
    }
  }

  /// Builds the notification body, prefixing the sender name in group chats.
  Future<String> _buildBody(
    Map<String, dynamic> message,
    Map<String, dynamic> chat,
  ) async {
    final preview = _preview(message['content'] as Map<String, dynamic>?);

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
            .where((p) => p != null && p.toString().isNotEmpty)
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

  /// A short human-readable preview for a message content.
  String _preview(Map<String, dynamic>? content) {
    switch (content?['@type']) {
      case 'MessageText':
        return content?['text']?['text'] as String? ?? '';
      case 'MessagePhoto':
        return '📷 Photo';
      case 'MessageVideo':
        return '🎥 Video';
      case 'MessageVoiceNote':
        return '🎤 Voice message';
      case 'MessageAudio':
        return '🎵 Audio';
      case 'MessageDocument':
        return '📎 Document';
      case 'MessageSticker':
        return '🎨 Sticker';
      case 'MessageAnimation':
        return '🎬 GIF';
      case 'MessagePoll':
        return '📊 Poll';
      default:
        return 'Message';
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
  }

  void _onTap(NotificationResponse response) {
    final chatId = int.tryParse(response.payload ?? '');
    if (chatId != null) _openChat(chatId);
  }

  Future<void> _openChat(int chatId) async {
    final chat = await TDLibClient.getChat(chatId: chatId);
    if (chat == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatPage(chat: chat)),
    );
  }
}
