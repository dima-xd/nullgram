import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/chat_page.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Opens a link the way Telegram does: `t.me` links, usernames and invite
/// links stay inside the app; anything else is handed to the system.
///
/// Sending a `t.me` link to the browser would bounce the user out of the app
/// and, for an invite link, out of the join flow entirely.
Future<void> openLink(BuildContext context, String target) async {
  final handled = await _openInApp(context, target);
  if (handled) return;

  final uri = _resolveExternal(target);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Opens a `@username` mention.
Future<void> openUsername(BuildContext context, String mention) async {
  final username = mention.startsWith('@') ? mention.substring(1) : mention;
  if (username.isEmpty) return;
  await _openPublicChat(context, username);
}

/// Tries to handle [target] internally, returning whether it did.
Future<bool> _openInApp(BuildContext context, String target) async {
  final path = _telegramPath(target);
  if (path == null) return false;

  // Invite links: `t.me/+hash` and the older `t.me/joinchat/hash`.
  if (path.startsWith('+') || path.startsWith('joinchat/')) {
    await _joinByInviteLink(context, target);
    return true;
  }

  // A bare `t.me/username`, possibly followed by a message id we ignore.
  final username = path.split('/').first;
  if (username.isEmpty) return false;
  return _openPublicChat(context, username);
}

/// The path part of a Telegram link, or null when [target] isn't one.
String? _telegramPath(String target) {
  final uri = Uri.tryParse(
    target.startsWith('http') || target.startsWith('tg:')
        ? target
        : 'https://$target',
  );
  if (uri == null) return null;

  if (uri.scheme == 'tg') {
    // tg://resolve?domain=username
    return uri.queryParameters['domain'];
  }
  const hosts = {'t.me', 'telegram.me', 'telegram.dog'};
  if (!hosts.contains(uri.host.toLowerCase())) return null;
  return uri.path.replaceFirst(RegExp(r'^/'), '');
}

/// Resolves a username to its chat and opens it. Returns false when no such
/// public chat exists, so the caller can fall back to the browser.
Future<bool> _openPublicChat(BuildContext context, String username) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final notFound = context.l10n.usernameNotFound(username);

  final chat = await TDLibClient.searchPublicChat(username: username);
  if (chat == null || chat['id'] == null) {
    messenger.showSnackBar(SnackBar(content: Text(notFound)));
    return false;
  }

  navigator.push(
    MaterialPageRoute(
      builder: (context) =>
          ChatPage(chat: ChatStore.instance.chat(chat['id'] as int) ?? chat),
    ),
  );
  return true;
}

/// Previews an invite link, asks for confirmation, then joins.
Future<void> _joinByInviteLink(BuildContext context, String link) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // Read up front, next to the messenger: every use below is past an await.
  final l10n = context.l10n;

  final info = await TDLibClient.checkChatInviteLink(link: link);
  if (info == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.inviteLinkInvalid)));
    return;
  }

  // An already-joined chat has a chat id; open it instead of re-joining.
  final existingChatId = info['chatId'] as int?;
  if (existingChatId != null && existingChatId != 0) {
    final chat = ChatStore.instance.chat(existingChatId) ??
        await TDLibClient.getChat(chatId: existingChatId);
    if (chat != null) {
      navigator.push(
        MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
      );
    }
    return;
  }

  if (!context.mounted) return;
  final title = info['title'] as String? ?? 'this chat';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.joinChatQuestion(title)),
      content: Text('${info['memberCount'] ?? 0} members'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.join),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final joined = await TDLibClient.joinChatByInviteLink(link: link);
  if (joined == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.joinFailed)));
    return;
  }
  navigator.push(
    MaterialPageRoute(builder: (context) => ChatPage(chat: joined)),
  );
}

/// Turns a raw link entity into a launchable [Uri], adding the right scheme
/// for bare URLs, emails and phone numbers.
Uri? _resolveExternal(String target) {
  if (target.contains('@') && !target.contains('/')) {
    return Uri(scheme: 'mailto', path: target);
  }
  if (RegExp(r'^\+?[\d\s\-()]+$').hasMatch(target)) {
    return Uri(scheme: 'tel', path: target.replaceAll(RegExp(r'\s'), ''));
  }
  if (target.startsWith('http://') || target.startsWith('https://')) {
    return Uri.tryParse(target);
  }
  return Uri.tryParse('https://$target');
}
