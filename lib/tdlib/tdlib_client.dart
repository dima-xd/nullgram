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

  static final _messagesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get messsagesUpdates => _messagesController.stream;

  static final _filesController = ReplaySubject<Map<String, dynamic>>();
  static Stream<Map<String, dynamic>> get filesUpdates => _filesController.stream;

  static Future<void> sendMessage({required int chatId, required String text}) async {
    final jsonMap = {
      "@type": "sendMessage",
      "chatId": chatId,
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

      if (type == "UpdateOption") {
        return;
      }

      switch (type) {
        case updateAuthorizationStateConst:
          _authUpdatesController.add(update['authorizationState']);
        case updateChatFoldersConst || updateNewChatConst || updateChatPositionConst || updateChatLastMessageConst || updateChatAddedToListConst || updateSupergroupFullInfoConst || updateSupergroupConst || updateChatReadInboxConst || updateUserConst:
          _chatUpdatesController.add(update);
        case updateNewMessageConst:
          _messagesController.add(update);
        case updateFileConst:
          _filesController.add(update);
        default:
          logger.i("Skipped update of type: $type");
      }
    });
  }
}