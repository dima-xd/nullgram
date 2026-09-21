import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/main.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/pages/chat/widgets/forward_chat_picker.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/services/link_resolver.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Android intents the app is opened with: a `t.me` link tapped elsewhere, or
/// content shared into it from another app.
class ShareIntents {
  ShareIntents._();

  static final ShareIntents instance = ShareIntents._();

  static const _methodChannel = MethodChannel('nullgram/intents');
  static const _eventChannel = EventChannel('nullgram/intents/events');

  StreamSubscription<dynamic>? _subscription;

  /// Subscribes to later intents, then drains the one the app was started
  /// with, which the platform side held until Dart was listening.
  Future<void> start() async {
    _subscription ??= _eventChannel.receiveBroadcastStream().listen(
          (payload) => _handle(payload),
          onError: (Object error) =>
              logger.w('Intent stream failed', error: error),
        );

    final dynamic initial =
        await _methodChannel.invokeMethod<dynamic>('getInitial');
    if (initial != null) await _handle(initial);
  }

  Future<void> _handle(dynamic payload) async {
    if (payload is! Map) return;
    switch (payload['type']) {
      case 'link':
        await _openLink(payload['url'] as String?);
      case 'share':
        await _share(
          text: payload['text'] as String?,
          paths: [
            for (final path in payload['paths'] as List? ?? const [])
              if (path is String && path.isNotEmpty) path,
          ],
        );
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await openLink(context, url);
  }

  Future<void> _share({String? text, required List<String> paths}) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if ((text == null || text.isEmpty) && paths.isEmpty) return;

    final chatId = await showForwardChatPicker(context);
    if (chatId == null) return;

    for (final path in paths) {
      await _sendFile(chatId: chatId, path: path);
    }

    final chat = ChatStore.instance.chat(chatId) ??
        await TDLibClient.getChat(chatId: chatId);
    if (chat == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chat: chat,
          initialText: paths.isEmpty ? text : null,
        ),
      ),
    );
  }

  /// Picks the TDLib content type from the file's extension, since an intent
  /// only promises a MIME type the sender chose.
  Future<void> _sendFile({required int chatId, required String path}) {
    final extension = path.split('.').last.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(extension)) {
      return TDLibClient.sendPhoto(chatId: chatId, path: path);
    }
    if (const {'mp4', 'mov', 'mkv', 'webm', '3gp'}.contains(extension)) {
      return TDLibClient.sendVideo(chatId: chatId, path: path);
    }
    if (const {'mp3', 'm4a', 'aac', 'flac', 'ogg'}.contains(extension)) {
      return TDLibClient.sendAudio(chatId: chatId, path: path);
    }
    return TDLibClient.sendDocument(chatId: chatId, path: path);
  }
}
