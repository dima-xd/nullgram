import 'package:flutter/material.dart';
import 'package:nullgram/services/passcode_service.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The local lock over the app: set, change or remove the passcode, choose
/// when it re-engages, and allow biometrics.
class PasscodePage extends StatelessWidget {
  const PasscodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PasscodeService.instance;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.passcodeLock)),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, child) => ListView(
          padding: withBottomSafeArea(
            context,
            const EdgeInsets.only(bottom: 24),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.passcodeExplanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(context.l10n.passcodeLock),
              value: service.isEnabled,
              onChanged: (enable) => enable
                  ? _setPasscode(context)
                  : _confirmDisable(context),
            ),
            if (service.isEnabled) ...[
              ListTile(
                leading: const Icon(Icons.password),
                title: Text(context.l10n.changePasscode),
                onTap: () => _setPasscode(context),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(context.l10n.lockTheApp),
                subtitle: Text(_timeoutLabel(context, service.timeout)),
                onTap: () => _pickTimeout(context),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(context.l10n.unlockWithBiometrics),
                subtitle: Text(context.l10n.biometricsHint),
                value: service.isBiometricEnabled,
                onChanged: (value) => _setBiometrics(context, value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setPasscode(BuildContext context) async {
    final passcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _PasscodeSheet(),
    );
    if (passcode == null) return;
    await PasscodeService.instance.setPasscode(passcode);
  }

  Future<void> _confirmDisable(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.turnOffPasscodeQuestion),
        content: Text(
          context.l10n.passcodeDisableWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.turnOff),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PasscodeService.instance.disable();
  }

  Future<void> _pickTimeout(BuildContext context) async {
    final service = PasscodeService.instance;
    final timeout = await showModalBottomSheet<PasscodeTimeout>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<PasscodeTimeout>(
          groupValue: service.timeout,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in PasscodeTimeout.values)
                RadioListTile<PasscodeTimeout>(
                  value: option,
                  title: Text(_timeoutLabel(sheetContext, option)),
                ),
            ],
          ),
        ),
      ),
    );
    if (timeout == null) return;
    await service.setTimeout(timeout);
  }

  Future<void> _setBiometrics(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.noBiometricsEnrolled;
    final applied = await PasscodeService.instance.setBiometricEnabled(value);
    if (applied) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// How a lock delay reads in the settings list.
String _timeoutLabel(BuildContext context, PasscodeTimeout timeout) =>
    switch (timeout) {
      PasscodeTimeout.immediately => context.l10n.lockImmediately,
      PasscodeTimeout.oneMinute => context.l10n.lockAfterOneMinute,
      PasscodeTimeout.fiveMinutes => context.l10n.lockAfterFiveMinutes,
      PasscodeTimeout.oneHour => context.l10n.lockAfterOneHour,
    };

/// Collects a new passcode twice over, resolving to it or to null on cancel.
class _PasscodeSheet extends StatefulWidget {
  const _PasscodeSheet();

  @override
  State<_PasscodeSheet> createState() => _PasscodeSheetState();
}

class _PasscodeSheetState extends State<_PasscodeSheet> {
  /// Short enough to type one-handed, long enough not to be a coin flip.
  static const int _minLength = 4;

  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _first.text.length >= _minLength && _first.text == _second.text;

  /// The reason the passcode is not acceptable yet, or null when it is.
  String? get _mismatch {
    if (_second.text.isEmpty) return null;
    return _first.text == _second.text
        ? null
        : context.l10n.codesDoNotMatch;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetBottomPadding(context),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            context.l10n.setAPasscode,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _first,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.passcode,
              helperText: context.l10n.passcodeMinLengthHint,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _second,
            obscureText: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.repeatThePasscode,
              errorText: _mismatch,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isValid ? _submit : null,
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.pop(context, _first.text);
  }
}
