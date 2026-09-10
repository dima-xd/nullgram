import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:nullgram/services/avatar_cache.dart';
import 'package:nullgram/services/custom_emoji_cache.dart';
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

  /// The lists returned by [visibleChats], kept until the next mutation.
  final Map<String, List<Map<String, dynamic>>> _visible = {};

  /// The counts returned by [unreadChatCount], kept until the next mutation.
  final Map<String, int> _unreadCounts = {};

  bool? _hasArchived;
  bool _notifyScheduled = false;

  /// Whether the chats on screen came back from a snapshot and still have to
  /// be checked against TDLib once the lists are loaded.
  bool _restoredFromSnapshot = false;

  /// Identifies which run of the store async work belongs to.
  ///
  /// A sync is a long chain of awaits and an account switch can land in the
  /// middle of it. Every step therefore checks that the generation it started
  /// in is still current: without that, chats fetched for the account being
  /// left are written into the store that now belongs to the account on
  /// screen, which is exactly how one account's chats turn up in another's
  /// list.
  int _generation = 0;

  /// The account whose chats the store currently describes.
  int _account = TDLibClient.defaultAccountId;

  /// Account pairs already reported by [_isForeign].
  final Set<String> _reportedLeaks = {};

  /// Chats put aside while another account is on screen, keyed by account.
  final Map<int, _AccountSnapshot> _snapshots = {};

  /// Every known chat, keyed by id.
  Map<int, Map<String, dynamic>> get chats => _chats;

  /// The user's chat folders, without the implicit "All chats" tab.
  List<Map<String, dynamic>> get folders => _folders;

  /// Whether the first full sync is still running.
  bool get isLoading => _isLoading;

  /// Drops the derived caches and asks for one notification.
  ///
  /// TDLib delivers updates one platform message at a time — thousands of
  /// them during a first sync — and every listener answers by recomputing a
  /// sorted list from the whole store. Collapsing a burst into a single
  /// notification per frame is what keeps that sync from starving the UI
  /// thread, and costs nothing: no listener can paint more often than that.
  void _notify() {
    _visible.clear();
    _unreadCounts.clear();
    _hasArchived = null;

    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
    // A post-frame callback only runs if a frame is coming, and an update that
    // arrives while the app is idle would otherwise sit unnoticed.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Starts folding updates into the store and kicks off the initial sync.
  /// Safe to call more than once; later calls are ignored.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _chatSubscription = TDLibClient.chatUpdates.listen(_onChatUpdate);
    _fileSubscription = TDLibClient.filesUpdates.listen(_onFileUpdate);

    // Both are pinned for the whole sync: every request names the account it
    // is for, rather than whichever one is active by the time it is sent, and
    // every result is dropped if the store has moved on since.
    final account = TDLibClient.activeAccountId;
    final generation = _generation;
    _account = account;

    _restoreSnapshot(account);
    await _syncLoadedChats(account, generation);
    if (generation != _generation) return;

    await _loadAll(account, generation);
    if (generation != _generation) return;

    if (_restoredFromSnapshot) await _pruneStaleChats(account, generation);
  }

  /// Drops chats that came back from a snapshot but are no longer in a list.
  ///
  /// While an account waits in the background its updates never reach this
  /// store, so a chat it left, deleted or archived meanwhile would otherwise
  /// stay on screen until the app restarts. Both lists are fully loaded by the
  /// time this runs, which is what makes "TDLib did not name it" mean "gone"
  /// rather than "not loaded yet".
  Future<void> _pruneStaleChats(int account, int generation) async {
    final confirmed = {
      ...await TDLibClient.getChats(
        limit: _confirmLimit,
        accountId: account,
      ),
      ...await TDLibClient.getArchivedChats(
        limit: _confirmLimit,
        accountId: account,
      ),
    };
    if (generation != _generation) return;
    // An empty answer is far more likely to be a failed request than an
    // account with no chats at all, and acting on it would empty the list.
    if (confirmed.isEmpty) return;

    final before = _chats.length;
    _chats.removeWhere((chatId, _) => !confirmed.contains(chatId));
    if (_chats.length != before) _notify();
  }

  /// Pulls the chats TDLib already holds and merges them in.
  ///
  /// On a Dart hot restart the native session survives but will not re-push
  /// `updateNewChat`, so without this the list would come up empty.
  Future<void> _syncLoadedChats(int account, int generation) async {
    final chatIds = [
      ...await TDLibClient.getChats(accountId: account),
      ...await TDLibClient.getArchivedChats(accountId: account),
    ];
    if (generation != _generation) return;

    // Each `getChat` is a platform-channel round trip, and TDLib hands the ids
    // back in list order, so the chats are resolved in batches: a batch is
    // painted as soon as it lands, which puts the top of the list on screen
    // while the tail is still arriving. Resolving all of them before the first
    // paint is what made a switch between accounts feel stuck.
    for (var start = 0; start < chatIds.length; start += _syncBatchSize) {
      final batch = chatIds.skip(start).take(_syncBatchSize);
      final chats = await Future.wait(
        batch.map(
          (chatId) => TDLibClient.getChat(chatId: chatId, accountId: account),
        ),
      );
      if (generation != _generation) return;

      for (final chat in chats) {
        if (chat == null) continue;
        _maybeDownloadPhoto(chat, accountId: account);
        _maybeResolveAlbum(chat);
        _chats[chat['id'] as int] = chat;
      }
      _notify();
    }
  }

  /// Walks TDLib's paged chat lists until both are exhausted.
  ///
  /// Each call answers "Ok" while chats remain and an error once the list ends,
  /// so the pages follow each other immediately: TDLib serializes them itself,
  /// and waiting between them only kept the list incomplete for longer.
  Future<void> _loadAll(int account, int generation) async {
    try {
      while (await _loadPage(account) && generation == _generation) {}
      while (await _loadPage(account, archived: true) &&
          generation == _generation) {}
    } catch (e) {
      logger.e('Failed to load chats: $e');
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Asks for one more page of a list, reporting whether chats remain.
  Future<bool> _loadPage(int account, {bool archived = false}) async {
    final answer = archived
        ? await TDLibClient.loadArchivedChats(
            limit: _pageSize,
            accountId: account,
          )
        : await TDLibClient.loadChats(limit: _pageSize, accountId: account);
    return answer == "Ok";
  }

  /// Albums resolved for a chat-list preview, keyed by their album id.
  ///
  /// TDLib's `lastMessage` is a single message, and in an album only one member
  /// carries the caption — usually the first, while `lastMessage` is the last.
  /// Reading the preview off `lastMessage` alone therefore shows "Photo" for an
  /// album that visibly has a caption. Each album is resolved once, off the
  /// render path.
  final Map<int, List<Map<String, dynamic>>> _albums = {};

  /// A message's album id, or null when it isn't part of an album.
  static int? albumIdOf(Map<String, dynamic>? message) {
    final id = message?['mediaAlbumId'] as int?;
    return (id == null || id == 0) ? null : id;
  }

  /// Resolves and caches the album [lastMessage] belongs to.
  Future<void> _resolveAlbum(
    int chatId,
    int albumId,
    Map<String, dynamic> lastMessage,
  ) async {
    if (_albums.containsKey(albumId)) return;
    // Claim the id before awaiting, so the burst of updates that arrives with
    // a new album doesn't start the same fetch several times over.
    _albums[albumId] = const [];

    final generation = _generation;
    final members = await collectAlbumMembers(
      lastMessage: lastMessage,
      albumId: albumId,
      fetchOlder: (fromMessageId) async {
        final history = await TDLibClient.getChatHistory(
          chatId: chatId,
          fromMessageId: fromMessageId,
          offset: 0,
          limit: maxAlbumSize,
          onlyLocal: false,
        );
        return history?.messages ?? const [];
      },
    );
    // The chats this album belonged to may have been put aside for another
    // account while the history was being paged.
    if (generation != _generation) return;

    _albums[albumId] = members;
    _notify();
  }

  /// Starts resolving [chat]'s album preview when it has one.
  void _maybeResolveAlbum(Map<String, dynamic> chat) {
    final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
    final albumId = albumIdOf(lastMessage);
    if (albumId == null || _albums.containsKey(albumId)) return;
    _resolveAlbum(chat['id'] as int, albumId, lastMessage!);
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
    _notify();
  }

  void _onChatUpdate(Map<String, dynamic> update) {
    if (_isForeign(update)) return;
    switch (update['@type']) {
      case updateNewChatConst:
        final chat = Map<String, dynamic>.from(update['chat'] as Map);
        _maybeDownloadPhoto(chat);
        _maybeResolveAlbum(chat);
        _chats[chat['id'] as int] = chat;
        _notify();

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
        _notify();

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
          final updated = {
            ...chat,
            'lastMessage': update['lastMessage'],
            'positions': positions,
          };
          _maybeResolveAlbum(updated);
          return updated;
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

      case updateChatEmojiStatusConst:
        _patchChat(
          update['chatId'] as int,
          (chat) => {...chat, 'emojiStatus': update['emojiStatus']},
        );

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
        _notify();

      case updateUserStatusConst:
        final userId = update['userId'] as int;
        final user = _users[userId];
        if (user == null) return;
        _users[userId] = {...user, 'status': update['status']};
        _notify();
    }
  }

  /// Whether an update belongs to an account other than the one on screen.
  ///
  /// The stream this store listens to is already filtered by account, so this
  /// should never fire — which is the point. Folding in a foreign update mixes
  /// two accounts' chats, and that is the one way this store can fail that
  /// stays invisible until it is thoroughly wrong.
  bool _isForeign(Map<String, dynamic> update) {
    final accountId = update['@accountId'] as int?;
    if (accountId == null || accountId == _account) return false;
    // Reported once per pair of accounts: a leak arrives as a burst of
    // hundreds of updates, and a log line each buries everything else.
    if (_reportedLeaks.add('$accountId>$_account')) {
      logger.w('Dropped an update of account $accountId in the store '
          'of account $_account');
    }
    return true;
  }

  /// Patches a freshly downloaded avatar file back into the chat that
  /// references it. Without this a chat keeps its empty initial path and the
  /// avatar only appears after a restart.
  void _onFileUpdate(Map<String, dynamic> update) {
    if (_isForeign(update) || update['@type'] != updateFileConst) return;
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
    if (changed) _notify();
  }

  /// Starts fetching a chat's avatar, if it has one that is not on disk yet.
  ///
  /// [accountId] is named during a sync: a file id belongs to the client that
  /// issued it, so sending it to whichever client is active by the time the
  /// request goes out would fetch an unrelated file.
  void _maybeDownloadPhoto(Map<String, dynamic> chat, {int? accountId}) {
    final small = chat['photo']?['small'];
    if (small is! Map) return;
    if (small['local']?['path'] != "" || small['remote']?['id'] == null) return;
    TDLibClient.downloadFile(
      fileId: small['id'] as int,
      accountId: accountId,
    ).catchError((_) {});
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
  ///
  /// Memoized until the next mutation: every chat-list view asks for its own
  /// list on every rebuild, and each answer means filtering, sorting and
  /// copying the whole store.
  List<Map<String, dynamic>> visibleChats({
    required ChatListKind kind,
    int? folderId,
  }) =>
      _visible.putIfAbsent(
        '${kind.name}:$folderId',
        () => _computeVisibleChats(kind: kind, folderId: folderId),
      );

  List<Map<String, dynamic>> _computeVisibleChats({
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

    return [
      for (final entry in visible)
        _withResolvedAlbum(_withResolvedSender(entry.$1)),
    ];
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

  /// Attaches the resolved album members to a chat, under `lastMessageAlbum`,
  /// so the row can render the album's own caption and thumbnails.
  Map<String, dynamic> _withResolvedAlbum(Map<String, dynamic> chat) {
    final albumId = albumIdOf(chat['lastMessage'] as Map<String, dynamic>?);
    if (albumId == null) return chat;
    final members = _albums[albumId];
    if (members == null || members.isEmpty) return chat;
    return {...chat, 'lastMessageAlbum': members};
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
    return chat == null ? null : _withResolvedAlbum(_withResolvedSender(chat));
  }

  /// The number of chats with something unread in [kind], optionally scoped to
  /// a folder. Muted chats still count, matching Telegram's tab badges.
  int unreadChatCount({required ChatListKind kind, int? folderId}) =>
      _unreadCounts.putIfAbsent(
        '${kind.name}:$folderId',
        () => _computeUnreadChatCount(kind: kind, folderId: folderId),
      );

  int _computeUnreadChatCount({required ChatListKind kind, int? folderId}) {
    var count = 0;
    for (final chat in _chats.values) {
      if (positionIn(chat, kind, folderId: folderId) == null) continue;
      final unread = chat['unreadCount'] as int? ?? 0;
      if (unread > 0 || chat['isMarkedAsUnread'] == true) count++;
    }
    return count;
  }

  /// Whether any chat currently sits in the archive.
  bool get hasArchivedChats => _hasArchived ??= _chats.values
      .any((chat) => positionIn(chat, ChatListKind.archive) != null);

  /// Empties the store and stops folding updates.
  ///
  /// Called on sign-out: the store is a singleton that outlives the session, so
  /// without this the next account would briefly see the previous one's chats.
  void reset() {
    _snapshots.remove(TDLibClient.activeAccountId);
    _clear();
    AvatarCache.clear();
    CustomEmojiCache.clear();
    _notify();
  }

  /// Puts the current chats aside under [accountId] and empties the store.
  ///
  /// Used when switching accounts. The account being left behind keeps its
  /// client online, but its updates stop reaching this store, so its chats are
  /// kept as they were and handed straight back when it returns to the screen
  /// — a switch then paints immediately and re-syncs behind the list, instead
  /// of showing a skeleton while a few hundred chats are fetched again.
  ///
  /// The avatar and emoji caches are keyed by file path, and every account has
  /// its own directory, so they are deliberately left warm.
  void stash(int accountId) {
    _snapshots[accountId] = _AccountSnapshot(
      chats: Map.of(_chats),
      users: Map.of(_users),
      supergroups: Map.of(_supergroups),
      folders: _folders,
      albums: Map.of(_albums),
    );
    _clear();
    _notify();
  }

  /// Hands the screen from one account to another in a single step.
  ///
  /// Stashing and restoring together means the new account's chats are in
  /// place before the frame that drops the old ones is drawn, so a switch
  /// never flashes the loading skeleton at an account whose chats are known.
  void swap({required int from, required int to}) {
    stash(from);
    _restoreSnapshot(to);
  }

  /// Forgets an account's stashed chats, for one that is being signed out.
  void forgetSnapshot(int accountId) => _snapshots.remove(accountId);

  /// Brings [accountId]'s stashed chats back, if it has any.
  void _restoreSnapshot(int accountId) {
    final snapshot = _snapshots.remove(accountId);
    if (snapshot == null) return;

    _chats.addAll(snapshot.chats);
    _users.addAll(snapshot.users);
    _supergroups.addAll(snapshot.supergroups);
    _albums.addAll(snapshot.albums);
    _folders = snapshot.folders;
    // There is something to show, so the list must not fall back to the
    // skeleton while the refresh runs.
    _isLoading = false;
    _restoredFromSnapshot = true;
    _notify();
  }

  /// Drops every chat and stops folding updates, leaving the caches alone.
  void _clear() {
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _fileSubscription?.cancel();
    _fileSubscription = null;
    _chats.clear();
    _users.clear();
    _supergroups.clear();
    _folders = const [];
    _albums.clear();
    _isLoading = true;
    _started = false;
    _restoredFromSnapshot = false;
    // Whatever is still in flight for the account being left belongs to the
    // run that ends here.
    _generation++;
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _fileSubscription?.cancel();
    super.dispose();
  }
}

/// How many chats one initial-sync batch resolves at a time.
const int _syncBatchSize = 40;

/// How many chats one `loadChats` page asks TDLib for.
const int _pageSize = 100;

/// The ceiling used when re-reading both lists to confirm restored chats.
const int _confirmLimit = 10000;

/// One account's chats, kept while another account is on screen.
@immutable
class _AccountSnapshot {
  const _AccountSnapshot({
    required this.chats,
    required this.users,
    required this.supergroups,
    required this.folders,
    required this.albums,
  });

  final Map<int, Map<String, dynamic>> chats;
  final Map<int, Map<String, dynamic>> users;
  final Map<int, Map<String, dynamic>> supergroups;
  final List<Map<String, dynamic>> folders;
  final Map<int, List<Map<String, dynamic>>> albums;
}

/// Telegram caps an album at ten items.
const int maxAlbumSize = 10;

/// Collects every member of the album [lastMessage] belongs to, newest last.
///
/// Album members are contiguous in message-id order, so the history is paged
/// backwards from the newest member until a message outside the album shows up.
/// Paging is unavoidable: `getChatHistory` documents that "the number of
/// returned messages is chosen by TDLib and can be smaller than the specified
/// limit", and in practice a single call often answers with one message —
/// which is what made a three-photo album read as "1 photo".
///
/// [fetchOlder] returns the messages older than a given id, newest first. It is
/// injected so the walk can be exercised against that short-batch behaviour.
Future<List<Map<String, dynamic>>> collectAlbumMembers({
  required Map<String, dynamic> lastMessage,
  required int albumId,
  required Future<List<Map<String, dynamic>>> Function(int fromMessageId)
      fetchOlder,
}) async {
  // The last member is already in hand; only the older ones need fetching.
  final members = <int, Map<String, dynamic>>{
    lastMessage['id'] as int: lastMessage,
  };
  var cursor = lastMessage['id'] as int;
  var reachedAlbumStart = false;

  // A short batch is normal, so an empty answer doesn't prove the history
  // ended — but it does after a couple of tries.
  var emptyRounds = 0;

  while (!reachedAlbumStart && members.length < maxAlbumSize && emptyRounds < 2) {
    final older = await fetchOlder(cursor);
    var advanced = false;

    for (final message in older) {
      final messageId = message['id'] as int;
      // `offset: 0` is documented as starting "from exactly" the cursor, and
      // TDLib has shipped it both inclusive and exclusive; skipping ids that
      // are already held makes the walk correct either way.
      if (messageId >= cursor) continue;
      cursor = messageId;
      advanced = true;

      if (ChatStore.albumIdOf(message) != albumId) {
        reachedAlbumStart = true;
        break;
      }
      members[messageId] = message;
    }

    emptyRounds = advanced ? 0 : emptyRounds + 1;
  }

  return members.values.toList()
    ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
}

/// Whether a chat is muted, i.e. its notifications are suppressed.
bool isChatMuted(Map<String, dynamic> chat) =>
    (chat['notificationSettings']?['muteFor'] as int? ?? 0) > 0;
