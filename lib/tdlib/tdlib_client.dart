import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/tdlib/models/message.dart';
import 'package:nullgram/tdlib/send_options.dart';
import 'package:nullgram/tdlib/td_bytes.dart';
import 'package:rxdart/rxdart.dart';

import 'constants.dart';

// A production filter, or a release build logs nothing at all and a TDLib
// failure behind a missing notification leaves no trace in logcat.
var logger = Logger(filter: ProductionFilter());

class TDLibClient {
  static const _channel = MethodChannel('tdlib_channel');
  static final _updatesChannel = EventChannel('tdlib_updates');

  static final _authUpdatesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get authStateUpdates => _authUpdatesController.stream;

  static final _chatUpdatesController = PublishSubject<Map<String, dynamic>>();

  /// Chat updates of the account on screen, preceded by the recent ones.
  ///
  /// A listener subscribes late by design — `ChatStore` only starts once the
  /// account is authorized, and a media widget only while it is mounted — so
  /// the last updates are handed over on subscription.
  ///
  /// This replaced a `ReplaySubject`, whose buffer was neither cleared nor
  /// bounded: it held every chat update of the whole session, so subscribing
  /// after an account switch replayed *another* account's chats into the store
  /// (one account's chats appearing in another's list), and every newly
  /// mounted widget re-processed the entire history.
  static Stream<Map<String, dynamic>> get chatUpdates =>
      _replaying(_chatReplay, _chatUpdatesController.stream);

  static final _messagesController = PublishSubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get messsagesUpdates => _messagesController.stream;

  static final _filesController = PublishSubject<Map<String, dynamic>>();

  /// File updates of the account on screen, preceded by the recent ones, so a
  /// download that finished just before a widget mounted is not missed. See
  /// [chatUpdates] for why this is not a `ReplaySubject`.
  static Stream<Map<String, dynamic>> get filesUpdates =>
      _replaying(_fileReplay, _filesController.stream);

  static final List<Map<String, dynamic>> _chatReplay = [];
  static final List<Map<String, dynamic>> _fileReplay = [];

  /// How many recent updates each replay buffer keeps.
  ///
  /// Enough to cover the gap between an update arriving and a listener
  /// subscribing, and small enough that handing the buffer to a newly mounted
  /// widget costs nothing. The full state is always recoverable another way —
  /// `getChats` for the lists, `getFile` for a download.
  static const int _replayLimit = 200;

  static void _buffer(
    List<Map<String, dynamic>> buffer,
    Map<String, dynamic> update,
  ) {
    buffer.add(update);
    if (buffer.length > _replayLimit) buffer.removeAt(0);
  }

  /// Hands a new listener the contents of [buffer], then [live].
  ///
  /// The buffer is drained in microtasks, which all run before the next
  /// platform message, so nothing arrives in between and is lost.
  static Stream<Map<String, dynamic>> _replaying(
    List<Map<String, dynamic>> buffer,
    Stream<Map<String, dynamic>> live,
  ) async* {
    yield* Stream.fromIterable(List.of(buffer));
    yield* live;
  }

  // Call signaling must never replay stale state to a new listener, so this is
  // a PublishSubject (broadcast, no buffer) unlike chat/file streams.
  static final _callController = PublishSubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get callUpdates => _callController.stream;

  // Seeded with "ready" so a late listener (any screen built after the first
  // update arrived) renders a connected app instead of a stuck banner.
  static final _connectionStateController =
      BehaviorSubject<String>.seeded('ConnectionStateReady');

  /// The current TDLib connection state, as a `ConnectionState*` type name.
  ///
  /// Emits the latest value immediately on subscription, so the header banner
  /// is correct as soon as it is built.
  static Stream<String> get connectionStateUpdates =>
      _connectionStateController.stream;

  // ---------------------------------------------------------------------------
  // Accounts
  //
  // Every signed-in account has its own TDLib client in the native bridge, and
  // all of them stay online. Only the active account's updates drive the UI;
  // the rest are published on [backgroundUpdates] so notifications and unread
  // badges keep working for accounts that are not on screen.
  // ---------------------------------------------------------------------------

  /// The account id an install starts with, before any account is added.
  static const int defaultAccountId = 1;

  /// Default target of a request naming no account, set by [setActiveAccount];
  /// only a push isolate assigns it directly, to leave the shared bridge be.
  static int activeAccountId = defaultAccountId;

  static final _backgroundController = PublishSubject<Map<String, dynamic>>();

  /// Updates belonging to an account other than [activeAccountId].
  ///
  /// Each event carries its origin in `@accountId`. No buffering: a late
  /// listener must not be woken by a message that was already handled.
  static Stream<Map<String, dynamic>> get backgroundUpdates =>
      _backgroundController.stream;

  static final _unreadController = PublishSubject<Map<String, dynamic>>();

  /// `UpdateUnreadChatCount` from every account, active or not, tagged with
  /// `@accountId`. Feeds the per-account badges in the account switcher.
  static Stream<Map<String, dynamic>> get unreadCountUpdates =>
      _unreadController.stream;

  static final _notificationsController =
      PublishSubject<Map<String, dynamic>>();

  /// TDLib's notification updates from every account, active or not, tagged
  /// with `@accountId`. Not filtered by the active account like the stores.
  static Stream<Map<String, dynamic>> get notificationUpdates =>
      _notificationsController.stream;

  /// Starts a TDLib client for [accountId] if one is not running yet.
  ///
  /// The new client immediately reports `AuthorizationStateWaitTdlibParameters`,
  /// so [setTdlibParameters] must follow with that account's own database
  /// directory — two accounts sharing a directory would corrupt both.
  static Future<void> createAccount(int accountId) =>
      _channel.invokeMethod('createAccount', {'accountId': accountId});

  /// Points the bridge and [activeAccountId] at [accountId].
  static Future<void> setActiveAccount(int accountId) async {
    activeAccountId = accountId;
    // The buffers describe the account leaving the screen. Handing them to the
    // next account's store is precisely how two accounts' chats get mixed.
    _chatReplay.clear();
    _fileReplay.clear();
    await _channel.invokeMethod('setActiveAccount', {'accountId': accountId});
  }

  /// Shuts the client of [accountId] down and forgets it.
  static Future<void> closeAccount(int accountId) =>
      _channel.invokeMethod('closeAccount', {'accountId': accountId});

  /// Re-publishes the active account's authorization state on
  /// [authStateUpdates].
  ///
  /// Switching accounts produces no new `updateAuthorizationState` — the other
  /// client reached its state long ago — so the state has to be replayed for
  /// the app's auth navigation to react to the switch at all.
  static Future<void> refreshAuthorizationState() async {
    final state = await _request({"@type": "getAuthorizationState"});
    if (state == null) return;
    _authUpdatesController.add({...state, '@accountId': activeAccountId});
  }

  /// Tells TDLib that this application cannot verify itself.
  ///
  /// Telegram asks for a Play Integrity or reCAPTCHA token only when the app
  /// presents official application credentials, and it validates that token
  /// against a key bound to the official app, which no other package can
  /// satisfy. Answering with an empty token fails the pending request at once
  /// with `VERIFICATION_FAILED`, instead of leaving the login screen waiting
  /// forever with nothing to show. Signing in needs an `api_id` of your own
  /// from my.telegram.org, for which no verification is required.
  static Future<void> _abortApplicationVerification(
    Map<String, dynamic> update,
  ) async {
    logger.w(
      'TDLib asked for app verification (${update['@type']}); aborting it. '
      'Signing in needs an api_id of your own from my.telegram.org.',
    );
    await _execute(
      {
        "@type": "setApplicationVerificationToken",
        "verificationId": update['verificationId'],
        "token": "",
      },
      accountId: update['@accountId'] as int?,
    );
  }

  /// Sends [request] and returns TDLib's error message, or null on success.
  ///
  /// Used by the login flow, where a failure has to be shown rather than only
  /// logged: a rejected number or a refused app verification is otherwise
  /// indistinguishable from the button doing nothing at all.
  static Future<String?> _errorOf(
    Map<String, dynamic> request, {
    int? accountId,
  }) async {
    final target = accountId ?? activeAccountId;
    final dynamic result;
    try {
      result = await _channel.invokeMethod(
        'send',
        _sendArgs(jsonEncode(request), accountId),
      );
    } catch (e) {
      logger.e('TDLib ${request['@type']} failed on account $target',
          error: e);
      return e is PlatformException ? e.message ?? 'FAILED' : 'FAILED';
    }

    final message = result is Map ? result['message'] : null;
    if (message is! String) return null;
    logger.w('TDLib ${request['@type']} error on account $target: $message');
    return message;
  }

  /// The arguments of a `send` aimed at [accountId], or at the active account
  /// when it is null.
  static Map<String, Object?> _sendArgs(String json, int? accountId) => {
        'json': json,
        'accountId': accountId ?? activeAccountId,
      };

  /// Sends a text message.
  ///
  /// Returns null on success, or TDLib's error message when the send was
  /// refused — a non-member commenting on a channel post gets an error whose
  /// message contains "FORBIDDEN".
  static Future<String?> sendMessage({
    required int chatId,
    required String text,
    int? replyToMessageId,
    List<Map<String, dynamic>>? entities,
    SendOptions options = SendOptions.normal,
    int messageThreadId = 0,
    int? accountId,
  }) async {
    final jsonMap = {
      "@type": "sendMessage",
      "chatId": chatId,
      if (messageThreadId != 0) "messageThreadId": messageThreadId,
      if (replyToMessageId != null)
        "replyTo": {
          "@type": "inputMessageReplyToMessage",
          "messageId": replyToMessageId,
        },
      if (options.toJson() case final sendOptions?) "options": sendOptions,
      "inputMessageContent": {
        "@type": "inputMessageText",
        "text": {
          "@type": "formattedText",
          "text": text,
          if (entities != null) "entities": entities,
        },
      },
    };

    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode(jsonMap), accountId),
    );

    if (result is Map && result["data"] != null) {
      final data = result["data"] is String
          ? jsonDecode(result["data"]) as Map<String, dynamic>
          : result["data"] as Map<String, dynamic>;
      if (data["@type"] == "Error") return data["message"] as String?;
    }
    return null;
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

  /// A standard emoji reaction, e.g. '👍'.
  static Map<String, dynamic> emojiReaction(String emoji) => {
        "@type": "reactionTypeEmoji",
        "emoji": emoji,
      };

  /// A custom (premium) emoji reaction, identified by its custom emoji id.
  static Map<String, dynamic> customEmojiReaction(int customEmojiId) => {
        "@type": "reactionTypeCustomEmoji",
        "customEmojiId": customEmojiId,
      };

  /// A stable key for a reaction type, so a chosen reaction can be compared
  /// without caring which of the variants it is.
  ///
  /// The bridge PascalCases response types while requests use lowercase-first,
  /// so the discriminator is normalised out of the key entirely.
  static String reactionKey(Map<String, dynamic>? reactionType) {
    final emoji = reactionType?['emoji'];
    if (emoji != null) return 'emoji:$emoji';
    final customEmojiId = reactionType?['customEmojiId'];
    if (customEmojiId != null) return 'custom:$customEmojiId';
    return 'unknown';
  }

  /// Adds a reaction to a message.
  ///
  /// [reactionType] comes from [emojiReaction] or [customEmojiReaction].
  /// Standard chats allow a single chosen reaction; remove the previous one
  /// first via [removeMessageReaction] to mimic Telegram's replace-on-tap
  /// behavior.
  static Future<void> addMessageReaction({
    required int chatId,
    required int messageId,
    required Map<String, dynamic> reactionType,
    bool isBig = false,
  }) =>
      _execute({
        "@type": "addMessageReaction",
        "chatId": chatId,
        "messageId": messageId,
        "reactionType": reactionType,
        "isBig": isBig,
        "updateRecentReactions": true,
      });

  /// Removes a previously added reaction from a message.
  static Future<void> removeMessageReaction({
    required int chatId,
    required int messageId,
    required Map<String, dynamic> reactionType,
  }) =>
      _execute({
        "@type": "removeMessageReaction",
        "chatId": chatId,
        "messageId": messageId,
        "reactionType": reactionType,
      });

  /// Resolves custom (premium) emoji to the stickers that render them.
  ///
  /// TDLib returns only the ids it found, in arbitrary order, so callers must
  /// match results by `fullType.customEmojiId` rather than by position. At
  /// most 200 ids per call.
  static Future<List<Map<String, dynamic>>> getCustomEmojiStickers({
    required List<int> customEmojiIds,
  }) async {
    if (customEmojiIds.isEmpty) return const [];
    final data = await _request({
      "@type": "getCustomEmojiStickers",
      "customEmojiIds": customEmojiIds,
    });
    return _mapList(data, 'stickers');
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
  static Future<Map<String, dynamic>?> getUser({
    required int userId,
    int? accountId,
  }) async {
    final jsonMap = {"@type": "getUser", "userId": userId};

    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode(jsonMap), accountId),
    );

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
  static Future<Map<String, dynamic>?> getMe({int? accountId}) async {
    final result = await _channel.invokeMethod(
      'send',
      _sendArgs('{"@type":"getMe"}', accountId),
    );

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

  /// Logs an account out, returning the app to the auth flow.
  ///
  /// Defaults to the active account; [accountId] logs another one out without
  /// bringing it on screen, which is how a removed account is dropped from the
  /// switcher.
  static Future<void> logOut({int? accountId}) async {
    await _channel.invokeMethod(
      'send',
      _sendArgs('{"@type":"logOut"}', accountId),
    );
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
    SendOptions options = SendOptions.normal,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessagePhoto',
        fileField: 'photo',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
        options: options,
      );

  /// Sends a video from a local [path] with an optional [caption].
  static Future<void> sendVideo({
    required int chatId,
    required String path,
    String caption = '',
    int? replyToMessageId,
    SendOptions options = SendOptions.normal,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessageVideo',
        fileField: 'video',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
        options: options,
      );

  /// Sends an arbitrary file from a local [path] as a document.
  static Future<void> sendDocument({
    required int chatId,
    required String path,
    String caption = '',
    int? replyToMessageId,
    SendOptions options = SendOptions.normal,
  }) =>
      _sendLocalMedia(
        chatId: chatId,
        contentType: 'inputMessageDocument',
        fileField: 'document',
        path: path,
        caption: caption,
        replyToMessageId: replyToMessageId,
        options: options,
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
    SendOptions options = SendOptions.normal,
  }) async {
    final jsonMap = {
      "@type": "sendMessage",
      "chatId": chatId,
      if (replyToMessageId != null)
        "replyTo": {
          "@type": "inputMessageReplyToMessage",
          "messageId": replyToMessageId,
        },
      if (options.toJson() case final sendOptions?) "options": sendOptions,
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
    Map<String, dynamic>? source,
    int? accountId,
  }) async {
    if (messageIds.isEmpty) return;
    final jsonMap = {
      "@type": "viewMessages",
      "chatId": chatId,
      "messageIds": messageIds,
      if (source != null) "source": source,
      "forceRead": forceRead,
    };

    await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode(jsonMap), accountId),
    );
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

  /// Starts downloading [fileId].
  ///
  /// [accountId] matters more here than it looks: a file id is meaningful only
  /// to the client that issued it, so a download started for one account must
  /// never be sent to another's client — it would fetch an unrelated file.
  static Future<void> downloadFile({
    required int fileId,
    int? accountId,
  }) async {
    final jsonMap = {
      "@type": "downloadFile",
      "fileId": fileId,
      "priority": 1,
      "synchronous": true,
    };

    await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode(jsonMap), accountId),
    );
  }

  /// Returns TDLib's current, authoritative [File] state for [fileId].
  ///
  /// Unlike the one-shot `updateFile` pushes (which a widget only sees while it
  /// is mounted and subscribed), this can be called at any time to recover the
  /// real on-disk state. Used to reconcile media that finished downloading—or
  /// was evicted from TDLib's cache—while the widget was off-screen.
  static Future<Map<String, dynamic>?> getFile({
    required int fileId,
    int? accountId,
  }) async {
    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode({"@type": "getFile", "fileId": fileId}), accountId),
    );

    if (result["data"] == null) return null;
    return result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
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

  /// Resolves the thread a message belongs to.
  ///
  /// For a channel post the returned `chatId` is the channel's linked
  /// discussion supergroup, not the channel — every later thread call must use
  /// that id. Returns null when the message has no thread (TDLib answers with
  /// an error), which is how the caller decides to show a snackbar.
  static Future<Map<String, dynamic>?> getMessageThread({
    required int chatId,
    required int messageId,
  }) async {
    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode({
        "@type": "getMessageThread",
        "chatId": chatId,
        "messageId": messageId,
      }),
    });

    if (result["data"] == null) return null;
    try {
      final data = result["data"] is String
          ? jsonDecode(result["data"]) as Map<String, dynamic>
          : result["data"] as Map<String, dynamic>;
      if (data["@type"] == "Error") return null;
      return data;
    } catch (e, stackTrace) {
      logger.e("Failed to parse message thread",
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// One page of a thread's history, newest first.
  ///
  /// [messageId] is the thread's root message *in [chatId]* — that is
  /// `messageThreadInfo.messageThreadId`, not the channel post's own id.
  /// TDLib may return fewer than [limit] messages, so callers must page.
  static Future<Messages?> getMessageThreadHistory({
    required int chatId,
    required int messageId,
    int fromMessageId = 0,
    required int offset,
    required int limit,
  }) async {
    final result = await _channel.invokeMethod('send', {
      'json': jsonEncode({
        "@type": "getMessageThreadHistory",
        "chatId": chatId,
        "messageId": messageId,
        "fromMessageId": fromMessageId,
        "offset": offset,
        "limit": limit,
      }),
    });

    if (result["data"] == null) return null;
    try {
      final data = result["data"] is String
          ? jsonDecode(result["data"]) as Map<String, dynamic>
          : result["data"] as Map<String, dynamic>;
      return Messages.fromJson(data);
    } catch (e, stackTrace) {
      logger.e("Failed to parse thread history",
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Returns the ids of chats already loaded in TDLib's in-memory main list.
  ///
  /// Unlike the one-shot `updateNewChat` pushes, this can be called at any time
  /// to recover the current chat list. This is what lets the chat list survive
  /// a Dart hot restart: the native TDLib session persists and still holds the
  /// chats, even though the Dart-side update buffers were wiped.
  static Future<List<int>> getChats({int limit = 200, int? accountId}) async =>
      _idList(
        await _request(
          {
            "@type": "getChats",
            "chatList": {"@type": "chatListMain"},
            "limit": limit,
          },
          accountId: accountId,
        ),
        'chatIds',
      );

  /// Fetches the full chat object for [chatId] from TDLib.
  static Future<Map<String, dynamic>?> getChat({
    required int chatId,
    int? accountId,
  }) async {
    final jsonMap = {"@type": "getChat", "chatId": chatId};

    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode(jsonMap), accountId),
    );

    if (result["data"] == null) return null;
    final data = result["data"] is String
        ? jsonDecode(result["data"]) as Map<String, dynamic>
        : result["data"] as Map<String, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  /// Asks TDLib to load the next slice of the main chat list.
  ///
  /// Answers "Ok" while chats remain and an error once the list is exhausted.
  static Future<String?> loadChats({int limit = 20, int? accountId}) async {
    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode({"@type": "loadChats", "limit": limit}), accountId),
    );
    if (result is! Map) return null;
    return result['type'] as String?;
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

  /// Starts phone-number sign-in, returning TDLib's error message on failure.
  static Future<String?> setAuthenticationPhoneNumber({
    required String phoneNumber,
  }) =>
      _errorOf({
        "@type": "setAuthenticationPhoneNumber",
        "phoneNumber": phoneNumber,
      });

  static Future<void> checkAuthenticationPassword({
    required String password,
  }) =>
      _execute({
        "@type": "checkAuthenticationPassword",
        "password": password,
      });

  /// Starts QR sign-in, returning TDLib's error message on failure.
  static Future<String?> requestQrCodeAuthentication() =>
      _errorOf({"@type": "requestQrCodeAuthentication"});

  static Future<void> resendAuthenticationCode() =>
      _execute({"@type": "resendAuthenticationCode"});

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
    int? accountId,
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

    await _execute(jsonMap, accountId: accountId);
  }

  static Future<String> getAuthorizationState({int? accountId}) async {
    final result = await _channel.invokeMethod(
      'send',
      _sendArgs('{"@type":"getAuthorizationState"}', accountId),
    );
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

  static bool _updatesStarted = false;

  static void initTdlibUpdates() {
    if (_updatesStarted) return;
    _updatesStarted = true;
    _updatesChannel.receiveBroadcastStream().listen((event) {
      final Map<String, dynamic> update;
      try {
        update = jsonDecode(event) as Map<String, dynamic>;
      } catch (e) {
        // A malformed event must not kill the subscription, which would leave
        // the app deaf to every later update.
        logger.e('Undecodable TDLib event', error: e);
        return;
      }
      final type = update['@type'];

      if (type == "UpdateOption" || type == updateUnreadMessageCountConst) {
        return;
      }

      // The bridge reports a failure in one of its own handlers this way.
      if (type == 'UpdateBridgeError') {
        logger.w('TDLib bridge error: ${update['message']}');
        return;
      }

      // Answered for any account, active or not: TDLib holds the request that
      // triggered it until the verification is resolved.
      if (type == updateApplicationVerificationRequiredConst ||
          type == updateApplicationRecaptchaVerificationRequiredConst) {
        _abortApplicationVerification(update);
        return;
      }

      // Unread totals are wanted from every account, so they are split off
      // before the active-account filter below.
      if (type == updateUnreadChatCountConst) {
        _unreadController.add(update);
        return;
      }

      // Notifications are wanted from every account too, most of all in the
      // push isolate, where no account is ever the active one.
      if (type == updateNotificationGroupConst ||
          type == updateActiveNotificationsConst ||
          type == updateNotificationConst ||
          type == updateHavePendingNotificationsConst) {
        _notificationsController.add({
          ...update,
          '@accountId': update['@accountId'] ?? activeAccountId,
        });
        return;
      }

      // An update tagged with another account must never reach the stores and
      // pages, which all describe the account currently on screen.
      final accountId = update['@accountId'] as int?;
      if (accountId != null && accountId != activeAccountId) {
        _backgroundController.add(update);
        return;
      }

      switch (type) {
        case updateAuthorizationStateConst:
          // The account tag sits on the envelope, but listeners only see the
          // state, so it is copied across: with several accounts online, "who
          // is logging out" is as important as "what happened".
          _authUpdatesController.add({
            ...update['authorizationState'] as Map<String, dynamic>,
            '@accountId': accountId ?? activeAccountId,
          });
        case updateConnectionStateConst:
          _connectionStateController.add(
            update['state']?['@type'] as String? ?? '',
          );
        case updateChatFoldersConst || updateNewChatConst || updateChatPositionConst ||
          updateChatLastMessageConst || updateChatAddedToListConst || updateSupergroupFullInfoConst ||
          updateSupergroupConst || updateChatReadInboxConst || updateUserConst ||
          updateChatReadOutboxConst || updateChatActionConst || updateUserStatusConst ||
          updateChatTitleConst || updateChatPhotoConst || updateBasicGroupConst ||
          updateChatNotificationSettingsConst || updateChatPermissionsConst ||
          updateChatIsMarkedAsUnreadConst || updateChatDraftMessageConst ||
          updateChatUnreadMentionCountConst || updateChatEmojiStatusConst:
          _buffer(_chatReplay, update);
          _chatUpdatesController.add(update);
        case updateNewMessageConst || updateDeleteMessagesConst ||
          updateMessageInteractionInfoConst || updateMessageContentConst ||
          updateMessageEditedConst || updateMessageIsPinnedConst ||
          updateMessageSendSucceededConst || updateMessageSendFailedConst:
          _messagesController.add(update);
        case updateFileConst:
          _buffer(_fileReplay, update);
          _filesController.add(update);
        case updateCallConst || updateNewCallSignalingDataConst:
          _callController.add(update);
        default:
          _logUnhandled(type);
      }
    });
  }

  /// The update types already reported as unhandled.
  static final Set<String> _unhandledTypes = {};

  /// Reports an update no store folds in, once per type.
  ///
  /// TDLib pushes hundreds of these while a session syncs, and the logger
  /// captures a stack trace for every line it prints, which by itself is
  /// enough to stutter the first seconds of the app. The name of a type is all
  /// the diagnostic value there was in repeating it.
  static void _logUnhandled(Object? type) {
    final name = type?.toString() ?? '<untyped>';
    if (!_unhandledTypes.add(name)) return;
    logger.i('Skipped update of type: $name');
  }

  // ---------------------------------------------------------------------------
  // Generic request plumbing
  //
  // Everything below is built on these helpers rather than repeating the
  // encode/invoke/decode dance. A TDLib error arrives as a payload without a
  // `data` key, which the helpers treat as "no result".
  // ---------------------------------------------------------------------------

  /// Sends [request] to TDLib and returns its decoded result.
  ///
  /// Returns null when TDLib answered with an error or the bridge produced no
  /// payload, so a caller can treat failure as "nothing came back" instead of
  /// having to catch.
  static Future<Map<String, dynamic>?> _request(
    Map<String, dynamic> request, {
    int? accountId,
  }) async {
    // Named in every log line below: with one client per account, an error
    // without the account it came from cannot be acted on.
    final target = accountId ?? activeAccountId;
    final dynamic result;
    try {
      result = await _channel.invokeMethod(
        'send',
        _sendArgs(jsonEncode(request), accountId),
      );
    } catch (e) {
      logger.e('TDLib ${request['@type']} failed on account $target',
          error: e);
      return null;
    }

    if (result is! Map) return null;
    final data = result['data'];
    if (data == null) {
      final message = result['message'];
      if (message != null) {
        logger.w(
          'TDLib ${request['@type']} error on account $target: $message',
        );
      }
      return null;
    }
    final decoded = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded);
  }

  /// Runs a synchronous TDLib function, which needs no client. Used by
  /// `getPushReceiverId`, which must run before any client exists.
  static Future<Map<String, dynamic>?> executeSync(
    Map<String, dynamic> request,
  ) async {
    final dynamic result;
    try {
      result = await _channel.invokeMethod(
        'execute',
        {'json': jsonEncode(request)},
      );
    } catch (e) {
      logger.e('TDLib execute ${request['@type']} failed', error: e);
      return null;
    }
    if (result is! Map) return null;
    final data = result['data'];
    if (data == null) return null;
    final decoded = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded);
  }

  /// Sends [request] and discards the result, for calls whose effect is only
  /// observed through updates.
  static Future<void> _execute(
    Map<String, dynamic> request, {
    int? accountId,
  }) async {
    await _request(request, accountId: accountId);
  }

  /// Reads a list of ids out of a TDLib `chats`/`users` style response.
  static List<int> _idList(Map<String, dynamic>? data, String key) {
    final ids = data?[key] as List?;
    if (ids == null) return const [];
    return ids.map((id) => (id as num).toInt()).toList();
  }

  /// Copies a TDLib response list into a list of plain maps.
  static List<Map<String, dynamic>> _mapList(
    Map<String, dynamic>? data,
    String key,
  ) {
    final items = data?[key] as List?;
    if (items == null) return const [];
    return [
      for (final item in items)
        if (item != null) Map<String, dynamic>.from(item as Map),
    ];
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Fetches a single message, or null when it is no longer available.
  ///
  /// Used to resolve the message a reply points at: TDLib describes a reply
  /// only as `replyTo.messageId`, never as the message itself.
  static Future<Map<String, dynamic>?> getMessage({
    required int chatId,
    required int messageId,
  }) =>
      _request({
        "@type": "getMessage",
        "chatId": chatId,
        "messageId": messageId,
      });

  /// Fetches several messages of one chat at once. Entries TDLib could not
  /// resolve are dropped, so the result may be shorter than [messageIds].
  static Future<List<Map<String, dynamic>>> getMessages({
    required int chatId,
    required List<int> messageIds,
  }) async {
    final data = await _request({
      "@type": "getMessages",
      "chatId": chatId,
      "messageIds": messageIds,
    });
    return _mapList(data, 'messages');
  }

  /// Sends a recorded voice message.
  ///
  /// [duration] is in seconds and [waveform] holds 5-bit amplitude samples
  /// packed most-significant-bit first, exactly as TDLib stores them; pass an
  /// empty list when no amplitudes were captured.
  static Future<void> sendVoiceNote({
    required int chatId,
    required String path,
    required int duration,
    List<int> waveform = const [],
    String caption = '',
    int? replyToMessageId,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        "inputMessageContent": {
          "@type": "inputMessageVoiceNote",
          "voiceNote": {"@type": "inputFileLocal", "path": path},
          "duration": duration,
          "waveform": TdBytes.encode(waveform),
          if (caption.isNotEmpty)
            "caption": {"@type": "formattedText", "text": caption},
        },
      });

  /// Sends several photos or videos as one album.
  ///
  /// Telegram groups an album into a single bubble, which only happens when the
  /// items are sent together in one request — sending them one by one produces
  /// separate messages instead.
  static Future<void> sendMediaAlbum({
    required int chatId,
    required List<({String path, bool isVideo})> items,
    String caption = '',
    int? replyToMessageId,
    SendOptions options = SendOptions.normal,
  }) =>
      _execute({
        "@type": "sendMessageAlbum",
        "chatId": chatId,
        "messageThreadId": 0,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        if (options.toJson() case final sendOptions?)
          "options": sendOptions,
        "inputMessageContents": [
          for (final (index, item) in items.indexed)
            {
              "@type":
                  item.isVideo ? "inputMessageVideo" : "inputMessagePhoto",
              if (item.isVideo)
                "video": {"@type": "inputFileLocal", "path": item.path}
              else
                "photo": {"@type": "inputFileLocal", "path": item.path},
              "width": 0,
              "height": 0,
              if (item.isVideo) ...{
                "duration": 0,
                "supportsStreaming": true,
              },
              // Telegram shows one caption per album, taken from its first
              // item; repeating it on every item would render it several times.
              if (index == 0 && caption.isNotEmpty)
                "caption": {"@type": "formattedText", "text": caption},
            },
        ],
      });

  /// Sends an already-uploaded sticker by its file id.
  static Future<void> sendSticker({
    required int chatId,
    required int fileId,
    int? replyToMessageId,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        "inputMessageContent": {
          "@type": "inputMessageSticker",
          "sticker": {"@type": "inputFileId", "id": fileId},
          "width": 0,
          "height": 0,
          "emoji": "",
        },
      });

  /// Shares a static geographic position.
  static Future<void> sendLocation({
    required int chatId,
    required double latitude,
    required double longitude,
    int? replyToMessageId,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        "inputMessageContent": {
          "@type": "inputMessageLocation",
          "location": {
            "@type": "location",
            "latitude": latitude,
            "longitude": longitude,
            "horizontalAccuracy": 0,
          },
          "livePeriod": 0,
          "heading": 0,
          "proximityAlertRadius": 0,
        },
      });

  /// Creates a poll message with [question] and at least two [options].
  static Future<void> sendPoll({
    required int chatId,
    required String question,
    required List<String> options,
    bool isAnonymous = true,
    bool allowMultipleAnswers = false,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        "inputMessageContent": {
          "@type": "inputMessagePoll",
          "question": {"@type": "formattedText", "text": question},
          "options": [
            for (final option in options)
              {"@type": "formattedText", "text": option},
          ],
          "isAnonymous": isAnonymous,
          "type": {
            "@type": "pollTypeRegular",
            "allowMultipleAnswers": allowMultipleAnswers,
          },
          "openPeriod": 0,
          "closeDate": 0,
          "isClosed": false,
        },
      });

  /// Marks a message's content as consumed: a voice note as listened to, a
  /// self-destructing photo as opened.
  static Future<void> openMessageContent({
    required int chatId,
    required int messageId,
  }) =>
      _execute({
        "@type": "openMessageContent",
        "chatId": chatId,
        "messageId": messageId,
      });

  /// Returns a public `t.me` link to a message, or null when the chat has no
  /// public link.
  static Future<String?> getMessageLink({
    required int chatId,
    required int messageId,
  }) async {
    final data = await _request({
      "@type": "getMessageLink",
      "chatId": chatId,
      "messageId": messageId,
      "mediaTimestamp": 0,
      "forAlbum": false,
    });
    return data?['link'] as String?;
  }

  /// Retries messages whose delivery failed.
  static Future<void> resendMessages({
    required int chatId,
    required List<int> messageIds,
  }) =>
      _execute({
        "@type": "resendMessages",
        "chatId": chatId,
        "messageIds": messageIds,
      });

  /// Stores the chat's unsent draft, or clears it when [text] is empty, so the
  /// composer survives leaving the chat and syncs to other devices.
  static Future<void> setChatDraftMessage({
    required int chatId,
    required String text,
    int? replyToMessageId,
    int messageThreadId = 0,
  }) =>
      _execute({
        "@type": "setChatDraftMessage",
        "chatId": chatId,
        "messageThreadId": messageThreadId,
        if (text.isNotEmpty)
          "draftMessage": {
            "@type": "draftMessage",
            if (replyToMessageId != null)
              "replyTo": {
                "@type": "inputMessageReplyToMessage",
                "messageId": replyToMessageId,
              },
            "date": DateTime.now().millisecondsSinceEpoch ~/ 1000,
            "inputMessageText": {
              "@type": "inputMessageText",
              "text": {"@type": "formattedText", "text": text},
            },
          },
      });

  // ---------------------------------------------------------------------------
  // Chat list management
  // ---------------------------------------------------------------------------

  /// The TDLib chat list a request should act on.
  static Map<String, dynamic> _chatListOf({bool archived = false}) => {
        "@type": archived ? "chatListArchive" : "chatListMain",
      };

  /// Pins or unpins a chat at the top of its list.
  static Future<void> toggleChatIsPinned({
    required int chatId,
    required bool isPinned,
    bool archived = false,
  }) =>
      _execute({
        "@type": "toggleChatIsPinned",
        "chatList": _chatListOf(archived: archived),
        "chatId": chatId,
        "isPinned": isPinned,
      });

  /// Mutes a chat for [muteFor] seconds, or unmutes it when [muteFor] is 0.
  ///
  /// Telegram expresses "mute forever" as a very large value; see
  /// [muteForever].
  static Future<void> setChatNotificationSettings({
    required int chatId,
    required int muteFor,
  }) =>
      _execute({
        "@type": "setChatNotificationSettings",
        "chatId": chatId,
        "notificationSettings": {
          "@type": "chatNotificationSettings",
          // Only the mute duration is overridden here. The bridge builds the
          // settings object from scratch, so every other `useDefault*` flag
          // has to be set explicitly or the chat would silently lose its
          // inherited sound and preview settings.
          "useDefaultMuteFor": false,
          "muteFor": muteFor,
          "useDefaultSound": true,
          "useDefaultShowPreview": true,
          "useDefaultMuteStories": true,
          "useDefaultStorySound": true,
          "useDefaultShowStoryPoster": true,
          "useDefaultDisablePinnedMessageNotifications": true,
          "useDefaultDisableMentionNotifications": true,
        },
      });

  /// The `muteFor` value Telegram uses for an indefinite mute (about 10 years).
  static const int muteForever = 367417600;

  /// Flags a chat as unread even though its messages have been seen.
  static Future<void> toggleChatIsMarkedAsUnread({
    required int chatId,
    required bool isMarkedAsUnread,
  }) =>
      _execute({
        "@type": "toggleChatIsMarkedAsUnread",
        "chatId": chatId,
        "isMarkedAsUnread": isMarkedAsUnread,
      });

  /// Clears a chat's history.
  ///
  /// [removeFromChatList] also drops the chat from the list; [revoke] clears
  /// the history for the other party too, where the chat allows it.
  static Future<void> deleteChatHistory({
    required int chatId,
    bool removeFromChatList = false,
    bool revoke = false,
  }) =>
      _execute({
        "@type": "deleteChatHistory",
        "chatId": chatId,
        "removeFromChatList": removeFromChatList,
        "revoke": revoke,
      });

  /// Deletes a chat along with all of its messages. Only the owner of a group
  /// or channel can do this; private chats use [deleteChatHistory] instead.
  static Future<void> deleteChat({required int chatId}) =>
      _execute({"@type": "deleteChat", "chatId": chatId});

  /// Leaves a group, supergroup or channel.
  static Future<void> leaveChat({required int chatId}) =>
      _execute({"@type": "leaveChat", "chatId": chatId});

  /// Joins a public group or channel the user can already see.
  static Future<void> joinChat({required int chatId}) =>
      _execute({"@type": "joinChat", "chatId": chatId});

  /// Moves a chat between the main and archived lists.
  static Future<void> addChatToList({
    required int chatId,
    required bool archived,
  }) =>
      _execute({
        "@type": "addChatToList",
        "chatId": chatId,
        "chatList": _chatListOf(archived: archived),
      });

  /// Asks TDLib to load the next slice of the archived chat list.
  ///
  /// Mirrors [loadChats] but for the archive, returning the response `@type`
  /// ("Ok" while more chats remain, "Error" once the list is exhausted).
  static Future<String?> loadArchivedChats({
    int limit = 20,
    int? accountId,
  }) async {
    final dynamic result;
    try {
      result = await _channel.invokeMethod(
        'send',
        _sendArgs(
          jsonEncode({
            "@type": "loadChats",
            "chatList": _chatListOf(archived: true),
            "limit": limit,
          }),
          accountId,
        ),
      );
    } catch (_) {
      return null;
    }
    if (result is! Map) return null;
    return result['data'] == null ? "Error" : result['type'] as String?;
  }

  /// Returns the ids of the chats TDLib currently holds in the archive.
  static Future<List<int>> getArchivedChats({
    int limit = 200,
    int? accountId,
  }) async {
    final data = await _request(
      {
        "@type": "getChats",
        "chatList": _chatListOf(archived: true),
        "limit": limit,
      },
      accountId: accountId,
    );
    return _idList(data, 'chatIds');
  }

  // ---------------------------------------------------------------------------
  // Creating chats
  // ---------------------------------------------------------------------------

  /// Creates a group with [title] and the given members, returning the new
  /// chat or null when creation failed.
  static Future<Map<String, dynamic>?> createNewBasicGroupChat({
    required String title,
    required List<int> userIds,
  }) async {
    final data = await _request({
      "@type": "createNewBasicGroupChat",
      "userIds": userIds,
      "title": title,
      "messageAutoDeleteTime": 0,
    });
    // Newer TDLib versions answer with a `createdBasicGroupChat` wrapper
    // around the chat instead of the chat itself.
    final chat = data?['chat'];
    if (chat is Map) return Map<String, dynamic>.from(chat);
    return data;
  }

  /// Creates a channel (when [isChannel]) or a supergroup.
  static Future<Map<String, dynamic>?> createNewSupergroupChat({
    required String title,
    required bool isChannel,
    String description = '',
  }) =>
      _request({
        "@type": "createNewSupergroupChat",
        "title": title,
        "isForum": false,
        "isChannel": isChannel,
        "description": description,
        "messageAutoDeleteTime": 0,
        "forImport": false,
      });

  /// Renames a chat the user is allowed to administer.
  static Future<void> setChatTitle({
    required int chatId,
    required String title,
  }) =>
      _execute({
        "@type": "setChatTitle",
        "chatId": chatId,
        "title": title,
      });

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches public chats (by username or title) the user isn't a member of.
  static Future<List<int>> searchPublicChats({required String query}) async {
    final data = await _request({
      "@type": "searchPublicChats",
      "query": query,
    });
    return _idList(data, 'chatIds');
  }

  /// Resolves a username to its chat, or null when nothing matches.
  static Future<Map<String, dynamic>?> searchPublicChat({
    required String username,
  }) =>
      _request({"@type": "searchPublicChat", "username": username});

  /// Searches messages across every chat the user takes part in.
  static Future<Messages?> searchMessages({
    required String query,
    int limit = 50,
  }) async {
    final data = await _request({
      "@type": "searchMessages",
      "chatList": _chatListOf(),
      "query": query,
      "offset": "",
      "limit": limit,
    });
    if (data == null) return null;
    return Messages.fromJson(data);
  }

  /// Returns the user's call history, newest first.
  static Future<Messages?> searchCallMessages({int limit = 50}) async {
    final data = await _request({
      "@type": "searchCallMessages",
      "offset": "",
      "limit": limit,
      "onlyMissed": false,
    });
    if (data == null) return null;
    return Messages.fromJson(data);
  }

  /// Looks up an invite link without joining, so the target can be previewed.
  static Future<Map<String, dynamic>?> checkChatInviteLink({
    required String link,
  }) =>
      _request({"@type": "checkChatInviteLink", "inviteLink": link});

  /// Joins a chat through an invite link and returns the joined chat.
  static Future<Map<String, dynamic>?> joinChatByInviteLink({
    required String link,
  }) =>
      _request({"@type": "joinChatByInviteLink", "inviteLink": link});

  // ---------------------------------------------------------------------------
  // Contacts and blocking
  // ---------------------------------------------------------------------------

  /// Returns the user ids in the account's contact list.
  static Future<List<int>> getContacts() async {
    final data = await _request({"@type": "getContacts"});
    return _idList(data, 'userIds');
  }

  /// Adds [userId] to the contact list under the given name.
  static Future<void> addContact({
    required int userId,
    required String firstName,
    String lastName = '',
    String phoneNumber = '',
  }) =>
      _execute({
        "@type": "addContact",
        "contact": {
          "@type": "contact",
          "phoneNumber": phoneNumber,
          "firstName": firstName,
          "lastName": lastName,
          "vcard": "",
          "userId": userId,
        },
        "sharePhoneNumber": false,
      });

  /// Removes users from the contact list.
  static Future<void> removeContacts({required List<int> userIds}) =>
      _execute({"@type": "removeContacts", "userIds": userIds});

  /// Blocks or unblocks a user.
  ///
  /// TDLib models "not blocked" as a null block list, hence the nullable field.
  static Future<void> setUserBlocked({
    required int userId,
    required bool blocked,
  }) =>
      _execute({
        "@type": "setMessageSenderBlockList",
        "senderId": {"@type": "messageSenderUser", "userId": userId},
        // TDLib models "not blocked" as a null block list. The bridge cannot
        // assign a JSON null to a typed field, so unblocking omits the key.
        if (blocked) "blockList": {"@type": "blockListMain"},
      });

  /// Returns the blocked senders, newest first.
  static Future<List<Map<String, dynamic>>> getBlockedMessageSenders({
    int limit = 100,
  }) async {
    final data = await _request({
      "@type": "getBlockedMessageSenders",
      "blockList": {"@type": "blockListMain"},
      "offset": 0,
      "limit": limit,
    });
    return _mapList(data, 'senders');
  }

  // ---------------------------------------------------------------------------
  // Stickers
  // ---------------------------------------------------------------------------

  /// Returns the user's installed sticker sets as covers; call [getStickerSet]
  /// for a set's full sticker list.
  static Future<List<Map<String, dynamic>>> getInstalledStickerSets() async {
    final data = await _request({
      "@type": "getInstalledStickerSets",
      "stickerType": {"@type": "stickerTypeRegular"},
    });
    return _mapList(data, 'sets');
  }

  /// Returns a sticker set with all of its stickers.
  static Future<Map<String, dynamic>?> getStickerSet({required int setId}) =>
      _request({"@type": "getStickerSet", "setId": setId});

  /// Returns the recently used stickers.
  static Future<List<Map<String, dynamic>>> getRecentStickers({
    int limit = 40,
  }) async {
    final data = await _request({
      "@type": "getRecentStickers",
      "isAttached": false,
      "limit": limit,
    });
    return _mapList(data, 'stickers');
  }

  /// Records a sticker as recently used so it surfaces first next time.
  static Future<void> addRecentSticker({required int fileId}) => _execute({
        "@type": "addRecentSticker",
        "isAttached": false,
        "sticker": {"@type": "inputFileId", "id": fileId},
      });

  // ---------------------------------------------------------------------------
  // Account settings
  // ---------------------------------------------------------------------------

  /// Returns the sessions currently signed in to this account.
  static Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final data = await _request({"@type": "getActiveSessions"});
    return _mapList(data, 'sessions');
  }

  /// Signs another device out of the account.
  static Future<void> terminateSession({required int sessionId}) =>
      _execute({"@type": "terminateSession", "sessionId": sessionId});

  /// Returns the default notification settings for a scope, one of
  /// `notificationSettingsScopePrivateChats`, `...GroupChats` or
  /// `...ChannelChats`.
  static Future<Map<String, dynamic>?> getScopeNotificationSettings({
    required String scope,
    int? accountId,
  }) =>
      _request(
        {
          "@type": "getScopeNotificationSettings",
          "scope": {"@type": scope},
        },
        accountId: accountId,
      );

  /// Mutes or unmutes a whole scope of chats by default.
  static Future<void> setScopeNotificationSettings({
    required String scope,
    required int muteFor,
  }) =>
      _execute({
        "@type": "setScopeNotificationSettings",
        "scope": {"@type": scope},
        "notificationSettings": {
          "@type": "scopeNotificationSettings",
          "muteFor": muteFor,
        },
      });

  /// Returns a cheap approximation of the on-disk size of downloaded files.
  static Future<Map<String, dynamic>?> getStorageStatisticsFast() =>
      _request({"@type": "getStorageStatisticsFast"});

  /// Deletes downloaded files to reclaim space. With these arguments TDLib
  /// clears the whole file cache.
  static Future<Map<String, dynamic>?> optimizeStorage() => _request({
        "@type": "optimizeStorage",
        "size": 0,
        "ttl": 0,
        "count": 0,
        "immunityDelay": 0,
        "chatLimit": 0,
        "returnDeletedFileStatistics": false,
      });

  /// Sets the current user's profile photo from a local image file.
  static Future<void> setProfilePhoto({required String path}) => _execute({
        "@type": "setProfilePhoto",
        "photo": {
          "@type": "inputChatPhotoStatic",
          "photo": {"@type": "inputFileLocal", "path": path},
        },
        "isPublic": false,
      });

  /// Returns extended info for a basic group (member list, invite link).
  static Future<Map<String, dynamic>?> getBasicGroupFullInfo({
    required int basicGroupId,
  }) =>
      _request({
        "@type": "getBasicGroupFullInfo",
        "basicGroupId": basicGroupId,
      });

  /// Returns extended info for a supergroup or channel.
  static Future<Map<String, dynamic>?> getSupergroupFullInfo({
    required int supergroupId,
  }) =>
      _request({
        "@type": "getSupergroupFullInfo",
        "supergroupId": supergroupId,
      });

  // ---------------------------------------------------------------------------
  // Group and channel administration
  // ---------------------------------------------------------------------------

  /// Returns members of a supergroup or channel.
  ///
  /// [filter] is a `SupergroupMembersFilter*` type name; the default lists the
  /// most recently active members.
  static Future<List<Map<String, dynamic>>> getSupergroupMembers({
    required int supergroupId,
    String filter = 'supergroupMembersFilterRecent',
    int offset = 0,
    int limit = 200,
  }) async {
    final data = await _request({
      "@type": "getSupergroupMembers",
      "supergroupId": supergroupId,
      "filter": {"@type": filter},
      "offset": offset,
      "limit": limit,
    });
    return _mapList(data, 'members');
  }

  /// Invites users into a chat.
  static Future<void> addChatMembers({
    required int chatId,
    required List<int> userIds,
  }) =>
      _execute({
        "@type": "addChatMembers",
        "chatId": chatId,
        "userIds": userIds,
        "forwardLimit": 0,
      });

  /// Sets a member's status in a chat.
  ///
  /// [status] is a full `chatMemberStatus*` object, since each variant carries
  /// its own fields — see [memberStatus], [adminStatus] and the removal helpers
  /// below rather than building one by hand.
  static Future<void> setChatMemberStatus({
    required int chatId,
    required int userId,
    required Map<String, dynamic> status,
  }) =>
      _execute({
        "@type": "setChatMemberStatus",
        "chatId": chatId,
        "memberId": {"@type": "messageSenderUser", "userId": userId},
        "status": status,
      });

  /// The status of an ordinary member, used to demote an administrator.
  static Map<String, dynamic> memberStatus() => {
        "@type": "chatMemberStatusMember",
      };

  /// The status of an administrator with the everyday moderation rights.
  ///
  /// Deliberately leaves out ownership-adjacent powers (adding other admins,
  /// anonymity), which Telegram also keeps off by default.
  static Map<String, dynamic> adminStatus({String customTitle = ''}) => {
        "@type": "chatMemberStatusAdministrator",
        "customTitle": customTitle,
        "canBeEdited": true,
        "rights": {
          "@type": "chatAdministratorRights",
          "canManageChat": true,
          "canChangeInfo": true,
          "canPostMessages": true,
          "canEditMessages": true,
          "canDeleteMessages": true,
          "canInviteUsers": true,
          "canRestrictMembers": true,
          "canPinMessages": true,
          "canManageTopics": true,
          "canPromoteMembers": false,
          "canManageVideoChats": true,
          "canPostStories": false,
          "canEditStories": false,
          "canDeleteStories": false,
          "isAnonymous": false,
        },
      };

  /// Removes a user from a chat without banning them.
  static Future<void> removeChatMember({
    required int chatId,
    required int userId,
  }) =>
      setChatMemberStatus(
        chatId: chatId,
        userId: userId,
        status: {"@type": "chatMemberStatusLeft"},
      );

  /// Bans a user from a chat permanently.
  static Future<void> banChatMember({
    required int chatId,
    required int userId,
  }) =>
      setChatMemberStatus(
        chatId: chatId,
        userId: userId,
        status: {
          "@type": "chatMemberStatusBanned",
          // Zero means "forever" for a ban's expiry.
          "bannedUntilDate": 0,
        },
      );

  /// Sets a chat's photo from a local image file.
  static Future<void> setChatPhoto({
    required int chatId,
    required String path,
  }) =>
      _execute({
        "@type": "setChatPhoto",
        "chatId": chatId,
        "photo": {
          "@type": "inputChatPhotoStatic",
          "photo": {"@type": "inputFileLocal", "path": path},
        },
      });

  /// Sets a group's or channel's description.
  static Future<void> setChatDescription({
    required int chatId,
    required String description,
  }) =>
      _execute({
        "@type": "setChatDescription",
        "chatId": chatId,
        "description": description,
      });

  /// Creates (or returns) the invite link for a chat the user administers.
  static Future<String?> replacePrimaryChatInviteLink({
    required int chatId,
  }) async {
    final data = await _request({
      "@type": "createChatInviteLink",
      "chatId": chatId,
      "name": "",
      "expirationDate": 0,
      "memberLimit": 0,
      "createsJoinRequest": false,
    });
    return data?['inviteLink'] as String?;
  }

  // ---------------------------------------------------------------------------
  // More message kinds
  // ---------------------------------------------------------------------------

  /// Sends a round video message.
  ///
  /// [length] is the diameter of the square source video in pixels; TDLib
  /// crops it to a circle on display.
  static Future<void> sendVideoNote({
    required int chatId,
    required String path,
    required int duration,
    int length = 384,
    int? replyToMessageId,
    SendOptions options = SendOptions.normal,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        if (options.toJson() case final sendOptions?)
          "options": sendOptions,
        "inputMessageContent": {
          "@type": "inputMessageVideoNote",
          "videoNote": {"@type": "inputFileLocal", "path": path},
          "duration": duration,
          "length": length,
        },
      });

  /// Shares a Telegram user as a contact card.
  static Future<void> sendContact({
    required int chatId,
    required int userId,
    required String firstName,
    String lastName = '',
    String phoneNumber = '',
    int? replyToMessageId,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        "inputMessageContent": {
          "@type": "inputMessageContact",
          "contact": {
            "@type": "contact",
            "phoneNumber": phoneNumber,
            "firstName": firstName,
            "lastName": lastName,
            "vcard": "",
            "userId": userId,
          },
        },
      });

  /// Returns the user's saved GIFs.
  static Future<List<Map<String, dynamic>>> getSavedAnimations() async {
    final data = await _request({"@type": "getSavedAnimations"});
    return _mapList(data, 'animations');
  }

  /// Sends a saved GIF by its file id.
  static Future<void> sendAnimation({
    required int chatId,
    required int fileId,
    int? replyToMessageId,
  }) =>
      _execute({
        "@type": "sendMessage",
        "chatId": chatId,
        if (replyToMessageId != null)
          "replyTo": {
            "@type": "inputMessageReplyToMessage",
            "messageId": replyToMessageId,
          },
        "inputMessageContent": {
          "@type": "inputMessageAnimation",
          "animation": {"@type": "inputFileId", "id": fileId},
          "duration": 0,
          "width": 0,
          "height": 0,
        },
      });

  /// The messages a chat has scheduled for later, newest first.
  static Future<List<Map<String, dynamic>>> getChatScheduledMessages({
    required int chatId,
  }) async {
    final data = await _request({
      "@type": "getChatScheduledMessages",
      "chatId": chatId,
    });
    return _mapList(data, 'messages');
  }

  /// Presses an inline-keyboard button and returns the bot's answer.
  ///
  /// [data] is the button's opaque callback payload, which the bridge hands
  /// over as Base64 because TDLib types it as bytes.
  static Future<Map<String, dynamic>?> getCallbackQueryAnswer({
    required int chatId,
    required int messageId,
    required List<int> data,
  }) =>
      _request({
        "@type": "getCallbackQueryAnswer",
        "chatId": chatId,
        "messageId": messageId,
        "payload": {
          "@type": "callbackQueryPayloadData",
          "data": TdBytes.encode(data),
        },
      });

  // ---------------------------------------------------------------------------
  // Secret chats and two-step verification
  // ---------------------------------------------------------------------------

  /// Starts an end-to-end encrypted chat with [userId] and returns it.
  static Future<Map<String, dynamic>?> createNewSecretChat({
    required int userId,
  }) =>
      _request({"@type": "createNewSecretChat", "userId": userId});

  /// The account's two-step verification state.
  static Future<Map<String, dynamic>?> getPasswordState() =>
      _request({"@type": "getPasswordState"});

  /// Sets, changes or (with an empty [newPassword]) removes the two-step
  /// verification password.
  ///
  /// Returns the new state, or null when TDLib rejected the change — most
  /// often because [oldPassword] was wrong.
  static Future<Map<String, dynamic>?> setPassword({
    String oldPassword = '',
    String newPassword = '',
    String newHint = '',
    String newRecoveryEmailAddress = '',
  }) =>
      _request({
        "@type": "setPassword",
        "oldPassword": oldPassword,
        "newPassword": newPassword,
        "newHint": newHint,
        "setRecoveryEmailAddress": newRecoveryEmailAddress.isNotEmpty,
        "newRecoveryEmailAddress": newRecoveryEmailAddress,
      });

  // ---------------------------------------------------------------------------
  // Proxies
  // ---------------------------------------------------------------------------

  /// Every proxy the account has stored, the enabled one included.
  static Future<List<Map<String, dynamic>>> getProxies() async =>
      _mapList(await _request({"@type": "getProxies"}), 'proxies');

  /// Adds a proxy and returns it with the id TDLib assigned.
  ///
  /// [type] must come from [socks5Proxy], [httpProxy] or [mtprotoProxy].
  static Future<Map<String, dynamic>?> addProxy({
    required String server,
    required int port,
    required Map<String, dynamic> type,
    bool enable = true,
  }) =>
      _request({
        "@type": "addProxy",
        "server": server,
        "port": port,
        "enable": enable,
        "type": type,
      });

  /// Replaces the settings of the proxy with [proxyId].
  static Future<Map<String, dynamic>?> editProxy({
    required int proxyId,
    required String server,
    required int port,
    required Map<String, dynamic> type,
    bool enable = true,
  }) =>
      _request({
        "@type": "editProxy",
        "proxyId": proxyId,
        "server": server,
        "port": port,
        "enable": enable,
        "type": type,
      });

  /// Routes all traffic through the proxy with [proxyId].
  static Future<void> enableProxy(int proxyId) =>
      _execute({"@type": "enableProxy", "proxyId": proxyId});

  /// Goes back to a direct connection without forgetting any proxy.
  static Future<void> disableProxy() => _execute({"@type": "disableProxy"});

  /// Forgets the proxy with [proxyId].
  static Future<void> removeProxy(int proxyId) =>
      _execute({"@type": "removeProxy", "proxyId": proxyId});

  /// Measures the round trip to the proxy with [proxyId], in seconds.
  ///
  /// Returns null when the proxy could not be reached, which is the only way
  /// to tell a working proxy from a dead one before switching to it.
  static Future<double?> pingProxy(int proxyId) async {
    final result = await _request({"@type": "pingProxy", "proxyId": proxyId});
    return (result?['seconds'] as num?)?.toDouble();
  }

  /// A SOCKS5 proxy type, with optional credentials.
  static Map<String, dynamic> socks5Proxy({
    String username = '',
    String password = '',
  }) => {
    "@type": "proxyTypeSocks5",
    "username": username,
    "password": password,
  };

  /// An HTTP proxy type.
  ///
  /// `httpOnly` stays false: an HTTP-only proxy can serve web requests but
  /// not the MTProto stream TDLib needs.
  static Map<String, dynamic> httpProxy({
    String username = '',
    String password = '',
  }) => {
    "@type": "proxyTypeHttp",
    "username": username,
    "password": password,
    "httpOnly": false,
  };

  /// An MTProto proxy type, identified by the secret from a `t.me/proxy` link.
  static Map<String, dynamic> mtprotoProxy(String secret) => {
    "@type": "proxyTypeMtproto",
    "secret": secret,
  };

  // ---------------------------------------------------------------------------
  // Automatic media download
  // ---------------------------------------------------------------------------

  /// Tells TDLib which connection is in use, as a `networkType*` name.
  ///
  /// TDLib uses this for its own bookkeeping and for the per-network limits
  /// it syncs across clients; it does not detect the network itself.
  static Future<void> setNetworkType(
    String networkType, {
    int? accountId,
  }) =>
      _execute(
        {
          "@type": "setNetworkType",
          "type": {"@type": networkType},
        },
        accountId: accountId,
      );

  /// The low, medium and high presets TDLib recommends for this network.
  static Future<Map<String, dynamic>?> getAutoDownloadSettingsPresets() =>
      _request({"@type": "getAutoDownloadSettingsPresets"});

  /// Stores [settings] as the automatic download rules for [networkType].
  ///
  /// [networkType] is a `networkType*` type name, such as `networkTypeWiFi`.
  static Future<void> setAutoDownloadSettings({
    required Map<String, dynamic> settings,
    required String networkType,
  }) => _execute({
    "@type": "setAutoDownloadSettings",
    "settings": settings,
    "type": {"@type": networkType},
  });

  // ---------------------------------------------------------------------------
  // Message extras
  // ---------------------------------------------------------------------------

  /// Sets the self-destruct timer for [chatId], in seconds.
  ///
  /// Zero turns it off. Telegram only offers a day, a week and a month, but
  /// TDLib accepts any value.
  static Future<void> setChatMessageAutoDeleteTime({
    required int chatId,
    required int autoDeleteTime,
  }) => _execute({
    "@type": "setChatMessageAutoDeleteTime",
    "chatId": chatId,
    "messageAutoDeleteTime": autoDeleteTime,
  });

  /// Translates a message's text into [toLanguageCode].
  ///
  /// Returns a `formattedText`, so formatting inside the message survives.
  static Future<Map<String, dynamic>?> translateMessageText({
    required int chatId,
    required int messageId,
    required String toLanguageCode,
  }) => _request({
    "@type": "translateMessageText",
    "chatId": chatId,
    "messageId": messageId,
    "toLanguageCode": toLanguageCode,
  });

  /// Who reacted to a message, newest first.
  ///
  /// Pass [reactionType] to list one reaction only; omit it for all of them.
  /// [offset] comes from a previous response's `nextOffset`.
  static Future<Map<String, dynamic>?> getMessageAddedReactions({
    required int chatId,
    required int messageId,
    Map<String, dynamic>? reactionType,
    String offset = '',
    int limit = 50,
  }) => _request({
    "@type": "getMessageAddedReactions",
    "chatId": chatId,
    "messageId": messageId,
    if (reactionType != null) "reactionType": reactionType,
    "offset": offset,
    "limit": limit,
  });

  /// Who has read a message in a small group.
  ///
  /// TDLib only answers for groups below a server-side member limit and for
  /// messages younger than a week; anywhere else the list comes back empty.
  static Future<List<Map<String, dynamic>>> getMessageViewers({
    required int chatId,
    required int messageId,
  }) async => _mapList(
    await _request({
      "@type": "getMessageViewers",
      "chatId": chatId,
      "messageId": messageId,
    }),
    'viewers',
  );

  // ---------------------------------------------------------------------------
  // Bots
  // ---------------------------------------------------------------------------

  /// The `botInfo` of [userId], or null when the user is not a bot.
  ///
  /// Both the advertised commands and the menu button live here, so one call
  /// covers the whole composer bot affordance.
  static Future<Map<String, dynamic>?> getBotInfo(int userId) async {
    final info = await getUserFullInfo(userId: userId);
    final botInfo = info?['botInfo'];
    if (botInfo is! Map) return null;
    return Map<String, dynamic>.from(botInfo);
  }

  // ---------------------------------------------------------------------------
  // Localization
  // ---------------------------------------------------------------------------

  /// Every language pack the server offers, official and custom.
  static Future<List<Map<String, dynamic>>> getLocalizationTargetInfo({
    bool onlyLocal = false,
  }) async => _mapList(
    await _request({
      "@type": "getLocalizationTargetInfo",
      "onlyLocal": onlyLocal,
    }),
    'languagePacks',
  );

  /// Strings of [languagePackId] in the current localization target.
  ///
  /// An empty [keys] asks for the whole pack. Each entry is `{key, value}`,
  /// where the value is an ordinary, pluralized or deleted string.
  static Future<List<Map<String, dynamic>>> getLanguagePackStrings({
    required String languagePackId,
    List<String> keys = const [],
  }) async =>
      _mapList(
        await _request({
          "@type": "getLanguagePackStrings",
          "languagePackId": languagePackId,
          "keys": keys,
        }),
        'strings',
      );

  /// Reads a TDLib option whose value is a string.
  ///
  /// Needs its own reader: the bridge answers `optionValueString` with a
  /// `{@type, value}` map rather than the usual `data` payload, so the generic
  /// request helper would see no result at all.
  static Future<String?> getStringOption(String name) async {
    final result = await _channel.invokeMethod(
      'send',
      _sendArgs(jsonEncode({"@type": "getOption", "name": name}), null),
    );
    if (result is! Map) return null;
    return result['value'] as String?;
  }

  /// Switches TDLib's own strings to [languagePackId].
  ///
  /// This only affects text TDLib generates — service messages and error
  /// strings; the app's own labels come from its bundled translations.
  static Future<void> setLanguagePackId(String languagePackId) async {
    await _execute({
      "@type": "setOption",
      "name": "language_pack_id",
      "value": {"@type": "optionValueString", "value": languagePackId},
    });
    await _execute({
      "@type": "synchronizeLanguagePack",
      "languagePackId": languagePackId,
    });
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Finishes signing up a phone number that has no Telegram account yet.
  ///
  /// Only valid while the authorization state is
  /// `AuthorizationStateWaitRegistration`.
  static Future<void> registerUser({
    required String firstName,
    required String lastName,
    bool disableNotification = false,
  }) => _execute({
    "@type": "registerUser",
    "firstName": firstName,
    "lastName": lastName,
    "disableNotification": disableNotification,
  });

  // Push notifications
  // ---------------------------------------------------------------------------

  /// Subscribes this device to Telegram's pushes for [accountId], returning
  /// the push receiver id. `encrypt` is on so the server never sees the text.
  static Future<int?> registerDevice({
    required String token,
    int? accountId,
  }) async {
    final data = await _request({
      "@type": "registerDevice",
      "deviceToken": {
        "@type": "deviceTokenFirebaseCloudMessaging",
        "token": token,
        "encrypt": true,
      },
      "otherUserIds": <int>[],
    }, accountId: accountId);
    return (data?['id'] as num?)?.toInt();
  }

  /// Hands TDLib the raw push payload to decrypt into notifications.
  /// Completes once every update has been sent, so the client may then close.
  static Future<void> processPushNotification({
    required String payload,
    int? accountId,
  }) =>
      _execute(
        {"@type": "processPushNotification", "payload": payload},
        accountId: accountId,
      );

  /// The push receiver id a payload is addressed to, or null when it cannot
  /// be read. Zero means every client should process it.
  static Future<int?> getPushReceiverId(String payload) async {
    final data = await executeSync({
      "@type": "getPushReceiverId",
      "payload": payload,
    });
    return (data?['id'] as num?)?.toInt();
  }

  /// Tells TDLib a whole notification group was dismissed.
  static Future<void> removeNotificationGroup({
    required int notificationGroupId,
    required int maxNotificationId,
    int? accountId,
  }) =>
      _execute({
        "@type": "removeNotificationGroup",
        "notificationGroupId": notificationGroupId,
        "maxNotificationId": maxNotificationId,
      }, accountId: accountId);

  /// Tells TDLib a single notification was dismissed.
  static Future<void> removeNotification({
    required int notificationGroupId,
    required int notificationId,
    int? accountId,
  }) =>
      _execute({
        "@type": "removeNotification",
        "notificationGroupId": notificationGroupId,
        "notificationId": notificationId,
      }, accountId: accountId);

  /// Sets an integer TDLib option, used to switch the Notification API on.
  static Future<void> setIntOption({
    required String name,
    required int value,
    int? accountId,
  }) =>
      _execute({
        "@type": "setOption",
        "name": name,
        "value": {"@type": "optionValueInteger", "value": value},
      }, accountId: accountId);
}
