import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrLoginPage extends StatefulWidget {
  const QrLoginPage({super.key});

  @override
  State<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends State<QrLoginPage> {
  final qrLink = ValueNotifier<String?>(null);

  StreamSubscription? _authSubscription;

  @override
  void initState() {
    _requestQrCode();

    super.initState();

    _authSubscription = TDLibClient.authStateUpdates.listen((state) {
      if (state['@type'] == 'AuthorizationStateWaitOtherDeviceConfirmation') {
        if (mounted) {
          setState(() {
            qrLink.value = state['link'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _requestQrCode() async {
    await TDLibClient.requestQrCodeAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('QR Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ValueListenableBuilder<String?>(
            valueListenable: qrLink,
            builder: (context, link, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: link == null
                  ? Column(
                key: const ValueKey('loading'),
                children: const [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 12),
                  Text('Loading QR code...'),
                ],
              )
                  : Column(
                key: const ValueKey('qr'),
                children: [
                  Text(
                    'Scan this QR code with any Telegram client on your phone',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 250,
                      gapless: false,
                      backgroundColor: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
