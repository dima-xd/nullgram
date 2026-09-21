import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A production filter, or a release build logs nothing at all and a push that
// renders no notification leaves no trace in logcat.
final _log = Logger(filter: ProductionFilter());

/// Subscribes each signed-in account to Telegram's pushes, and remembers
/// which account a later push belongs to.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const MethodChannel _channel = MethodChannel('nullgram_push');

  /// Keyed by receiver id: a push names only that id, and the process
  /// handling it is usually a new one with no memory of who registered it.
  static const String _receiversKey = 'push_receivers';

  /// Accounts already registered with the current token.
  final Set<int> _registered = {};

  /// Chains every mutation of [_receiversKey] so concurrent callers cannot
  /// clobber each other's read-modify-write.
  Future<void> _writes = Future.value();

  String? _token;

  /// Registers every known account again, installed by whoever knows which
  /// accounts exist. A refreshed token invalidates the old registrations.
  Future<void> Function()? reregisterAccounts;

  /// The FCM token, or null when this build ships no Firebase configuration.
  Future<String?> token() async {
    if (_token != null) return _token;
    try {
      _token = await _channel.invokeMethod<String>('getToken');
    } catch (e) {
      _log.w('No FCM token available: $e');
      return null;
    }
    if (_token == null) {
      _log.w('No FCM token: this build has no google-services.json');
    }
    return _token;
  }

  /// Starts listening for token refreshes, which invalidate every
  /// registration.
  void listenForTokenRefresh() {
    _channel.setMethodCallHandler((call) async {
      // A push is dropped on purpose here: this isolate has every account
      // online, so TDLib delivers the message over its own socket.
      if (call.method == 'onPush') return null;
      if (call.method != 'onToken') return null;
      acceptToken(call.arguments as String?);
      return null;
    });
  }

  /// Takes a refreshed token, which invalidates every registration made with
  /// the previous one.
  void acceptToken(String? token) {
    _token = token;
    _registered.clear();
    _log.i('FCM token refreshed');
    unawaited(reregisterAccounts?.call());
  }

  /// Tells the native side this engine can take pushes, which stops one being
  /// handed to a headless engine. Call once the accounts are online.
  Future<void> markReady() async {
    try {
      await _channel.invokeMethod('ready');
    } catch (e) {
      _log.w('Could not report push readiness: $e');
    }
  }

  /// Registers [accountId] for pushes, at most once per token.
  Future<void> register(int accountId) async {
    if (_registered.contains(accountId)) return;
    final value = await token();
    if (value == null) return;

    final receiverId = await TDLibClient.registerDevice(
      token: value,
      accountId: accountId,
    );
    if (receiverId == null) {
      _log.w('registerDevice failed for account $accountId');
      return;
    }

    _registered.add(accountId);
    await rememberReceiver(accountId: accountId, receiverId: receiverId);
    _log.i('Account $accountId registered for pushes as $receiverId');
  }

  /// Stores the receiver id of [accountId], replacing any previous one.
  Future<void> rememberReceiver({
    required int accountId,
    required int receiverId,
  }) {
    return _mutateReceivers((receivers) {
      receivers.removeWhere((_, id) => id == accountId);
      receivers['$receiverId'] = accountId;
    });
  }

  /// The account a push addressed to [receiverId] belongs to.
  Future<int?> accountForReceiver(int receiverId) async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(preferences.getString(_receiversKey))['$receiverId'];
  }

  /// Every account with a stored receiver id, for a push addressed to all.
  Future<List<int>> registeredAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    return _decode(preferences.getString(_receiversKey)).values.toList();
  }

  /// Drops the registration of an account that signed out.
  Future<void> forget(int accountId) {
    _registered.remove(accountId);
    return _mutateReceivers((receivers) {
      receivers.removeWhere((_, id) => id == accountId);
    });
  }

  /// Runs [mutate] on the current receiver map and persists the result,
  /// queued behind every other pending mutation so none is lost.
  Future<void> _mutateReceivers(void Function(Map<String, int>) mutate) {
    final next = _writes.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final receivers = _decode(preferences.getString(_receiversKey));
        mutate(receivers);
        await preferences.setString(_receiversKey, jsonEncode(receivers));
      } catch (e) {
        // Absorbed rather than propagated: a rejected future here would be
        // chained onto, and would fail every later mutation of the map.
        _log.w('Could not persist the push receivers', error: e);
      }
    });
    _writes = next;
    return next;
  }

  Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: (entry.value as num).toInt(),
      };
    } catch (e) {
      _log.w('Unreadable push receiver map, starting over: $e');
      return {};
    }
  }
}
