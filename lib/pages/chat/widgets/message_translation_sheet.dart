import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/pages/chat/widgets/message_text.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/widgets/safe_insets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nullgram/l10n/l10n.dart';

/// The languages offered as translation targets.
///
/// TDLib accepts any two-letter code, but a free-text field for a language
/// code is not a usable control; this is the short list Telegram itself
/// puts first, plus the device's own language.
const Map<String, String> translationLanguages = {
  'en': 'English',
  'ru': 'Русский',
  'uk': 'Українська',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'pl': 'Polski',
  'tr': 'Türkçe',
  'ar': 'العربية',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
};

/// Where the chosen target language is remembered between messages.
const String _targetPreferenceKey = 'translate.target';

/// Shows [messageId] translated, with a picker for the target language.
Future<void> showMessageTranslationSheet(
  BuildContext context, {
  required int chatId,
  required int messageId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _TranslationSheet(
      chatId: chatId,
      messageId: messageId,
    ),
  );
}

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({required this.chatId, required this.messageId});

  final int chatId;
  final int messageId;

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  final ValueNotifier<Map<String, dynamic>?> _translated = ValueNotifier(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<String?> _error = ValueNotifier(null);

  late String _target = _deviceLanguage;

  /// The device's language when it is one this sheet offers, English
  /// otherwise — translating into a language with no entry would leave the
  /// picker showing nothing.
  static String get _deviceLanguage {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return translationLanguages.containsKey(code) ? code : 'en';
  }

  @override
  void initState() {
    super.initState();
    _restoreTargetAndTranslate();
  }

  @override
  void dispose() {
    _translated.dispose();
    _isLoading.dispose();
    _error.dispose();
    super.dispose();
  }

  Future<void> _restoreTargetAndTranslate() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_targetPreferenceKey);
    if (stored != null && translationLanguages.containsKey(stored)) {
      _target = stored;
    }
    await _translate();
  }

  Future<void> _translate() async {
    _isLoading.value = true;
    _error.value = null;

    final text = await TDLibClient.translateMessageText(
      chatId: widget.chatId,
      messageId: widget.messageId,
      toLanguageCode: _target,
    );
    if (!mounted) return;

    _isLoading.value = false;
    if (text == null) {
      _error.value = 'Telegram could not translate this message.';
      return;
    }
    _translated.value = text;
  }

  Future<void> _changeTarget(String target) async {
    setState(() => _target = target);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_targetPreferenceKey, target);
    await _translate();
  }

  void _copy() {
    final text = _translated.value?['text'] as String?;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetBottomPadding(context),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.translation,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              DropdownButton<String>(
                value: _target,
                underline: const SizedBox.shrink(),
                onChanged: (value) =>
                    value == null ? null : _changeTarget(value),
                items: [
                  for (final entry in translationLanguages.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildResult(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return ListenableBuilder(
      listenable: Listenable.merge([_isLoading, _error, _translated]),
      builder: (context, child) {
        if (_isLoading.value) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_error.value case final String message) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(message, textAlign: TextAlign.center),
          );
        }
        final text = _translated.value;
        if (text == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: MessageText(content: text),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: Text(context.l10n.copyTranslation),
            ),
          ],
        );
      },
    );
  }
}
