import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Display names for message senders, resolved once and remembered.
///
/// A TDLib message identifies its sender only as `{userId}` or `{chatId}`, and
/// the same handful of senders repeats down a whole group history — so the
/// lookup is memoised rather than repeated per bubble.
abstract final class SenderNames {
  static final Map<String, String> _cache = {};

  /// A cache key that keeps users and chats from colliding.
  static String? _keyOf(dynamic senderId) {
    if (senderId is! Map) return null;
    return switch (senderId['@type']) {
      'MessageSenderUser' => 'u${senderId['userId']}',
      'MessageSenderChat' => 'c${senderId['chatId']}',
      _ => null,
    };
  }

  /// The name if it is already known, without touching the network.
  ///
  /// Safe to call from `build`; returns null when a resolve is still needed.
  static String? cached(dynamic senderId) {
    final key = _keyOf(senderId);
    if (key == null) return null;
    final known = _cache[key];
    if (known != null) return known;

    // The chat store may already hold the sender from an earlier update.
    final store = ChatStore.instance;
    final fallback = key.startsWith('u')
        ? store.userName(senderId['userId'] as int)
        : store.chat(senderId['chatId'] as int)?['title'] as String?;
    if (fallback != null) _cache[key] = fallback;
    return fallback;
  }

  /// The sender's name, fetching it from TDLib when it isn't cached yet.
  static Future<String?> resolve(dynamic senderId) async {
    final key = _keyOf(senderId);
    if (key == null) return null;

    final known = cached(senderId);
    if (known != null) return known;

    String? name;
    if (senderId['@type'] == 'MessageSenderUser') {
      final user = await TDLibClient.getUser(
        userId: senderId['userId'] as int,
      );
      if (user != null) {
        name = [user['firstName'], user['lastName']]
            .whereType<String>()
            .where((part) => part.isNotEmpty)
            .join(' ');
      }
    } else {
      final chat = await TDLibClient.getChat(
        chatId: senderId['chatId'] as int,
      );
      name = chat?['title'] as String?;
    }

    if (name == null || name.isEmpty) return null;
    _cache[key] = name;
    return name;
  }
}

/// A label for where a forwarded message came from, or null when the message
/// wasn't forwarded.
///
/// TDLib describes the source as a `MessageOrigin`, which is a different shape
/// per source kind (a user, an anonymous admin, a group, a channel post).
String? forwardOriginName(Map<String, dynamic> message) {
  final origin = message['forwardInfo']?['origin'];
  if (origin == null) return null;

  switch (origin['@type']) {
    case 'MessageOriginUser':
      return SenderNames.cached({
            '@type': 'MessageSenderUser',
            'userId': origin['senderUserId'],
          }) ??
          'a user';
    case 'MessageOriginHiddenUser':
      return origin['senderName'] as String? ?? 'a user';
    case 'MessageOriginChat':
      return SenderNames.cached({
            '@type': 'MessageSenderChat',
            'chatId': origin['senderChatId'],
          }) ??
          origin['authorSignature'] as String? ??
          'a chat';
    case 'MessageOriginChannel':
      return SenderNames.cached({
            '@type': 'MessageSenderChat',
            'chatId': origin['chatId'],
          }) ??
          'a channel';
    default:
      return null;
  }
}
