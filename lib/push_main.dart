import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:nullgram/services/account_manager.dart';
import 'package:nullgram/services/language_service.dart';
import 'package:nullgram/services/notification_service.dart';
import 'package:nullgram/services/push_service.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

// A production filter, or a release build logs nothing at all and a push that
// renders no notification leaves no trace in logcat.
final _log = Logger(filter: ProductionFilter());

const MethodChannel _channel = MethodChannel('nullgram_push');

/// How long one push may take, bring-up included, before it is given up on:
/// Android gives a background isolate about thirty seconds.
const Duration _budget = Duration(seconds: 25);

/// Pushes are handled one at a time: a burst would otherwise bring the same
/// client up twice and race over one database.
Future<void> _queue = Future.value();

/// The entrypoint of the headless engine the push service starts, where
/// nothing of the app exists: no UI, no stores, no account on screen.
@pragma('vm:entry-point')
Future<void> pushMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  _log.i('Push isolate started');

  // Without this the notification renders in the system language rather than
  // the one the user picked, which only the app process has in memory.
  await restoreLocale();
  await NotificationService.instance.init();

  _channel.setMethodCallHandler((call) async {
    // The refresh reaches this engine whenever no app engine is ready, and
    // dropping it would leave every account registered under a dead token.
    if (call.method == 'onToken') {
      PushService.instance.acceptToken(call.arguments as String?);
      return null;
    }
    if (call.method != 'onPush') return null;
    final arguments = (call.arguments as Map).cast<String, dynamic>();
    // Captured before the field moves on: awaiting the field itself would
    // hold this call until every later push had been handled too.
    final handled = _queue = _queue
        .then((_) => _onPush(
              payload: arguments['payload'] as String? ?? '',
              receiverId: (arguments['receiverId'] as num?)?.toInt() ?? 0,
            ))
        // Absorbed rather than propagated: a rejected future here would be
        // chained onto, and would drop every later push of this engine.
        .catchError((Object e, StackTrace s) {
      _log.e('Failed to handle a push', error: e, stackTrace: s);
    });
    await handled;
    return null;
  });

  // Tells the native side the entrypoint is up, which releases any payload
  // that arrived while the engine was still starting.
  await _channel.invokeMethod('ready');
}

/// One push, start to finish.
Future<void> _onPush({
  required String payload,
  required int receiverId,
}) async {
  if (payload.isEmpty) return;

  // Zero means the push is addressed to every client rather than to one
  // account, which is how Telegram announces account-independent events.
  final accounts = receiverId == 0
      ? await PushService.instance.registeredAccounts()
      : [await PushService.instance.accountForReceiver(receiverId)]
          .whereType<int>()
          .toList();

  if (accounts.isEmpty) {
    _log.w(receiverId == 0
        ? 'Push for every client, but no account is registered'
        : 'Push for unknown receiver $receiverId');
    return;
  }

  for (final accountId in accounts) {
    _log.i('Processing a push for account $accountId');
    try {
      // Both under one timeout: a hung bring-up would otherwise burn the whole
      // allowance Android gives this isolate with nothing to stop it.
      await Future(() async {
        await bringAccountOnline(accountId);
        // Returns only once TDLib has sent every notification update it
        // produced, so the notification is already on screen by then.
        await TDLibClient.processPushNotification(
          payload: payload,
          accountId: accountId,
        );
      }).timeout(_budget);
    } catch (e, s) {
      _log.e('Failed to process a push', error: e, stackTrace: s);
    }
  }
}
