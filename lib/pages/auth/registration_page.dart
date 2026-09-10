import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/message_text.dart';

import '../../tdlib/tdlib_client.dart';
import 'widgets/auth_widgets.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Sign-up screen for a phone number that has no Telegram account yet.
///
/// TDLib asks for this by entering `AuthorizationStateWaitRegistration` right
/// after the login code is accepted. Without this screen the number is stuck:
/// there is no other way to answer that state.
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, this.termsOfService});

  /// The `termsOfService` object TDLib attached to the state, if any.
  ///
  /// Carries the text to display, a `minUserAge` and a `showPopup` flag that
  /// asks for an explicit confirmation dialog.
  final Map<String, dynamic>? termsOfService;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _isSubmitting = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _isSubmitting.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _terms => widget.termsOfService;

  int get _minUserAge => (_terms?['minUserAge'] as num?)?.toInt() ?? 0;

  /// Whether TDLib wants the terms confirmed in a dialog rather than just
  /// shown on the page.
  bool get _needsPopup => _terms?['showPopup'] == true || _minUserAge > 0;

  Future<void> _submit() async {
    final firstName = _firstName.text.trim();
    if (firstName.isEmpty) return;
    if (_needsPopup && !await _confirmTerms()) return;

    _isSubmitting.value = true;
    try {
      await TDLibClient.registerUser(
        firstName: firstName,
        lastName: _lastName.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Could not create the account. Try again.');
    } finally {
      _isSubmitting.value = false;
    }
  }

  Future<bool> _confirmTerms() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.termsOfService),
        content: Text(
          _minUserAge > 0
              ? 'You must be at least $_minUserAge years old to use '
                    'Telegram. Do you accept the Terms of Service?'
              : 'Do you accept the Terms of Service?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.decline),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.accept),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthHeader(
            title: context.l10n.createYourAccount,
            subtitle: context.l10n.registrationSubtitle,
            icon: Icons.person_add_alt,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _firstName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: context.l10n.firstName,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: context.l10n.lastNameOptional,
              prefixIcon: Icon(Icons.person_outline),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: Listenable.merge([_isSubmitting, _firstName]),
            builder: (context, _) => AuthPrimaryButton(
              label: context.l10n.signUp,
              loading: _isSubmitting.value,
              onPressed: _firstName.text.trim().isEmpty ? null : _submit,
            ),
          ),
          if (_terms?['text'] case final Map<String, dynamic> text) ...[
            const SizedBox(height: 24),
            _TermsBlock(text: text),
          ],
        ],
      ),
    );
  }
}

/// The Terms of Service, rendered with their links and formatting intact.
class _TermsBlock extends StatelessWidget {
  const _TermsBlock({required this.text});

  final Map<String, dynamic> text;

  @override
  Widget build(BuildContext context) {
    return AuthInputContainer(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        // The terms run long; a scroll area keeps them from pushing the
        // sign-up button off the page.
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(child: MessageText(content: text)),
      ),
    );
  }
}
