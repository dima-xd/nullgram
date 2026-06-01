import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/auth/code_input_page.dart';
import 'package:nullgram/pages/auth/login_page.dart';
import 'package:nullgram/pages/auth/password_input_page.dart';
import 'package:nullgram/pages/home/home_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/tdlib/tdlib_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? _currentAuthState;

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

  await dotenv.load(fileName: ".env");

  TDLibClient.initTdlibUpdates();

  TDLibClient.authStateUpdates.listen((state) {
    final authType = state['@type'];

    if (_currentAuthState == authType) return;
    _currentAuthState = authType;

    switch (authType) {
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
      case 'AuthorizationStateWaitPassword':
        _postFrame(() => _pushAuth(
              PasswordInputPage(passwordHint: state['passwordHint'] ?? ''),
              resetStateOnPop: 'AuthorizationStateWaitCode',
            ));
      case 'AuthorizationStateReady':
        _postFrame(() => _resetTo(const HomePage()));
    }
  });

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  final appDir = await getApplicationDocumentsDirectory();

  await TDLibClient.setTdlibParameters(
    useTestDc: false,
    databaseDirectory: appDir.path,
    filesDirectory: appDir.path,
    databaseEncryptionKey: dotenv.env["DB_ENCRYPTION_KEY"]!.codeUnits,
    useFileDatabase: true,
    useChatInfoDatabase: true,
    useMessageDatabase: true,
    useSecretChats: true,
    apiId: int.parse(dotenv.env["API_ID"]!),
    apiHash: dotenv.env["API_HASH"]!,
    systemLanguageCode: PlatformDispatcher.instance.locale.languageCode,
    deviceModel: androidInfo.model,
    systemVersion: '',
    // TODO: Replace with actual app version
    applicationVersion: '0.1',
  );

  runApp(MyApp());
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _authorized,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data! ? HomePage() : Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
