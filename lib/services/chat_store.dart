import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nullgram/services/avatar_cache.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// Which TDLib chat list a view is showing.
enum ChatListKind {
  /// The default list.
  main,

  /// The archive.
  archive;

  /// The `@type` the bridge reports for this list inside a chat position.
  ///
  /// The native bridge PascalCases response types, so positions carry
  /// `ChatListMain` rather than the `chatListMain` used in requests.
  String get responseType =>
      this == ChatListKind.archive ? 'ChatListArchive' : 'ChatListMain';
}

/// The live, in-memory chat list.
///
/// TDLib pushes chats and their mutations as a stream of updates rather than
/// letting clients poll a list, so this store folds those updates into a map
/// keyed by chat id and notifies listeners. Every write replaces the map (and
/// any nested map it touches) with a new instance: mutating in place would let
/// a rebuild read half-applied state, and would not notify at all when the
/// container identity is unchanged.
///
/// One store is shared by every chat-list view — the main list, each folder tab
/// and the archive — so a chat only ever exists once in memory.
class ChatStore extends ChangeNotifier {
  ChatStore._();

  /// The process-wide store.
  static final ChatStore instance = ChatStore._();

  final Map<int, Map<String, dynamic>> _chats = {};
  List<Map<String, dynamic>> _folders = const [];
  final Map<int, Map<String, dynamic>> _users = {};
  final Map<int, Map<String, dynamic>> _supergroups = {};

  bool _isLoading = true;
  bool _started = false;
  StreamSubscription<Map<String, dynamic>>? _chatSubscription;
  StreamSubscription<Map<String, dynamic>>? _fileSubscription;

  /// Every known chat, keyed by id.
  Map<int, Map<String, dynamic>> get chats => _chats;

  /// The user's chat folders, without the implicit "All chats" tab.
  List<Map<String, dynamic>> get folders => _folders;

  /// Whether the first full sync is still running.
  bool get isLoading => _isLoading;

  /// Starts folding updates into the store and kicks off the initial sync.
  /// Safe to call more than once; later calls are ignored.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _chatSubscription = TDLibClient.chatUpdates.listen(_onChatUpdate);
    _fileSubscription = TDLibClient.filesUpdates.listen(_onFileUpdate);

    await _syncLoadedChats();
    await _loadAll();
  }

  /// Pulls the chats TDLib already holds and merges them in.
  ///
  /// On a Dart hot restart the native session survives but will not re-push
  /// `updateNewChat`, so without this the list would come up empty.
  Future<void> _syncLoadedChats() async {
    final chatIds = [
      ...await TDLibClient.getChats(),
      ...await TDLibClient.getArchivedChats(),
    ];
    // Resolved concurrently: each `getChat` is a platform-channel round trip,
    // and doing hundreds of them in sequence visibly delays the first paint.
    final chats = await Future.wait(
      chatIds.map((chatId) => TDLibClient.getChat(chatId: chatId)),
    );

    for (final chat in chats) {
      if (chat == null) continue;
      _maybeDownloadPhoto(chat);
      _chats[chat['id'] as int] = chat;
    }
    notifyListeners();
  }

  /// Walks TDLib's paged chat lists until both are exhausted.
  Future<void> _loadAll() async {
    try {
      while (await TDLibClient.loadChats() == "Ok") {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      while (await TDLibClient.loadArchivedChats() == "Ok") {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      logger.e('Failed to load chats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Replaces the stored chat for [chatId] by applying [patch] to a copy of it.
  /// Does nothing when the chat isn't known yet.
  void _patchChat(
    int chatId,
    Map<String, dynamic> Function(Map<String, dynamic> chat) patch,
  ) {
    final existing = _chats[chatId];
    if (existing == null) return;
    _chats[chatId] = patch(existing);
    notifyListeners();
  }

  void _onChatUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case updateNewChatConst:
        final chat = Map<String, dynamic>.from(update['chat'] as Map);
        _maybeDownloadPhoto(chat);
        _chats[chat['id'] as int] = chat;
        notifyListeners();

      case updateChatFoldersConst:
        final raw = update['chatFolders'] as List? ?? const [];
        _folders = [
          for (final folder in raw)
            {
              'id': folder['id'],
              // The folder name is a nested formattedText; flatten it once so
              // views can read a plain string.
              'title': folder['name']?['text']?['text'] ?? 'Folder',
            },
        ];
        notifyListeners();

      case updateChatPositionConst:
        final position = update['position'] as Map<String, dynamic>?;
        if (position == null) return;
        _patchChat(update['chatId'] as int, (chat) {
          return {...chat, 'positions': _mergePosition(chat, position)};
        });

      case updateChatLastMessageConst:
        final incoming = (update['positions'] as List?)
                ?.map((p) => Map<String, dynamic>.from(p as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        _patchChat(update['chatId'] as int, (chat) {
          var positions = _positionsOf(chat);
          for (final position in incoming) {
            positions = _mergeInto(positions, position);
          }
          return {
            ...chat,
            'lastMessage': update['lastMessage'],
            'positions': positions,
          };
        });

      case updateChatReadInboxConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'unreadCount': update['unreadCount'] ?? 0,
              'lastReadInboxMessageId': update['lastReadInboxMessageId'],
            });

      case updateChatReadOutboxConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'lastReadOutboxMessageId': update['lastReadOutboxMessageId'],
            });

      case updateChatTitleConst:
        _patchChat(
          update['chatId'] as int,
          (chat) => {...chat, 'title': update['title']},
        );

      case updateChatPhotoConst:
        final photo = update['photo'];
        _patchChat(update['chatId'] as int, (chat) {
          final updated = {...chat, 'photo': photo};
          _maybeDownloadPhoto(updated);
          return updated;
        });

      case updateChatNotificationSettingsConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'notificationSettings': update['notificationSettings'],
            });

      case updateChatIsMarkedAsUnreadConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'isMarkedAsUnread': update['isMarkedAsUnread'],
            });

      case updateChatDraftMessageConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'draftMessage': update['draftMessage'],
            });

      case updateChatUnreadMentionCountConst:
        _patchChat(update['chatId'] as int, (chat) => {
              ...chat,
              'unreadMentionCount': update['unreadMentionCount'] ?? 0,
            });

      case updateChatPermissionsConst:
        _patchChat(
          update['chatId'] as int,
          (chat) => {...chat, 'permissions': update['permissions']},
        );

      case updateSupergroupConst:
        final supergroup = Map<String, dynamic>.from(
          update['supergroup'] as Map,
        );
        _supergroups[supergroup['id'] as int] = supergroup;

      case updateUserConst:
        final user = Map<String, dynamic>.from(update['user'] as Map);
        _users[user['id'] as int] = user;
        notifyListeners();

      case updateUserStatusConst:
        final userId = update['userId'] as int;
        final user = _users[userId];
        if (user == null) return;
        _users[userId] = {...user, 'status': update['status']};
        notifyListeners();
    }
  }

  /// Patches a freshly downloaded avatar file back into the chat that
  /// references it. Without this a chat keeps its empty initial path and the
  /// avatar only appears after a restart.
  void _onFileUpdate(Map<String, dynamic> update) {
    if (update['@type'] != updateFileConst) return;
    final file = update['file'] as Map<String, dynamic>?;
    final fileId = file?['id'] as int?;
    if (fileId == null || file?['local']?['isDownloadingCompleted'] != true) {
      return;
    }

    final path = file?['local']?['path'] as String?;
    if (path != null && path.isNotEmpty) AvatarCache.invalidate(path);

    var changed = false;
    for (final entry in _chats.entries.toList()) {
      final small = entry.value['photo']?['small'];
      if (small is Map && small['id'] == fileId) {
        final photo = Map<String, dynamic>.from(entry.value['photo'] as Map);
        photo['small'] = file;
        _chats[entry.key] = {...entry.value, 'photo': photo};
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _maybeDownloadPhoto(Map<String, dynamic> chat) {
    final small = chat['photo']?['small'];
    if (small is! Map) return;
    if (small['local']?['path'] != "" || small['remote']?['id'] == null) return;
    TDLibClient.downloadFile(fileId: small['id'] as int).catchError((_) {});
  }

  List<Map<String, dynamic>> _positionsOf(Map<String, dynamic> chat) => [
        for (final position in (chat['positions'] as List? ?? const []))
          Map<String, dynamic>.from(position as Map),
      ];

  List<Map<String, dynamic>> _mergePosition(
    Map<String, dynamic> chat,
    Map<String, dynamic> position,
  ) =>
      _mergeInto(_positionsOf(chat), position);

  /// Returns a new list with [position] replacing any existing entry for the
  /// same chat list. TDLib identifies a position solely by its list, so a
  /// position for a list already present is an update, not an addition.
  List<Map<String, dynamic>> _mergeInto(
    List<Map<String, dynamic>> positions,
    Map<String, dynamic> position,
  ) {
    final merged = [
      for (final existing in positions)
        if (!_sameList(existing, position)) existing,
    ];
    // An order of zero means the chat left that list; drop it rather than
    // keeping a position that sorts to the bottom forever.
    if (_orderOf(position) != 0) merged.add(position);
    return merged;
  }

  bool _sameList(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['list']?['@type'] == b['list']?['@type'] &&
      a['list']?['chatFolderId'] == b['list']?['chatFolderId'];

  /// A chat position's order. TDLib sends this int64 as a string in some
  /// builds, so parse defensively.
  static int _orderOf(Map<String, dynamic>? position) {
    final order = position?['order'];
    if (order is int) return order;
    if (order is num) return order.toInt();
    return int.tryParse(order?.toString() ?? '') ?? 0;
  }

  /// The position a chat holds in [kind] (optionally within [folderId]), or
  /// null when the chat isn't in that list at all.
  static Map<String, dynamic>? positionIn(
    Map<String, dynamic> chat,
    ChatListKind kind, {
    int? folderId,
  }) {
    for (final raw in (chat['positions'] as List? ?? const [])) {
      final position = raw as Map<String, dynamic>;
      final list = position['list'];
      if (folderId != null) {
        if (list?['@type'] == 'ChatListFolder' &&
            list?['chatFolderId'] == folderId) {
          return position;
        }
        continue;
      }
      if (list?['@type'] == kind.responseType) return position;
    }
    return null;
  }

  /// The chats of one list, ordered the way Telegram orders them: pinned chats
  /// first (by their pin order), then the rest by TDLib's position order.
  List<Map<String, dynamic>> visibleChats({
    required ChatListKind kind,
    int? folderId,
  }) {
    final visible = <(Map<String, dynamic>, Map<String, dynamic>)>[];
    for (final chat in _chats.values) {
      final position = positionIn(chat, kind, folderId: folderId);
      if (position == null) continue;
      visible.add((chat, position));
    }

    visible.sort((a, b) {
      final aPinned = a.$2['isPinned'] == true;
      final bPinned = b.$2['isPinned'] == true;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return _orderOf(b.$2).compareTo(_orderOf(a.$2));
    });

    return [for (final entry in visible) _withResolvedSender(entry.$1)];
  }

  /// Merges the cached user or supergroup behind a chat into it.
  ///
  /// A TDLib `chat` carries only a `type`, so views that need the peer's online
  /// status or a channel's member count would otherwise have to resolve it
  /// themselves on every rebuild.
  Map<String, dynamic> _withResolvedSender(Map<String, dynamic> chat) {
    final type = chat['type'];
    switch (type?['@type']) {
      case 'ChatTypePrivate':
      case 'ChatTypeSecret':
        final user = _users[type['userId']];
        return user == null ? chat : {...chat, 'user': user};
      case 'ChatTypeSupergroup':
        final supergroup = _supergroups[type['supergroupId']];
        return supergroup == null ? chat : {...chat, 'supergroup': supergroup};
      default:
        return chat;
    }
  }

  /// The cached user for [userId], or null when it hasn't been pushed yet.
  Map<String, dynamic>? user(int userId) => _users[userId];

  /// The display name of a cached user, or null when unknown.
  ///
  /// Only reads the cache: this is called from `build` methods (chat previews,
  /// sender labels) where an await is not an option.
  String? userName(int userId) {
    final user = _users[userId];
    if (user == null) return null;
    final name = [user['firstName'], user['lastName']]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    return name.isEmpty ? null : name;
  }

  /// The chat for [chatId] with its peer merged in, or null when unknown.
  Map<String, dynamic>? chat(int chatId) {
    final chat = _chats[chatId];
    return chat == null ? null : _withResolvedSender(chat);
  }

  /// The number of chats with something unread in [kind], optionally scoped to
  /// a folder. Muted chats still count, matching Telegram's tab badges.
  int unreadChatCount({required ChatListKind kind, int? folderId}) {
    var count = 0;
    for (final chat in _chats.values) {
      if (positionIn(chat, kind, folderId: folderId) == null) continue;
      final unread = chat['unreadCount'] as int? ?? 0;
      if (unread > 0 || chat['isMarkedAsUnread'] == true) count++;
    }
    return count;
  }

  /// Whether any chat currently sits in the archive.
  bool get hasArchivedChats => _chats.values
      .any((chat) => positionIn(chat, ChatListKind.archive) != null);

  /// Empties the store and stops folding updates.
  ///
  /// Called on sign-out: the store is a singleton that outlives the session, so
  /// without this the next account would briefly see the previous one's chats.
  void reset() {
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _fileSubscription?.cancel();
    _fileSubscription = null;
    _chats.clear();
    _users.clear();
    _supergroups.clear();
    _folders = const [];
    AvatarCache.clear();
    _isLoading = true;
    _started = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _fileSubscription?.cancel();
    super.dispose();
  }
}

/// Whether a chat is muted, i.e. its notifications are suppressed.
bool isChatMuted(Map<String, dynamic> chat) =>
    (chat['notificationSettings']?['muteFor'] as int? ?? 0) > 0;
