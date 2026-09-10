import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nullgram/services/account_manager.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'widgets/auth_widgets.dart';
import 'widgets/country_picker.dart';
import 'package:nullgram/l10n/l10n.dart';

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
    final String? error;
    try {
      error = await TDLibClient.setAuthenticationPhoneNumber(
        phoneNumber: '${_country.value.dialCode}$digits',
      );
    } finally {
      _isLoading.value = false;
    }
    if (error != null && mounted) showAuthError(context, _reason(error));
  }

  /// Turns a TDLib error code into something a person can act on.
  ///
  /// The codes that matter here are not obvious, and neither is retryable:
  /// `VERIFICATION_FAILED` means Telegram demanded a Play Integrity or
  /// reCAPTCHA token, which it only asks of official application credentials
  /// and only accepts from the official app, while `API_ID_PUBLISHED_FLOOD`
  /// means it recognized the credentials as publicly known. Both are answered
  /// by an `api_id` of your own.
  String _reason(String error) => switch (error) {
        'PHONE_NUMBER_INVALID' => context.l10n.phoneNumberInvalid,
        'VERIFICATION_FAILED' => context.l10n.appVerificationFailed,
        'API_ID_PUBLISHED_FLOOD' => context.l10n.apiIdPublishedFlood,
        _ => context.l10n.signInFailed(error),
      };

  Future<void> _switchToQr() async {
    _qrLink.value = null;
    _mode.value = AuthMode.qr;
    final error = await TDLibClient.requestQrCodeAuthentication();
    // Without this the QR view would spin forever: the link only ever arrives
    // as an authorization state, and a refused request produces none.
    if (error != null && mounted) showAuthError(context, _reason(error));
  }

  void _switchToPhone() => _mode.value = AuthMode.phone;

  Future<void> _pickCountry() async {
    final selected =
        await showCountryPicker(context, selected: _country.value);
    if (selected != null) _country.value = selected;
  }

  /// The bar above the login form, present only when there is somewhere to go
  /// back to: the phone form of a newly added account can be abandoned, and
  /// the QR form falls back to the phone form.
  PreferredSizeWidget? _appBar(AuthMode mode) {
    final leading = switch (mode) {
      AuthMode.qr => BackButton(onPressed: _switchToPhone),
      AuthMode.phone when AccountManager.instance.canCancelPendingAccount =>
        CloseButton(onPressed: AccountManager.instance.cancelPendingAccount),
      AuthMode.phone => null,
    };
    if (leading == null) return null;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<AuthMode>(
      valueListenable: _mode,
      builder: (context, mode, _) => Scaffold(
        appBar: _appBar(mode),
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
          AuthHeader(
            title: context.l10n.welcomeToNullgram,
            subtitle: context.l10n.enterPhoneToContinue,
          ),
          const SizedBox(height: 32),
          _buildPhoneInput(theme),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: Listenable.merge([_isLoading, _phoneController]),
            builder: (context, _) {
              final hasDigits =
                  _phoneController.text.replaceAll(RegExp(r'\D'), '').isNotEmpty;
              return AuthPrimaryButton(
                label: context.l10n.continueLabel,
                icon: Icons.arrow_forward,
                loading: _isLoading.value,
                onPressed: hasDigits ? _sendCode : null,
              );
            },
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _switchToQr,
            icon: const Icon(Icons.qr_code_rounded),
            label: Text(context.l10n.loginByQrCode),
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
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flag, style: theme.textTheme.titleLarge),
                      const SizedBox(width: 6),
                      Text(country.dialCode, style: theme.textTheme.titleMedium),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: authInputDecoration(hintText: context.l10n.phoneNumber),
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
          AuthHeader(
            title: context.l10n.loginByQrCode,
            subtitle: context.l10n.qrInstructions,
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
            label: Text(context.l10n.loginByPhone),
          ),
        ],
      );
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) => Column(
        key: ValueKey('qr-loading'),
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(context.l10n.generatingQrCode),
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
