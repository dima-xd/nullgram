import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/services/link_resolver.dart';
import 'package:nullgram/tdlib/td_bytes.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/l10n/l10n.dart';

/// A bot message's inline keyboard, rendered under its bubble.
///
/// Without this, bot conversations are unusable: the buttons carry the whole
/// interaction and a message that only says "choose an option" has nothing to
/// choose from.
class MessageKeyboard extends StatelessWidget {
  const MessageKeyboard({
    super.key,
    required this.replyMarkup,
    required this.chatId,
    required this.messageId,
  });

  /// The message's `replyMarkup`.
  final Map<String, dynamic> replyMarkup;

  final int chatId;
  final int messageId;

  @override
  Widget build(BuildContext context) {
    // Only inline keyboards attach to a message. A `replyMarkupShowKeyboard`
    // asks to replace the composer's keyboard instead, which this client
    // doesn't offer, so it is left unrendered rather than drawn as dead
    // buttons.
    if (replyMarkup['@type'] != 'ReplyMarkupInlineKeyboard') {
      return const SizedBox.shrink();
    }

    final rows = replyMarkup['rows'] as List? ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final button in (row as List))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _KeyboardButton(
                          button: button as Map<String, dynamic>,
                          chatId: chatId,
                          messageId: messageId,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({
    required this.button,
    required this.chatId,
    required this.messageId,
  });

  final Map<String, dynamic> button;
  final int chatId;
  final int messageId;

  @override
  Widget build(BuildContext context) {
    final type = button['type'] as Map<String, dynamic>?;

    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _press(context, type),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon(type) case final icon?) ...[
            Icon(icon, size: 15),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              button['text'] as String? ?? '',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// A hint about what the button does, matching Telegram's own glyphs.
  IconData? _icon(Map<String, dynamic>? type) => switch (type?['@type']) {
        'InlineKeyboardButtonTypeUrl' ||
        'InlineKeyboardButtonTypeLoginUrl' =>
          Icons.open_in_new,
        'InlineKeyboardButtonTypeWebApp' => Icons.web_asset,
        'InlineKeyboardButtonTypeCopyText' => Icons.copy,
        'InlineKeyboardButtonTypeSwitchInline' => Icons.search,
        'InlineKeyboardButtonTypeBuy' => Icons.shopping_cart_outlined,
        _ => null,
      };

  Future<void> _press(
    BuildContext context,
    Map<String, dynamic>? type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    switch (type?['@type']) {
      case 'InlineKeyboardButtonTypeUrl':
      case 'InlineKeyboardButtonTypeLoginUrl':
      case 'InlineKeyboardButtonTypeWebApp':
        final url = type?['url'] as String?;
        if (url != null) await openLink(context, url);

      case 'InlineKeyboardButtonTypeCopyText':
        final text = type?['text'] as String?;
        if (text == null) return;
        await Clipboard.setData(ClipboardData(text: text));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.copiedToClipboard)),
        );

      case 'InlineKeyboardButtonTypeUser':
        final userId = type?['userId'] as int?;
        if (userId == null) return;
        final chat = await TDLibClient.createPrivateChat(userId: userId);
        if (chat == null || !context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
        );

      case 'InlineKeyboardButtonTypeCallback':
        await _answerCallback(messenger, type);

      default:
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.buttonNotSupported)),
        );
    }
  }

  /// Presses a callback button and surfaces whatever the bot replies with.
  ///
  /// A bot usually answers with a short toast; `showAlert` asks for something
  /// more prominent, which a longer-lived snack bar stands in for.
  Future<void> _answerCallback(
    ScaffoldMessengerState messenger,
    Map<String, dynamic>? type,
  ) async {
    final data = TdBytes.decode(type?['data']);
    if (data == null) return;

    final answer = await TDLibClient.getCallbackQueryAnswer(
      chatId: chatId,
      messageId: messageId,
      data: data,
    );

    final text = answer?['text'] as String?;
    if (text == null || text.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: answer?['showAlert'] == true
            ? const Duration(seconds: 6)
            : const Duration(seconds: 3),
      ),
    );
  }
}
