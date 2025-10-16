import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/auth/code_input_page.dart';
import 'package:nullgram/pages/auth/password_input_page.dart';
import 'package:nullgram/pages/auth/phone_input_page.dart';
import 'package:nullgram/pages/auth/qr_login_page.dart';
import 'package:nullgram/pages/home/home_page.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/tdlib/tdlib_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String? _currentAuthState;

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PhoneInputPage(),
            ),
                (_) => false,
          );
        });
      case 'AuthorizationStateWaitPassword':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PasswordInputPage(passwordHint: state['passwordHint']),
            ),
                (_) => false,
          );
        });
      case 'AuthorizationStateReady':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomePage(),
            ),
                (_) => false,
          );
        });
      case 'AuthorizationStateWaitCode':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => CodeInputPage(),
            ),
                (_) => false,
          );
        });
      case 'AuthorizationStateWaitOtherDeviceConfirmation':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => QrLoginPage(),
            ),
                (_) => false,
          );
        });
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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: TDLibHelper.isAuthorized(),
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
