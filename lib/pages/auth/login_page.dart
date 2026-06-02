import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'widgets/auth_widgets.dart';
import 'widgets/country_picker.dart';

/// Which sign-in method the [LoginPage] is currently showing.
enum AuthMode { phone, qr }

/// Entry point of the authentication flow.
///
/// Hosts both the phone-number form and the QR-code view in a single screen so
/// the user can move freely between them. QR is intentionally not a separate
/// navigation route: tapping back from QR simply toggles the local mode rather
/// than popping, which is what makes returning to the phone form possible.
class LoginPage extends StatefulWidget {
  const LoginPage({this.initialMode = AuthMode.phone, super.key});

  /// The mode to start in. [AuthMode.qr] is used when the app launches while
  /// TDLib is already awaiting QR confirmation.
  final AuthMode initialMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _isLoading = ValueNotifier<bool>(false);
  final _qrLink = ValueNotifier<String?>(null);
  late final ValueNotifier<AuthMode> _mode;
  late final ValueNotifier<Country> _country;
  StreamSubscription<Map<String, dynamic>>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _mode = ValueNotifier<AuthMode>(widget.initialMode);
    _country = ValueNotifier<Country>(defaultCountry);

    _authSubscription = TDLibClient.authStateUpdates.listen((state) {
      if (state['@type'] == 'AuthorizationStateWaitOtherDeviceConfirmation') {
        _qrLink.value = state['link'] as String?;
      }
    });

    if (widget.initialMode == AuthMode.qr) {
      TDLibClient.requestQrCodeAuthentication();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _phoneController.dispose();
    _isLoading.dispose();
    _qrLink.dispose();
    _mode.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    _isLoading.value = true;
    try {
      await TDLibClient.setAuthenticationPhoneNumber(
        phoneNumber: '${_country.value.dialCode}$digits',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void _switchToQr() {
    _qrLink.value = null;
    _mode.value = AuthMode.qr;
    TDLibClient.requestQrCodeAuthentication();
  }

  void _switchToPhone() => _mode.value = AuthMode.phone;

  Future<void> _pickCountry() async {
    final selected = await showCountryPicker(context);
    if (selected != null) _country.value = selected;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<AuthMode>(
      valueListenable: _mode,
      builder: (context, mode, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: mode == AuthMode.qr
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _switchToPhone,
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: mode == AuthMode.phone
                      ? _buildPhoneView(theme)
                      : _buildQrView(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneView(ThemeData theme) => Column(
        key: const ValueKey('phone'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            title: 'Welcome to Nullgram',
            subtitle: 'Enter your phone number to continue',
          ),
          const SizedBox(height: 32),
          _buildPhoneInput(theme),
          const SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) => AuthPrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward,
              loading: loading,
              onPressed: _sendCode,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _switchToQr,
            icon: const Icon(Icons.qr_code_rounded),
            label: const Text('Log in by QR Code'),
          ),
        ],
      );

  Widget _buildPhoneInput(ThemeData theme) => AuthInputContainer(
        child: Row(
          children: [
            ValueListenableBuilder<Country>(
              valueListenable: _country,
              builder: (context, country, _) => InkWell(
                onTap: _pickCountry,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 6),
                      Text(
                        country.dialCode,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 28, color: theme.dividerColor),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: authInputDecoration(hintText: 'Phone number'),
                onSubmitted: (_) => _sendCode(),
              ),
            ),
          ],
        ),
      );

  Widget _buildQrView(ThemeData theme) => Column(
        key: const ValueKey('qr'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthHeader(
            title: 'Log in by QR Code',
            subtitle: 'Open Telegram on your phone, go to '
                'Settings › Devices › Link Desktop Device, and scan this code.',
            icon: Icons.qr_code_rounded,
          ),
          const SizedBox(height: 32),
          ValueListenableBuilder<String?>(
            valueListenable: _qrLink,
            builder: (context, link, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: link == null
                  ? const _QrPlaceholder()
                  : _QrCode(link: link),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _switchToPhone,
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Log in by phone number'),
          ),
        ],
      );
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
        key: ValueKey('qr-loading'),
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text('Generating QR code...'),
        ],
      );
}

class _QrCode extends StatelessWidget {
  const _QrCode({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    // Always render on a light surface: inverted QR codes are unreliable to
    // scan, so the card stays white regardless of the app theme.
    return Container(
      key: const ValueKey('qr-code'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QrImageView(
        data: link,
        version: QrVersions.auto,
        size: 240,
        backgroundColor: Colors.white,
      ),
    );
  }
}
