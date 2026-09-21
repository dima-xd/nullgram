import 'package:nullgram/tdlib/tdlib_client.dart';

/// One GIF an inline bot offered, addressed by the query it came from.
class GifResult {
  const GifResult({
    required this.queryId,
    required this.resultId,
    required this.animation,
  });

  final int queryId;
  final String resultId;

  /// The TDLib `animation`, whose thumbnail the grid draws.
  final Map<String, dynamic> animation;
}

/// Searches GIFs through the inline bot Telegram names in the
/// `animation_search_bot_username` option.
class GifSearch {
  GifSearch._();

  static int? _botUserId;

  static Future<int?> _bot() async {
    if (_botUserId != null) return _botUserId;
    final username =
        await TDLibClient.getStringOption('animation_search_bot_username');
    if (username == null || username.isEmpty) return null;

    final chat = await TDLibClient.searchPublicChat(username: username);
    final type = chat?['type'] as Map<String, dynamic>?;
    if (type?['@type'] != 'ChatTypePrivate') return null;
    _botUserId = type?['userId'] as int?;
    return _botUserId;
  }

  static Future<List<GifResult>> search({
    required int chatId,
    required String query,
  }) async {
    final botUserId = await _bot();
    if (botUserId == null) return const [];

    final results = await TDLibClient.getInlineQueryResults(
      botUserId: botUserId,
      chatId: chatId,
      query: query,
    );
    final queryId = (results?['inlineQueryId'] as num?)?.toInt();
    if (queryId == null) return const [];

    return [
      for (final result in results?['results'] as List? ?? const [])
        if (result is Map && result['animation'] is Map)
          GifResult(
            queryId: queryId,
            resultId: result['id'] as String? ?? '',
            animation: Map<String, dynamic>.from(result['animation'] as Map),
          ),
    ];
  }
}
