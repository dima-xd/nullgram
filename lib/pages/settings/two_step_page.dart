import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Two-step verification: the password asked for when signing in on a new
/// device, on top of the SMS code.
class TwoStepPage extends StatefulWidget {
  const TwoStepPage({super.key});

  @override
  State<TwoStepPage> createState() => _TwoStepPageState();
}

class _TwoStepPageState extends State<TwoStepPage> {
  final ValueNotifier<Map<String, dynamic>?> _state = ValueNotifier(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _state.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = await TDLibClient.getPasswordState();
    if (!mounted) return;
    _state.value = state;
    _isLoading.value = false;
  }

  bool get _hasPassword => _state.value?['hasPassword'] == true;

  Future<void> _setOrChange() async {
    final result = await showModalBottomSheet<_PasswordForm>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PasswordSheet(
        requiresOldPassword: _hasPassword,
        hint: _state.value?['passwordHint'] as String? ?? '',
      ),
    );
    if (result == null) return;

    final updated = await TDLibClient.setPassword(
      oldPassword: result.oldPassword,
      newPassword: result.newPassword,
      newHint: result.hint,
    );
    if (!mounted) return;

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not change the password. Check the old one.'),
        ),
      );
      return;
    }
    _state.value = updated;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.newPassword.isEmpty
              ? 'Two-step verification disabled'
              : 'Password updated',
        ),
      ),
    );
  }

  Future<void> _disable() async {
    final scheme = Theme.of(context).colorScheme;
    final oldPassword = await showModalBottomSheet<_PasswordForm>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PasswordSheet(
        requiresOldPassword: true,
        hint: _state.value?['passwordHint'] as String? ?? '',
        // A removal only needs the current password; the new one stays empty,
        // which is how TDLib expresses "turn this off".
        isRemoval: true,
      ),
    );
    if (oldPassword == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off two-step verification?'),
        content: const Text(
          'Your account will be protected by the login code alone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = await TDLibClient.setPassword(
      oldPassword: oldPassword.oldPassword,
    );
    if (!mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That password was not accepted.')),
      );
      return;
    }
    _state.value = updated;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-step verification')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _state,
            builder: (context, state, child) {
              if (state == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Two-step verification is unavailable right now.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final hasPassword = state['hasPassword'] == true;
              final hint = state['passwordHint'] as String? ?? '';

              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      hasPassword
                          ? 'A password is required when you sign in on a new '
                              'device, in addition to the login code.'
                          : 'Add a password that is asked for whenever you '
                              'sign in on a new device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      hasPassword ? Icons.lock : Icons.lock_open,
                      color: hasPassword
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(hasPassword ? 'Password is on' : 'Password is off'),
                    subtitle: hasPassword && hint.isNotEmpty
                        ? Text('Hint: $hint')
                        : null,
                  ),
                  if (state['hasRecoveryEmailAddress'] == true)
                    const ListTile(
                      leading: Icon(Icons.mail_outline),
                      title: Text('Recovery email is set'),
                    ),
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton(
                      onPressed: _setOrChange,
                      child: Text(
                        hasPassword ? 'Change password' : 'Set password',
                      ),
                    ),
                  ),
                  if (hasPassword)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextButton(
                        onPressed: _disable,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Turn off two-step verification'),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// What the password sheet collected.
typedef _PasswordForm = ({
  String oldPassword,
  String newPassword,
  String hint,
});

/// Collects the current and/or new password.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({
    required this.requiresOldPassword,
    required this.hint,
    this.isRemoval = false,
  });

  final bool requiresOldPassword;
  final String hint;

  /// When set, only the current password is asked for.
  final bool isRemoval;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final TextEditingController _old = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _hint = TextEditingController();

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _hint.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (widget.requiresOldPassword && _old.text.isEmpty) return false;
    if (widget.isRemoval) return true;
    return _new.text.length >= 4;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            widget.isRemoval ? 'Confirm your password' : 'Two-step password',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (widget.requiresOldPassword) ...[
            TextField(
              controller: _old,
              obscureText: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Current password',
                helperText: widget.hint.isEmpty ? null : 'Hint: ${widget.hint}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!widget.isRemoval) ...[
            TextField(
              controller: _new,
              obscureText: true,
              autofocus: !widget.requiresOldPassword,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 4 characters',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hint,
              decoration: const InputDecoration(
                labelText: 'Hint (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _isValid
                ? () => Navigator.pop(context, (
                      oldPassword: _old.text,
                      newPassword: _new.text,
                      hint: _hint.text.trim(),
                    ))
                : null,
            child: Text(widget.isRemoval ? 'Continue' : 'Save'),
          ),
        ],
      ),
    );
  }
}
