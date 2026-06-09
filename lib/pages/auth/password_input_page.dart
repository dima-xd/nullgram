import 'package:flutter/material.dart';

import '../../tdlib/tdlib_client.dart';
import 'widgets/auth_widgets.dart';

/// Two-factor authentication password screen.
class PasswordInputPage extends StatefulWidget {
  final String passwordHint;

  const PasswordInputPage({required this.passwordHint, super.key});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage> {
  final _passwordController = TextEditingController();
  final _isSubmitting = ValueNotifier<bool>(false);
  final _obscure = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _passwordController.dispose();
    _isSubmitting.dispose();
    _obscure.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    _isSubmitting.value = true;
    try {
      await TDLibClient.checkAuthenticationPassword(password: password);
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Incorrect password. Please try again.');
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.passwordHint.isNotEmpty
        ? 'Hint: ${widget.passwordHint}'
        : 'Your account is protected with a password';

    return AuthScaffold(
      showBackButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthHeader(
            title: 'Enter your password',
            subtitle: subtitle,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 32),
          ValueListenableBuilder<bool>(
            valueListenable: _obscure,
            builder: (context, obscure, _) => TextField(
              controller: _passwordController,
              obscureText: obscure,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => _obscure.value = !obscure,
                ),
              ),
              onSubmitted: (_) => _submitPassword(),
            ),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: Listenable.merge([_isSubmitting, _passwordController]),
            builder: (context, _) {
              final hasPassword = _passwordController.text.isNotEmpty;
              return AuthPrimaryButton(
                label: 'Submit',
                loading: _isSubmitting.value,
                onPressed: hasPassword ? _submitPassword : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
