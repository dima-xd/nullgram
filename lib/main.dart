import 'dart:async';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:nullgram/app_credentials.dart';
import 'package:nullgram/app_info.dart';
import 'package:nullgram/theme/app_theme.dart';
import 'package:nullgram/pages/auth/code_input_page.dart';
import 'package:nullgram/pages/auth/login_page.dart';
import 'package:nullgram/pages/auth/password_input_page.dart';
import 'package:nullgram/pages/auth/registration_page.dart';
import 'package:nullgram/pages/home/home_page.dart';
import 'package:nullgram/services/account_manager.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/services/auto_download.dart';
import 'package:nullgram/services/language_service.dart';
import 'package:nullgram/pages/passcode/passcode_lock_screen.dart';
import 'package:nullgram/services/passcode_service.dart';
import 'package:nullgram/services/notification_service.dart';
import 'package:nullgram/services/call_service.dart';
import 'package:nullgram/pages/call/call_overlay.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/tdlib/tdlib_helper.dart';
import 'package:path_provider/path_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App-wide theme mode, toggled from the settings screen. Defaults to following
/// the system setting.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.system);

/// Whether the dark theme collapses surfaces to true black (OLED). Toggled from
/// settings; only affects the dark theme.
final ValueNotifier<bool> amoledNotifier = ValueNotifier(false);

String? _currentAuthState;
int? _currentAuthAccount;

/// Whether [LoginPage] is currently the root of the navigation stack. Used to
/// decide whether forward auth screens (code, password) can simply be pushed
/// on top of it, preserving the back stack.
bool _isLoginRoot = false;

void _postFrame(VoidCallback callback) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());

/// Replaces the entire stack with [page]. Used for reset/terminal states.
void _resetTo(Widget page) {
  _isLoginRoot = page is LoginPage;
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => page),
    (_) => false,
  );
}

/// Pushes [page] on top of the current stack so the user can go back.
///
/// When the pushed route is popped (the user navigates back), the cached auth
/// state is reset to [resetStateOnPop] so a repeat of the same TDLib state
/// re-triggers navigation instead of being swallowed by the de-dupe guard.
void _pushAuth(Widget page, {required String resetStateOnPop}) {
  navigatorKey.currentState
      ?.push(MaterialPageRoute(builder: (_) => page))
      .then((_) => _currentAuthState = resetStateOnPop);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  TDLibClient.initTdlibUpdates();

  callService = buildCallService();

  // Started here and awaited below: it only needs to be listening before the
  // first client comes online, and its plugin setup can run while the three
  // platform lookups the accounts need are in flight.
  final notifications = NotificationService.instance.init();

  TDLibClient.authStateUpdates.listen((state) {
    final authType = state['@type'];
    final accountId = state['@accountId'] as int?;

    // While a switch is in flight both accounts report states — the one being
    // left behind may even report `WaitPhoneNumber` after signing out — and
    // acting on either would flash the wrong screen. The account that wins
    // replays its state once the switch settles.
    if (AccountManager.instance.isSwitching) return;

    // The account is part of the identity of a state: the same `Ready` from a
    // different account is a different event and must navigate again.
    if (_currentAuthState == authType && _currentAuthAccount == accountId) {
      return;
    }
    _currentAuthState = authType;
    _currentAuthAccount = accountId;

    switch (authType) {
      case 'AuthorizationStateClosed':
      case 'AuthorizationStateLoggingOut':
        // Drop the signed-in user's chats so the next account never sees
        // them, even briefly.
        ChatStore.instance.reset();
      case 'AuthorizationStateWaitPhoneNumber':
        _postFrame(() => _resetTo(const LoginPage()));
      case 'AuthorizationStateWaitOtherDeviceConfirmation':
        // QR is shown in-page by LoginPage. Only navigate if the app started
        // directly in this state without a LoginPage to host it.
        if (!_isLoginRoot) {
          _postFrame(
            () => _resetTo(const LoginPage(initialMode: AuthMode.qr)),
          );
        }
      case 'AuthorizationStateWaitCode':
        _postFrame(() {
          final codeInfo = state['codeInfo'] as Map<String, dynamic>?;
          final page = CodeInputPage(
            phoneNumber: codeInfo?['phoneNumber'] as String?,
            timeout: (codeInfo?['timeout'] as num?)?.toInt(),
          );
          if (!_isLoginRoot) _resetTo(const LoginPage());
          _pushAuth(
            page,
            resetStateOnPop: 'AuthorizationStateWaitPhoneNumber',
          );
        });
      case 'AuthorizationStateWaitRegistration':
        _postFrame(() => _pushAuth(
              RegistrationPage(
                termsOfService:
                    state['termsOfService'] as Map<String, dynamic>?,
              ),
              resetStateOnPop: 'AuthorizationStateWaitCode',
            ));
      case 'AuthorizationStateWaitPassword':
        _postFrame(() => _pushAuth(
              PasswordInputPage(passwordHint: state['passwordHint'] ?? ''),
              resetStateOnPop: 'AuthorizationStateWaitCode',
            ));
      case 'AuthorizationStateReady':
        NotificationService.instance.start();
        ChatStore.instance.start();
        _postFrame(() {
          _resetTo(const HomePage());
          NotificationService.instance.requestPermission();
        });
    }
  });

  // Three independent platform round trips that everything below waits on, so
  // they are made at once rather than one after another.
  final (credentials, androidInfo, appDir) = await (
    AppCredentials.resolve(),
    DeviceInfoPlugin().androidInfo,
    getApplicationDocumentsDirectory(),
  ).wait;

  await notifications;

  await AccountManager.instance.init(
    documentsPath: appDir.path,
    config: (
      databaseEncryptionKey: credentials.databaseEncryptionKey.codeUnits,
      apiId: credentials.apiId,
      apiHash: credentials.apiHash,
      systemLanguageCode: PlatformDispatcher.instance.locale.languageCode,
      deviceModel: androidInfo.model,
      systemVersion: androidInfo.version.release,
      applicationVersion: appVersion,
    ),
  );

  // Both read preferences, neither depends on the other, and the passcode has
  // to be known before the first frame so a locked app never flashes its
  // contents.
  await (restoreLocale(), PasscodeService.instance.init()).wait;

  runApp(MyApp());

  // Left until after the first frame is on its way: it reports the network
  // type and mirrors the download limits to the server, and nothing on screen
  // waits for either. It does need the TDLib parameters, which are in place by
  // now.
  unawaited(AutoDownloadService.instance.init());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Created once so hot reload (which re-runs build) doesn't restart the
  // future, drop FutureBuilder back to its loading state, and rebuild a fresh
  // HomePage that loses all in-memory chats.
  late final Future<bool> _authorized = TDLibHelper.isAuthorized();

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, themeMode, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: amoledNotifier,
              builder: (context, amoled, _) {
                return ValueListenableBuilder<Locale?>(
                  valueListenable: localeNotifier,
                  builder: (context, locale, _) => MaterialApp(
                    navigatorKey: navigatorKey,
                    builder: (context, child) => PasscodeGate(
                      child: CallOverlay(child: child!),
                    ),
                    debugShowCheckedModeBanner: false,
                    themeMode: themeMode,
                    theme: buildLightTheme(lightDynamic),
                    darkTheme: buildDarkTheme(darkDynamic, amoled: amoled),
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: FutureBuilder<bool>(
                      future: _authorized,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return snapshot.data!
                            ? const HomePage()
                            : const Scaffold(
                                body: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
