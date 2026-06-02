import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/tdlib/models/message.dart';
import 'package:rxdart/rxdart.dart';

import 'constants.dart';

var logger = Logger();

class TDLibClient {
  static const _channel = MethodChannel('tdlib_channel');
  static final _updatesChannel = EventChannel('tdlib_updates');

  static final _authUpdatesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get authStateUpdates => _authUpdatesController.stream;

  static final _chatUpdatesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get chatUpdates => _chatUpdatesController.stream;

  static final _messagesController = PublishSubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get messsagesUpdates => _messagesController.stream;

  static final _filesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get filesUpdates => _filesController.stream;

  static Future<void> sendMessage({
    required int chatId,
    required String text,
    int? replyToMessageId,
  }) async {
    final jsonMap = {
      "@type": "sendMessage",
      "chatId": chatId,
      if (replyToMessageId != null)
        "replyTo": {
          "@type": "inputMessageReplyToMessage",
          "messageId": replyToMessageId,
        },
      "inputMessageContent": {
        "@type": "inputMessageText",
        "text": {
          "@type": "formattedText",
          "text": text,
        },
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Adds an emoji reaction to a message.
  ///
  /// [emoji] is the reaction's text representation (e.g. '👍'). Standard chats
  /// allow a single chosen reaction; remove the previous one first via
  /// [removeMessageReaction] to mimic Telegram's replace-on-tap behavior.
  static Future<void> addMessageReaction({
    required int chatId,
    required int messageId,
    required String emoji,
    bool isBig = false,
  }) async {
    final jsonMap = {
      "@type": "addMessageReaction",
      "chatId": chatId,
      "messageId": messageId,
      "reactionType": {
        "@type": "reactionTypeEmoji",
        "emoji": emoji,
      },
      "isBig": isBig,
      "updateRecentReactions": true,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Removes a previously added emoji reaction from a message.
  static Future<void> removeMessageReaction({
    required int chatId,
    required int messageId,
    required String emoji,
  }) async {
    final jsonMap = {
      "@type": "removeMessageReaction",
      "chatId": chatId,
      "messageId": messageId,
      "reactionType": {
        "@type": "reactionTypeEmoji",
        "emoji": emoji,
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Returns the emoji reactions that can be added to the given message.
  ///
  /// Only standard emoji reactions are returned (custom and premium-only ones
  /// are filtered out), drawn from the chat's top and recently used reactions.
  static Future<List<String>> getMessageAvailableReactions({
    required int chatId,
    required int messageId,
    int rowSize = 8,
  }) async {
    final jsonMap = {
      "@type": "getMessageAvailableReactions",
      "chatId": chatId,
      "messageId": messageId,
      "rowSize": rowSize,
    };

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return const [];

    try {
      final data = result["data"] is String
          ? jsonDecode(result["data"]) as Map<String, dynamic>
          : result["data"] as Map<String, dynamic>;

      final emojis = <String>[];
      for (final key in const ['topReactions', 'recentReactions']) {
        for (final reaction in (data[key] as List? ?? const [])) {
          if (reaction['needsPremium'] == true) continue;
          final type = reaction['type'];
          if (type?['@type'] == 'ReactionTypeEmoji') {
            final emoji = type['emoji'] as String?;
            if (emoji != null && !emojis.contains(emoji)) emojis.add(emoji);
          }
        }
      }
      return emojis;
    } catch (e, stackTrace) {
      logger.e("Failed to parse available reactions",
          error: e, stackTrace: stackTrace);
      return const [];
    }
  }

  /// Deletes messages in a chat.
  ///
  /// When [revoke] is true the messages are deleted for all chat members.
  static Future<void> deleteMessages({
    required int chatId,
    required List<int> messageIds,
    bool revoke = true,
  }) async {
    final jsonMap = {
      "@type": "deleteMessages",
      "chatId": chatId,
      "messageIds": messageIds,
      "revoke": revoke,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Forwards messages from one chat into another.
  static Future<void> forwardMessages({
    required int chatId,
    required int fromChatId,
    required List<int> messageIds,
  }) async {
    final jsonMap = {
      "@type": "forwardMessages",
      "chatId": chatId,
      "fromChatId": fromChatId,
      "messageIds": messageIds,
      "sendCopy": false,
      "removeCaption": false,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  static Future<void> sendAudio({required int chatId, required String path}) async {
    final jsonMap = {
      "@type": "sendMessage",
      "chatId": chatId,
      "inputMessageContent": {
        "@type": "inputMessageAudio",
        "audio": {
          "@type": "inputFileLocal",
          "path": path,
        },
        "duration": 0,
        "title": "",
        "performer": "",
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  static Future<void> downloadFile({required int fileId}) async {
    final jsonMap = {
      "@type": "downloadFile",
      "fileId": fileId,
      "priority": 1,
      "synchronous": true,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  static Future<Messages?> getChatHistory({required int chatId, int fromMessageId = 0, required int offset, required int limit, required bool onlyLocal}) async {
    final jsonMap = {
      "@type": "getChatHistory",
      "chatId": chatId,
      "fromMessageId": fromMessageId,
      "offset": offset,
      "limit": limit,
      "onlyLocal": onlyLocal,
    };

    var result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });

    if (result["data"] != null) {
      try {
        final data = result["data"] is String
            ? jsonDecode(result["data"]) as Map<String, dynamic>
            : result["data"] as Map<String, dynamic>;

        return Messages.fromJson(data);
      } catch (e, stackTrace) {
        logger.e("Failed to parse messages", error: e, stackTrace: stackTrace);
        return null;
      }
    }
    return null;
  }

  /// Returns the ids of chats already loaded in TDLib's in-memory main list.
  ///
  /// Unlike the one-shot `updateNewChat` pushes, this can be called at any time
  /// to recover the current chat list. This is what lets the chat list survive
  /// a Dart hot restart: the native TDLib session persists and still holds the
  /// chats, even though the Dart-side update buffers were wiped.
  static Future<List<int>> getChats({int limit = 200}) async {
    final jsonMap = {
      "@type": "getChats",
      "chatList": {"@type": "chatListMain"},
      "limit": limit,
    };

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return [];
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return (data["chatIds"] as List?)?.map((e) => e as int).toList() ?? [];
  }

  /// Fetches the full chat object for [chatId] from TDLib.
  static Future<Map<String, dynamic>?> getChat({required int chatId}) async {
    final jsonMap = {"@type": "getChat", "chatId": chatId};

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  static Future<String?> loadChats({int limit = 20}) async {
    final jsonMap = {
      "@type": "loadChats",
      "limit": limit,
    };

    var result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
    return result['type'];
  }

  static Future<String> checkAuthenticationCode({required String code}) async {
    final jsonMap = {
      "@type": "checkAuthenticationCode",
      "code": code,
    };

    var result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["message"] != null) {
      return result["message"];
    }
    return "";
  }

  static Future<void> setAuthenticationPhoneNumber({required String phoneNumber}) async {
    final jsonMap = {
      "@type": "setAuthenticationPhoneNumber",
      "phoneNumber": phoneNumber,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });
  }

  static Future<void> checkAuthenticationPassword({required String password}) async {
    final jsonMap = {
      "@type": "checkAuthenticationPassword",
      "password": password,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });
  }

  static Future<void> requestQrCodeAuthentication() async {
    await _channel.invokeMethod('send', {
      'json': '{"@type":"requestQrCodeAuthentication"}'
    });
  }

  static Future<void> resendAuthenticationCode() async {
    await _channel.invokeMethod('send', {
      'json': '{"@type":"resendAuthenticationCode"}'
    });
  }

  static Future<void> setTdlibParameters({
    required bool useTestDc,
    required String databaseDirectory,
    required String filesDirectory,
    required List<int> databaseEncryptionKey,
    required bool useFileDatabase,
    required bool useChatInfoDatabase,
    required bool useMessageDatabase,
    required bool useSecretChats,
    required int apiId,
    required String apiHash,
    required String systemLanguageCode,
    required String deviceModel,
    required String systemVersion,
    required String applicationVersion,
  }) async {
    final jsonMap = {
      "@type": "setTdlibParameters",
      "useTestDc": useTestDc,
      "databaseDirectory": databaseDirectory,
      "filesDirectory": filesDirectory,
      "databaseEncryptionKey": base64Encode(databaseEncryptionKey),
      "useFileDatabase": useFileDatabase,
      "useChatInfoDatabase": useChatInfoDatabase,
      "useMessageDatabase": useMessageDatabase,
      "useSecretChats": useSecretChats,
      "apiId": apiId,
      "apiHash": apiHash,
      "systemLanguageCode": systemLanguageCode,
      "deviceModel": deviceModel,
      "systemVersion": systemVersion,
      "applicationVersion": applicationVersion
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });
  }

  static Future<String> getAuthorizationState() async {
    final result = await _channel.invokeMethod('send', {
      'json': '{"@type":"getAuthorizationState"}'
    });
    return result["type"];
  }

  static void initTdlibUpdates() {
    _updatesChannel.receiveBroadcastStream().listen((event) {
      final update = jsonDecode(event);
      final type = update['@type'];

      if (type == "UpdateOption" || type == updateUnreadMessageCountConst) {
        return;
      }

      switch (type) {
        case updateAuthorizationStateConst:
          _authUpdatesController.add(update['authorizationState']);
        case updateChatFoldersConst || updateNewChatConst || updateChatPositionConst ||
          updateChatLastMessageConst || updateChatAddedToListConst || updateSupergroupFullInfoConst ||
          updateSupergroupConst || updateChatReadInboxConst || updateUserConst ||
          updateUserStatusConst:
          _chatUpdatesController.add(update);
        case updateNewMessageConst || updateDeleteMessagesConst ||
          updateMessageInteractionInfoConst:
          _messagesController.add(update);
        case updateFileConst:
          _filesController.add(update);
        default:
          logger.i("Skipped update of type: $type");
      }
    });
  }
}