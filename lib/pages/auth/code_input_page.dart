import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

import 'widgets/auth_widgets.dart';

/// Screen for entering the login code sent to the user's phone.
class CodeInputPage extends StatefulWidget {
  const CodeInputPage({this.phoneNumber, this.timeout, super.key});

  /// The phone number the code was sent to, shown for confirmation.
  final String? phoneNumber;

  /// Seconds to wait before the code can be resent, from TDLib's `codeInfo`.
  final int? timeout;

  @override
  State<CodeInputPage> createState() => _CodeInputPageState();
}

class _CodeInputPageState extends State<CodeInputPage> {
  static const _codeLength = 5;

  final _isLoading = ValueNotifier<bool>(false);
  final _hasError = ValueNotifier<bool>(false);
  final _secondsLeft = ValueNotifier<int>(0);
  final _codeController = TextEditingController();
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(widget.timeout ?? 60);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _isLoading.dispose();
    _hasError.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    _secondsLeft.value = seconds;
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft.value <= 1) {
        _secondsLeft.value = 0;
        timer.cancel();
      } else {
        _secondsLeft.value -= 1;
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < _codeLength) return;

    _isLoading.value = true;
    _hasError.value = false;
    try {
      final result = await TDLibClient.checkAuthenticationCode(code: code);
      if (result == 'PHONE_CODE_INVALID') {
        _hasError.value = true;
        _codeController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _hasError.value = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _resendCode() async {
    try {
      await TDLibClient.resendAuthenticationCode();
      _startResendCountdown(widget.timeout ?? 60);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code sent again')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = widget.phoneNumber != null
        ? 'We sent a code to ${widget.phoneNumber}'
        : 'Enter the code we just sent you';

    return AuthScaffold(
      showBackButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthHeader(
            title: 'Enter the code',
            subtitle: subtitle,
            icon: Icons.sms_outlined,
          ),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Wrong number?'),
          ),
          const SizedBox(height: 16),
          _buildCodeField(theme),
          const SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) => AuthPrimaryButton(
              label: 'Verify',
              loading: loading,
              onPressed: _verifyCode,
            ),
          ),
          const SizedBox(height: 16),
          _buildResend(theme),
        ],
      ),
    );
  }

  Widget _buildCodeField(ThemeData theme) => ValueListenableBuilder<bool>(
        valueListenable: _hasError,
        builder: (context, error, _) => AuthInputContainer(
          hasError: error,
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            maxLength: _codeLength,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              color: error ? theme.colorScheme.error : null,
            ),
            decoration: authInputDecoration(
              hintText: '• • • • •',
              counterText: '',
            ),
            onChanged: (value) {
              if (_hasError.value) _hasError.value = false;
              if (value.length == _codeLength) _verifyCode();
            },
          ),
        ),
      );

  Widget _buildResend(ThemeData theme) => ValueListenableBuilder<int>(
        valueListenable: _secondsLeft,
        builder: (context, seconds, _) => seconds > 0
            ? Text(
                'Resend code in ${seconds}s',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
            : TextButton(
                onPressed: _resendCode,
                child: const Text('Resend code'),
              ),
      );
}
