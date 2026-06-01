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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
          AuthInputContainer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _obscure,
              builder: (context, obscure, _) => TextField(
                controller: _passwordController,
                obscureText: obscure,
                autofocus: true,
                decoration: authInputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                ).copyWith(
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
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: _isSubmitting,
            builder: (context, submitting, _) => AuthPrimaryButton(
              label: 'Submit',
              loading: submitting,
              onPressed: _submitPassword,
            ),
          ),
        ],
      ),
    );
  }
}
