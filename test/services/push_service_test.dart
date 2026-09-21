import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pushChannel = MethodChannel('nullgram_push');
const _tdlibChannel = MethodChannel('tdlib_channel');
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pushChannel, null);
    messenger.setMockMethodCallHandler(_tdlibChannel, null);
  });

  group('PushService receiver ids', () {
    test('remembers which account a receiver id belongs to', () async {
      await PushService.instance
          .rememberReceiver(accountId: 2, receiverId: 99);

      expect(await PushService.instance.accountForReceiver(99), 2);
    });

    test('answers null for a receiver id it never stored', () async {
      await PushService.instance
          .rememberReceiver(accountId: 2, receiverId: 99);

      expect(await PushService.instance.accountForReceiver(1), isNull);
    });

    test('a re-registration replaces the account previous id', () async {
      await PushService.instance
          .rememberReceiver(accountId: 2, receiverId: 99);
      await PushService.instance
          .rememberReceiver(accountId: 2, receiverId: 100);

      expect(await PushService.instance.accountForReceiver(99), isNull);
      expect(await PushService.instance.accountForReceiver(100), 2);
    });

    test('two accounts keep their own receiver ids', () async {
      await PushService.instance
          .rememberReceiver(accountId: 1, receiverId: 10);
      await PushService.instance
          .rememberReceiver(accountId: 2, receiverId: 20);

      expect(await PushService.instance.accountForReceiver(10), 1);
      expect(await PushService.instance.accountForReceiver(20), 2);
    });

    test('forgetting an account drops its receiver id', () async {
      await PushService.instance
          .rememberReceiver(accountId: 1, receiverId: 10);

      await PushService.instance.forget(1);

      expect(await PushService.instance.accountForReceiver(10), isNull);
    });

    test('lists every account that registered', () async {
      await PushService.instance.rememberReceiver(accountId: 1, receiverId: 10);
      await PushService.instance.rememberReceiver(accountId: 2, receiverId: 20);

      expect(await PushService.instance.registeredAccounts(), [1, 2]);
    });

    test('lists nothing before any registration', () async {
      expect(await PushService.instance.registeredAccounts(), isEmpty);
    });

    test('two concurrent writes do not clobber each other', () async {
      final first =
          PushService.instance.rememberReceiver(accountId: 1, receiverId: 10);
      final second =
          PushService.instance.rememberReceiver(accountId: 2, receiverId: 20);
      await Future.wait([first, second]);

      expect(await PushService.instance.accountForReceiver(10), 1);
      expect(await PushService.instance.accountForReceiver(20), 2);
    });
  });

  group('PushService registration', () {
    // Simulates a token push, the only public way to clear the cached
    // token and the registration guard between tests.
    Future<void> resetToken(String? token) async {
      PushService.instance.listenForTokenRefresh();
      final data = _codec.encodeMethodCall(MethodCall('onToken', token));
      await messenger.handlePlatformMessage('nullgram_push', data, (_) {});
    }

    setUp(() => resetToken(null));

    test('a successful register stores the mapping', () async {
      messenger.setMockMethodCallHandler(_pushChannel, (call) async {
        return call.method == 'getToken' ? 'token-a' : null;
      });
      messenger.setMockMethodCallHandler(_tdlibChannel, (call) async {
        return {
          'data': jsonEncode({'@type': 'PushReceiverId', 'id': 99}),
        };
      });

      await PushService.instance.register(5);

      expect(await PushService.instance.accountForReceiver(99), 5);
    });

    test('a null token registers nothing', () async {
      var sendCalls = 0;
      messenger.setMockMethodCallHandler(_pushChannel, (call) async {
        return call.method == 'getToken' ? null : null;
      });
      messenger.setMockMethodCallHandler(_tdlibChannel, (call) async {
        sendCalls++;
        return null;
      });

      await PushService.instance.register(6);

      expect(sendCalls, 0);
    });

    test('a second register for the same account skips TDLib', () async {
      var sendCalls = 0;
      messenger.setMockMethodCallHandler(_pushChannel, (call) async {
        return call.method == 'getToken' ? 'token-b' : null;
      });
      messenger.setMockMethodCallHandler(_tdlibChannel, (call) async {
        sendCalls++;
        return {
          'data': jsonEncode({'@type': 'PushReceiverId', 'id': 100}),
        };
      });

      await PushService.instance.register(7);
      await PushService.instance.register(7);

      expect(sendCalls, 1);
    });

    test('a token refresh lets the next register go through again',
        () async {
      var sendCalls = 0;
      messenger.setMockMethodCallHandler(_pushChannel, (call) async {
        return call.method == 'getToken' ? 'token-c' : null;
      });
      messenger.setMockMethodCallHandler(_tdlibChannel, (call) async {
        sendCalls++;
        return {
          'data': jsonEncode({'@type': 'PushReceiverId', 'id': 101}),
        };
      });

      await PushService.instance.register(8);
      await resetToken('token-d');
      await PushService.instance.register(8);

      expect(sendCalls, 2);
    });
  });
}
