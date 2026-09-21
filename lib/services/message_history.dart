import 'package:flutter/foundation.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Where a [MessageHistoryController] gets its messages.
///
/// A chat and a message thread page identically but call different TDLib
/// functions and accept different messages from the update stream, so the
/// difference lives here rather than in branches inside the controller.
abstract class HistorySource {
  /// The chat the messages live in.
  ///
  /// For a channel post's comments this is the linked discussion supergroup,
  /// not the channel.
  int get chatId;

  /// One page, newest first. May return fewer than [limit] messages even when
  /// more history exists, which is why callers page in a loop.
  Future<List<Map<String, dynamic>>> load({
    required int fromMessageId,
    required int offset,
    required int limit,
    required bool onlyLocal,
  });

  /// Whether a message carried by `updateNewMessage` belongs to this feed.
  bool owns(Map<String, dynamic> message);
}

/// The history of a whole chat.
class ChatHistorySource implements HistorySource {
  const ChatHistorySource(this.chatId);

  @override
  final int chatId;

  @override
  Future<List<Map<String, dynamic>>> load({
    required int fromMessageId,
    required int offset,
    required int limit,
    required bool onlyLocal,
  }) async {
    final result = await TDLibClient.getChatHistory(
      chatId: chatId,
      fromMessageId: fromMessageId,
      offset: offset,
      limit: limit,
      onlyLocal: onlyLocal,
    );
    return result?.messages ?? const [];
  }

  @override
  bool owns(Map<String, dynamic> message) => message['chatId'] == chatId;
}

/// The history of one message thread inside [chatId].
class ThreadHistorySource implements HistorySource {
  const ThreadHistorySource({
    required this.chatId,
    required this.messageThreadId,
  });

  @override
  final int chatId;

  /// The thread's root message id *within [chatId]*, which is
  /// `messageThreadInfo.messageThreadId`.
  final int messageThreadId;

  @override
  Future<List<Map<String, dynamic>>> load({
    required int fromMessageId,
    required int offset,
    required int limit,
    required bool onlyLocal,
  }) async {
    // getMessageThreadHistory has no local-only mode; answering a local pass
    // with the network would double every initial load, so it stays empty and
    // the page falls through to loadMore.
    if (onlyLocal) return const [];

    final result = await TDLibClient.getMessageThreadHistory(
      chatId: chatId,
      messageId: messageThreadId,
      fromMessageId: fromMessageId,
      offset: offset,
      limit: limit,
    );
    return result?.messages ?? const [];
  }

  @override
  bool owns(Map<String, dynamic> message) =>
      message['chatId'] == chatId &&
      message['messageThreadId'] == messageThreadId;
}

/// A paged, live-updating message list.
///
/// Owns everything about *which* messages are shown — paging, de-duplication,
/// album grouping and applying TDLib's message updates — and nothing about how
/// they look. Pages listen to it and render [messages].
class MessageHistoryController extends ChangeNotifier {
  MessageHistoryController({required this.source, this.batchSize = 100});

  final HistorySource source;

  /// Messages asked for per page. TDLib caps this at 100 and usually returns
  /// fewer.
  final int batchSize;

  List<Map<String, dynamic>> _messages = const [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _disposed = false;

  /// The visible entries, newest first. An album is one entry holding its
  /// members under `messages`.
  List<Map<String, dynamic>> get messages => _messages;

  bool get isLoading => _isLoading;

  /// Whether older history is still worth asking for.
  bool get hasMore => _hasMore;

  /// Fills the list from TDLib's local cache, looping because a page comes
  /// back short even when more is cached.
  Future<void> loadLocal() async {
    try {
      while (true) {
        _setLoading(true);
        final page = await source.load(
          fromMessageId: _oldestId(),
          offset: 0,
          limit: batchSize,
          onlyLocal: true,
        );
        if (_disposed) return;

        final fresh = _withoutDuplicates(page);
        if (fresh.isEmpty) break;
        _messages = AlbumsGrouper.groupMediaAlbums([..._messages, ...fresh]);
        _emit();
      }
    } catch (e, stackTrace) {
      logger.e('Failed to load local history',
          error: e, stackTrace: stackTrace);
    }
    _setLoading(false);
  }

  /// Appends one page of older history.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _setLoading(true);

    final page = await source.load(
      fromMessageId: _oldestId(),
      offset: 0,
      limit: batchSize,
      onlyLocal: false,
    );
    if (_disposed) return;

    if (page.isEmpty) {
      _hasMore = false;
      _setLoading(false);
      return;
    }

    final fresh = _withoutDuplicates(page);
    if (fresh.isNotEmpty) {
      _messages = AlbumsGrouper.groupMediaAlbums([..._messages, ...fresh]);
    }
    _setLoading(false);
  }

  /// Reloads the history as a window centred on [messageId].
  ///
  /// Replaces the list rather than scrolling it: the target may be far older
  /// than anything loaded, and a lazy list cannot scroll to what it has not
  /// got.
  Future<void> loadWindowAround(int messageId) async {
    _setLoading(true);

    final page = await source.load(
      fromMessageId: messageId,
      offset: -25,
      limit: 50,
      onlyLocal: false,
    );
    if (_disposed) return;

    _messages = AlbumsGrouper.groupMediaAlbums([...page]);
    _hasMore = true;
    _setLoading(false);
  }

  /// Applies one message update.
  ///
  /// Returns the message a `updateNewMessage` actually added, so the page can
  /// react to it (scroll, mark as read) without repeating the ownership and
  /// duplicate checks; returns null for every other update.
  Map<String, dynamic>? applyUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case updateNewMessageConst:
        final message = update['message'] as Map<String, dynamic>;
        if (!source.owns(message)) return null;
        if (contains(message['id'] as int)) return null;
        _messages = AlbumsGrouper.groupMediaAlbums([message, ..._messages]);
        _emit();
        return message;

      case updateMessageSendSucceededConst:
      case updateMessageSendFailedConst:
        final message = update['message'] as Map<String, dynamic>;
        if (!source.owns(message)) return null;
        // A sent message gets a brand new server-side id; swap the temporary
        // entry out or the list keeps a ghost no update can reach.
        patch(update['oldMessageId'] as int, (_) => message);

      case updateDeleteMessagesConst:
        if (update['chatId'] != source.chatId) return null;
        final deleted =
            (update['messageIds'] as List?)?.cast<int>().toSet() ??
                const <int>{};
        if (deleted.isEmpty) return null;
        _messages = [
          for (final entry in _messages)
            if (entry['isAlbum'] == true)
              {
                ...entry,
                'messages': <Map<String, dynamic>>[
                  for (final member in AlbumsGrouper.membersOf(entry))
                    if (!deleted.contains(member['id'])) member,
                ],
              }
            else if (!deleted.contains(entry['id']))
              entry,
        ].where((entry) {
          if (entry['isAlbum'] != true) return true;
          return (entry['messages'] as List).isNotEmpty;
        }).toList();
        _emit();

      case updateMessageInteractionInfoConst:
        if (update['chatId'] != source.chatId) return null;
        patch(
          update['messageId'] as int,
          (message) => {
            ...message,
            'interactionInfo': update['interactionInfo'],
          },
        );

      case updateMessageContentConst:
        if (update['chatId'] != source.chatId) return null;
        patch(
          update['messageId'] as int,
          (message) => {...message, 'content': update['newContent']},
        );

      case updateMessageEditedConst:
        if (update['chatId'] != source.chatId) return null;
        patch(
          update['messageId'] as int,
          (message) => {...message, 'editDate': update['editDate']},
        );

      case updateMessageIsPinnedConst:
        if (update['chatId'] != source.chatId) return null;
        patch(
          update['messageId'] as int,
          (message) => {...message, 'isPinned': update['isPinned']},
        );
    }
    return null;
  }

  /// Empties the list, for when the history itself was deleted.
  void clear() {
    if (_messages.isEmpty) return;
    _messages = const [];
    _emit();
  }

  /// Whether a message is already shown, counting album members.
  bool contains(int messageId) {
    for (final entry in _messages) {
      if (entry['isAlbum'] == true) {
        if (AlbumsGrouper.membersOf(entry).any((m) => m['id'] == messageId)) {
          return true;
        }
      } else if (entry['id'] == messageId) {
        return true;
      }
    }
    return false;
  }

  /// Applies [transform] to the message with [messageId], whether it stands
  /// alone or sits inside an album.
  void patch(
    int messageId,
    Map<String, dynamic> Function(Map<String, dynamic> message) transform,
  ) {
    var changed = false;
    final updated = _messages.map((entry) {
      if (entry['isAlbum'] == true) {
        final members = AlbumsGrouper.membersOf(entry);
        final index = members.indexWhere((m) => m['id'] == messageId);
        if (index == -1) return entry;
        members[index] = transform(members[index]);
        changed = true;
        return {...entry, 'messages': members};
      }
      if (entry['id'] == messageId) {
        changed = true;
        return transform(entry);
      }
      return entry;
    }).toList();

    if (!changed) return;
    _messages = updated;
    _emit();
  }

  /// The id to page from: the oldest entry held, or 0 for a first page.
  int _oldestId() => _messages.isEmpty ? 0 : _messages.last['id'] as int;

  List<Map<String, dynamic>> _withoutDuplicates(
    List<Map<String, dynamic>> incoming,
  ) =>
      incoming.where((m) => !contains(m['id'] as int)).toList();

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
