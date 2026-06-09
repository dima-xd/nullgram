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
        await HapticFeedback.heavyImpact();
        _hasError.value = true;
        _codeController.clear();
        if (!mounted) return;
        showAuthError(context, 'That code is invalid. Please try again.');
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
      _hasError.value = true;
      if (!mounted) return;
      showAuthError(context, 'Could not verify the code. Please try again.');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _resendCode() async {
    try {
      await TDLibClient.resendAuthenticationCode();
      _startResendCountdown(widget.timeout ?? 60);
      if (!mounted) return;
      showAuthInfo(context, 'Code sent again');
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Could not resend the code. Please try again.');
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
          ListenableBuilder(
            listenable: Listenable.merge([_isLoading, _codeController]),
            builder: (context, _) {
              final complete =
                  _codeController.text.trim().length == _codeLength;
              return AuthPrimaryButton(
                label: 'Verify',
                loading: _isLoading.value,
                onPressed: complete ? _verifyCode : null,
              );
            },
          ),
          const SizedBox(height: 16),
          _buildResend(theme),
        ],
      ),
    );
  }

  void _onCodeChanged(String value) {
    if (_hasError.value) _hasError.value = false;
    if (value.length == _codeLength) {
      HapticFeedback.selectionClick();
      _verifyCode();
    }
  }

  Widget _buildCodeField(ThemeData theme) => ValueListenableBuilder<bool>(
        valueListenable: _hasError,
        builder: (context, error, _) => _OtpField(
          controller: _codeController,
          length: _codeLength,
          hasError: error,
          onChanged: _onCodeChanged,
        ),
      );

  Widget _buildResend(ThemeData theme) => ValueListenableBuilder<int>(
        valueListenable: _secondsLeft,
        builder: (context, seconds, _) => seconds > 0
            ? Text(
                'Resend code in ${seconds}s',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
            : TextButton(
                onPressed: _resendCode,
                child: const Text('Resend code'),
              ),
      );
}

/// Segmented one-time-code input rendering [length] cells backed by a single
/// hidden [TextField].
///
/// The active cell is outlined in [ColorScheme.primary]; when [hasError] is
/// set every cell is tinted with [ColorScheme.error]. All editing flows through
/// [controller] and [onChanged], so auto-submit and error-clearing behave
/// exactly like a plain text field.
class _OtpField extends StatefulWidget {
  const _OtpField({
    required this.controller,
    required this.length,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int length;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<_OtpField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Visual cells. They react to controller and focus changes.
        AnimatedBuilder(
          animation: Listenable.merge([widget.controller, _focusNode]),
          builder: (context, _) => _OtpCells(
            value: widget.controller.text,
            length: widget.length,
            hasError: widget.hasError,
            hasFocus: _focusNode.hasFocus,
          ),
        ),
        // Hidden input that owns the editing logic; tapping the cells focuses
        // it and opens the keyboard.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              maxLength: widget.length,
              style: theme.textTheme.headlineMedium,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// The row of digit boxes drawn for the [_OtpField].
class _OtpCells extends StatelessWidget {
  const _OtpCells({
    required this.value,
    required this.length,
    required this.hasError,
    required this.hasFocus,
  });

  final String value;
  final int length;
  final bool hasError;
  final bool hasFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeIndex = value.length.clamp(0, length - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final filled = index < value.length;
        final isActive = hasFocus && index == activeIndex && !hasError;
        final Color borderColor;
        if (hasError) {
          borderColor = scheme.error;
        } else if (isActive) {
          borderColor = scheme.primary;
        } else {
          borderColor = scheme.outlineVariant;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: isActive || hasError ? 2 : 1,
              ),
            ),
            child: Text(
              filled ? value[index] : '',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: hasError ? scheme.error : scheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }
}
