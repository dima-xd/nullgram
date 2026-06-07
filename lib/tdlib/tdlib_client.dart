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

  // Call signaling must never replay stale state to a new listener, so this is
  // a PublishSubject (broadcast, no buffer) unlike chat/file streams.
  static final _callController = PublishSubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get callUpdates => _callController.stream;

  static Future<void> sendMessage({
    required int chatId,
    required String text,
    int? replyToMessageId,
    List<Map<String, dynamic>>? entities,
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
          if (entities != null) "entities": entities,
        },
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Parses [text] as Telegram MarkdownV2 into a `formattedText`.
  ///
  /// Returns the resulting `{text, entities}` map, or `null` if the markdown is
  /// malformed (TDLib reports an error). Callers should fall back to sending the
  /// raw text so a message is never dropped.
  static Future<Map<String, dynamic>?> parseTextEntities({
    required String text,
  }) async {
    final jsonMap = {
      "@type": "parseTextEntities",
      "text": text,
      "parseMode": {"@type": "textParseModeMarkdown", "version": 2},
    };
    final dynamic result;
    try {
      result = await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
    } catch (_) {
      return null;
    }
    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    if (data["@type"] == "error") return null;
    // The bridge returns `@type` values in PascalCase, but outgoing requests
    // must use TDLib's lowercase-first names, so normalize before the entities
    // are sent back inside a `formattedText`.
    return _toRequestJson(data) as Map<String, dynamic>;
  }

  /// Recursively lowercases the first letter of every `@type` so a value
  /// decoded from a bridge response can be sent back as a valid TDLib request.
  static dynamic _toRequestJson(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key: entry.key == '@type' && entry.value is String
              ? (entry.value as String).isEmpty
                  ? entry.value
                  : (entry.value as String)[0].toLowerCase() +
                      (entry.value as String).substring(1)
              : _toRequestJson(entry.value),
      };
    }
    if (value is List) return value.map(_toRequestJson).toList();
    return value;
  }

  /// Edits the text of a previously sent message.
  ///
  /// Only messages where `canBeEdited` is true can be edited; the resulting
  /// `UpdateMessageContent` / `UpdateMessageEdited` reflect the change live.
  static Future<void> editMessageText({
    required int chatId,
    required int messageId,
    required String text,
    List<Map<String, dynamic>>? entities,
  }) async {
    final jsonMap = {
      "@type": "editMessageText",
      "chatId": chatId,
      "messageId": messageId,
      "inputMessageContent": {
        "@type": "inputMessageText",
        "text": {
          "@type": "formattedText",
          "text": text,
          if (entities != null) "entities": entities,
        },
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Searches chats by [query] across the user's chat list and the server.
  ///
  /// Returns the matching chat ids; resolve each to a full chat via [getChat].
  static Future<List<int>> searchChats({
    required String query,
    int limit = 50,
  }) async {
    final jsonMap = {
      "@type": "searchChats",
      "query": query,
      "limit": limit,
    };

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return const [];
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return (data["chatIds"] as List?)?.map((e) => e as int).toList() ?? const [];
  }

  /// Searches messages containing [query] within a single chat.
  ///
  /// Pass [fromMessageId] to page through results (0 starts from the newest).
  /// Pass [filter] (e.g. `{"@type": "searchMessagesFilterPinned"}`) to restrict
  /// results to a message category such as pinned messages.
  static Future<Messages?> searchChatMessages({
    required int chatId,
    String query = "",
    int fromMessageId = 0,
    int limit = 50,
    Map<String, dynamic>? filter,
  }) async {
    final jsonMap = {
      "@type": "searchChatMessages",
      "chatId": chatId,
      "query": query,
      "fromMessageId": fromMessageId,
      "offset": 0,
      "limit": limit,
      if (filter != null) "filter": filter,
    };

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return null;
    try {
      final data = result["data"] is String
          ? jsonDecode(result["data"]) as Map<String, dynamic>
          : result["data"] as Map<String, dynamic>;
      return Messages.fromJson(data);
    } catch (e, stackTrace) {
      logger.e("Failed to parse search results",
          error: e, stackTrace: stackTrace);
      return null;
    }
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

  /// Pins [messageId] in [chatId] for all members.
  static Future<void> pinChatMessage({
    required int chatId,
    required int messageId,
    bool disableNotification = false,
  }) async {
    final jsonMap = {
      "@type": "pinChatMessage",
      "chatId": chatId,
      "messageId": messageId,
      "disableNotification": disableNotification,
      "onlyForSelf": false,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Unpins a previously pinned message.
  static Future<void> unpinChatMessage({
    required int chatId,
    required int messageId,
  }) async {
    final jsonMap = {
      "@type": "unpinChatMessage",
      "chatId": chatId,
      "messageId": messageId,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Submits the chosen [optionIds] for a poll message. Pass an empty list to
  /// retract a vote in a non-anonymous, still-open poll.
  static Future<void> setPollAnswer({
    required int chatId,
    required int messageId,
    required List<int> optionIds,
  }) async {
    final jsonMap = {
      "@type": "setPollAnswer",
      "chatId": chatId,
      "messageId": messageId,
      "optionIds": optionIds,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Fetches the user object for [userId].
  ///
  /// The TDLib `chat` object has no embedded user — only a `type`. For a
  /// private/secret chat, read the user id from `chat['type']['userId']` and
  /// resolve the user here.
  static Future<Map<String, dynamic>?> getUser({required int userId}) async {
    final jsonMap = {"@type": "getUser", "userId": userId};

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Fetches extended user info (bio, etc.) for [userId].
  static Future<Map<String, dynamic>?> getUserFullInfo({
    required int userId,
  }) async {
    final jsonMap = {"@type": "getUserFullInfo", "userId": userId};

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Fetches the current user (the logged-in account).
  static Future<Map<String, dynamic>?> getMe() async {
    final result = await _channel.invokeMethod('send', {
      'json': '{"@type":"getMe"}',
    });

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Creates (or returns) the private chat with [userId].
  ///
  /// Used for "Saved Messages" by passing the current user's own id.
  static Future<Map<String, dynamic>?> createPrivateChat({
    required int userId,
    bool force = false,
  }) async {
    final jsonMap = {
      "@type": "createPrivateChat",
      "userId": userId,
      "force": force,
    };

    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap),
    });

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Updates the current user's first and last name.
  static Future<void> setName({
    required String firstName,
    String lastName = '',
  }) async {
    final jsonMap = {
      "@type": "setName",
      "firstName": firstName,
      "lastName": lastName,
    };

    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Updates the current user's bio (about) text.
  static Future<void> setBio({required String bio}) async {
    final jsonMap = {"@type": "setBio", "bio": bio};

    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Updates the current user's editable username.
  static Future<void> setUsername({required String username}) async {
    final jsonMap = {"@type": "setUsername", "username": username};

    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Logs the current user out, returning the app to the auth flow.
  static Future<void> logOut() async {
    await _channel.invokeMethod('send', {
      'json': '{"@type":"logOut"}'
    });
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

  /// Sends a photo from a local [path] with an optional [caption].
  static Future<void> sendPhoto({
    required int chatId,
    required String path,
    String caption = '',
    int? replyToMessageId,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessagePhoto',
        fileField: 'photo',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
      );

  /// Sends a video from a local [path] with an optional [caption].
  static Future<void> sendVideo({
    required int chatId,
    required String path,
    String caption = '',
    int? replyToMessageId,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessageVideo',
        fileField: 'video',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
      );

  /// Sends an arbitrary file from a local [path] as a document.
  static Future<void> sendDocument({
    required int chatId,
    required String path,
    String caption = '',
    int? replyToMessageId,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessageDocument',
        fileField: 'document',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
      );

  /// Shared body for the local-file media senders. [fileField] is the TDLib
  /// input-content field that carries the file (`photo`/`video`/`document`).
  static Future<void> _sendLocalMedia({
    required int chatId,
    required String contentType,
    required String fileField,
    required String path,
    required String caption,
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
        "@type": contentType,
        fileField: {
          "@type": "inputFileLocal",
          "path": path,
        },
        if (caption.isNotEmpty)
          "caption": {
            "@type": "formattedText",
            "text": caption,
          },
      },
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Marks [messageIds] in [chatId] as viewed. TDLib advances the chat's read
  /// inbox, clearing the unread count for those and all older messages.
  ///
  /// Pass [forceRead] true to mark them read even while the chat is closed.
  static Future<void> viewMessages({
    required int chatId,
    required List<int> messageIds,
    bool forceRead = false,
  }) async {
    if (messageIds.isEmpty) return;
    final jsonMap = {
      "@type": "viewMessages",
      "chatId": chatId,
      "messageIds": messageIds,
      "forceRead": forceRead,
    };

    await _channel.invokeMethod('send', {
      'json': jsonEncode(jsonMap)
    });
  }

  /// Informs TDLib that the user opened [chatId]. Required for read receipts
  /// and live updates in supergroups/channels. Pair with [closeChat].
  static Future<void> openChat({required int chatId}) async {
    await _channel.invokeMethod('send', {
      'json': jsonEncode({"@type": "openChat", "chatId": chatId}),
    });
  }

  /// Informs TDLib that the user closed [chatId].
  static Future<void> closeChat({required int chatId}) async {
    await _channel.invokeMethod('send', {
      'json': jsonEncode({"@type": "closeChat", "chatId": chatId}),
    });
  }

  /// Sends a transient user-activity notification (e.g. "typing") for [chatId].
  ///
  /// [action] is a TDLib `ChatAction` object; defaults to typing. Pass a
  /// `{"@type": "chatActionCancel"}` action to clear the current activity.
  static Future<void> sendChatAction({
    required int chatId,
    Map<String, dynamic> action = const {"@type": "chatActionTyping"},
  }) async {
    final jsonMap = {
      "@type": "sendChatAction",
      "chatId": chatId,
      "action": action,
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

  /// Builds the call protocol descriptor TDLib hands to tgcalls.
  ///
  /// Layers 65..92 and the tgcalls library versions come straight from the
  /// TDLib `CallProtocol` documentation; [versions] is `TgCalls.supportedVersions`.
  static Map<String, dynamic> _callProtocol(List<String> versions) => {
        "@type": "callProtocol",
        "udpP2p": true,
        "udpReflector": true,
        "minLayer": 65,
        "maxLayer": 92,
        "libraryVersions": versions,
      };

  /// Places an outgoing 1:1 call to [userId].
  static Future<void> createCall({
    required int userId,
    required bool isVideo,
    required List<String> protocolVersions,
  }) async {
    final jsonMap = {
      "@type": "createCall",
      "userId": userId,
      "protocol": _callProtocol(protocolVersions),
      "isVideo": isVideo,
    };
    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Accepts an incoming call identified by [callId].
  static Future<void> acceptCall({
    required int callId,
    required List<String> protocolVersions,
  }) async {
    final jsonMap = {
      "@type": "acceptCall",
      "callId": callId,
      "protocol": _callProtocol(protocolVersions),
    };
    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Ends or declines the call [callId].
  static Future<void> discardCall({
    required int callId,
    required bool isVideo,
    int duration = 0,
    int connectionId = 0,
    bool isDisconnected = false,
  }) async {
    final jsonMap = {
      "@type": "discardCall",
      "callId": callId,
      "isDisconnected": isDisconnected,
      "duration": duration,
      "isVideo": isVideo,
      "connectionId": connectionId,
    };
    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Forwards tgcalls-produced signaling [data] to the call [callId].
  ///
  /// `data` is a `byte[]` field, so it crosses the channel as Base64 (NO_WRAP)
  /// — see TdApiConverter.
  static Future<void> sendCallSignalingData({
    required int callId,
    required Uint8List data,
  }) async {
    final jsonMap = {
      "@type": "sendCallSignalingData",
      "callId": callId,
      "data": base64Encode(data),
    };
    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
  }

  /// Submits a post-call quality rating (1..5).
  static Future<void> sendCallRating({
    required int callId,
    required int rating,
    String comment = '',
  }) async {
    final jsonMap = {
      "@type": "sendCallRating",
      "callId": callId,
      "rating": rating,
      "comment": comment,
      "problems": <Map<String, dynamic>>[],
    };
    await _channel.invokeMethod('send', {'json': jsonEncode(jsonMap)});
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
          updateChatReadOutboxConst || updateChatActionConst || updateUserStatusConst:
          _chatUpdatesController.add(update);
        case updateNewMessageConst || updateDeleteMessagesConst ||
          updateMessageInteractionInfoConst || updateMessageContentConst ||
          updateMessageEditedConst:
          _messagesController.add(update);
        case updateFileConst:
          _filesController.add(update);
        case updateCallConst || updateNewCallSignalingDataConst:
          _callController.add(update);
        default:
          logger.i("Skipped update of type: $type");
      }
    });
  }
}