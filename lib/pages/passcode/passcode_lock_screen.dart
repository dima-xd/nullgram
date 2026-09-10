import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/services/passcode_service.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The screen that stands between a locked app and its contents.
///
/// Deliberately offers no way out other than the passcode: no back button, no
/// dismissal. Chat content must never be visible behind it, so it is opaque.
class PasscodeLockScreen extends StatefulWidget {
  const PasscodeLockScreen({super.key});

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  final TextEditingController _passcode = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _isChecking = ValueNotifier(false);
  final ValueNotifier<bool> _wasWrong = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  @override
  void dispose() {
    _passcode.dispose();
    _focusNode.dispose();
    _isChecking.dispose();
    _wasWrong.dispose();
    super.dispose();
  }

  /// Offers the fingerprint prompt as soon as the lock appears, so the common
  /// case needs no typing at all.
  Future<void> _tryBiometrics() async {
    final service = PasscodeService.instance;
    if (!service.isBiometricEnabled) {
      _focusNode.requestFocus();
      return;
    }
    final unlocked = await service.unlockWithBiometrics(
      reason: context.l10n.unlockPrompt,
    );
    if (!unlocked && mounted) _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final passcode = _passcode.text;
    if (passcode.isEmpty || _isChecking.value) return;

    _isChecking.value = true;
    final unlocked = await PasscodeService.instance.unlockWithPasscode(
      passcode,
    );
    if (!mounted) return;

    _isChecking.value = false;
    if (unlocked) return;

    _wasWrong.value = true;
    _passcode.clear();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.appLocked,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildField(),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField() {
    return ValueListenableBuilder<bool>(
      valueListenable: _wasWrong,
      builder: (context, wasWrong, child) => TextField(
        controller: _passcode,
        focusNode: _focusNode,
        obscureText: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (_) => _wasWrong.value = false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: context.l10n.passcode,
          errorText: wasWrong ? 'Wrong passcode' : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return ListenableBuilder(
      listenable: Listenable.merge([_isChecking, _passcode]),
      builder: (context, child) => Column(
        children: [
          FilledButton(
            onPressed: _passcode.text.isEmpty || _isChecking.value
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isChecking.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(context.l10n.unlock),
          ),
          if (PasscodeService.instance.isBiometricEnabled) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _tryBiometrics,
              icon: const Icon(Icons.fingerprint),
              label: Text(context.l10n.useBiometrics),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps the app and covers it whenever the passcode is engaged.
///
/// Also drives the timeout: it is the only widget that reliably sees the app
/// leave and come back.
class PasscodeGate extends StatefulWidget {
  const PasscodeGate({super.key, required this.child});

  final Widget child;

  @override
  State<PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends State<PasscodeGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = PasscodeService.instance;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        service.onBackgrounded();
      case AppLifecycleState.resumed:
        service.onForegrounded();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PasscodeService.instance.isLocked,
      builder: (context, isLocked, child) => Stack(
        children: [
          // The app stays mounted underneath so unlocking returns to exactly
          // the screen that was open, rather than restarting.
          child!,
          if (isLocked) const Positioned.fill(child: PasscodeLockScreen()),
        ],
      ),
      child: widget.child,
    );
  }
}
