import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/album_bubble.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/chat/widgets/date_separator.dart';
import 'package:nullgram/pages/chat/widgets/forward_chat_picker.dart';
import 'package:nullgram/pages/chat/widgets/message_bubble.dart';
import 'package:nullgram/pages/chat/widgets/message_context_menu.dart';
import 'package:nullgram/pages/profile/chat_profile_page.dart';
import 'package:nullgram/services/notification_service.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/services/call_service.dart';
import 'package:nullgram/theme/motion.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatPage({
    super.key,
    required this.chat,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isAudioMode = ValueNotifier(true);
  final ValueNotifier<bool> _isRecording = ValueNotifier<bool>(false);
  final ValueNotifier<String> _messageText = ValueNotifier('');

  final ValueNotifier<List<Map<String, dynamic>>> _messages = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _hasMore = ValueNotifier(true);
  final ValueNotifier<bool> _showScrollToBottom = ValueNotifier(false);

  /// Whether the in-chat message search bar is active.
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<List<Map<String, dynamic>>> _searchResults =
      ValueNotifier([]);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Pinned messages in this chat, newest first; drives the top pin banner.
  final ValueNotifier<List<Map<String, dynamic>>> _pinnedMessages =
      ValueNotifier([]);

  /// The resolved user behind a private/secret chat, kept live via chat
  /// updates. The TDLib chat object has no embedded user, so it is fetched via
  /// [TDLibClient.getUser] rather than read from `chat['user']`.
  final ValueNotifier<Map<String, dynamic>?> _chatUser = ValueNotifier(null);
  StreamSubscription<Map<String, dynamic>>? _chatSubscription;

  /// A human-readable activity ("typing…") for the other party, shown in the
  /// header in place of the status, or null when nobody is active.
  final ValueNotifier<String?> _typingAction = ValueNotifier(null);
  StreamSubscription<Map<String, dynamic>>? _chatActionSubscription;

  /// Auto-clears [_typingAction] if TDLib stops sending action updates, since a
  /// `chatActionCancel` is not always delivered.
  Timer? _typingClearTimer;

  /// When the outgoing typing notification was last sent, used to throttle it.
  DateTime? _lastTypingSent;

  /// The message being replied to, or null when composing a fresh message.
  final ValueNotifier<Map<String, dynamic>?> _replyTo = ValueNotifier(null);

  /// The message being edited, or null when composing a fresh message.
  /// Mutually exclusive with [_replyTo].
  final ValueNotifier<Map<String, dynamic>?> _editing = ValueNotifier(null);

  final _record = AudioRecorder();

  /// Distance (px) from the bottom past which the jump-to-latest button shows
  /// and incoming messages stop auto-scrolling.
  static const double _stickToBottomThreshold = 320;

  static const int _batchSize = 50;

  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      _messageText.value = _messageController.text;
      if (_messageController.text.trim().isNotEmpty) _notifyTyping();
    });

    _scrollController.addListener(_onScroll);

    _messagesSubscription = TDLibClient.messsagesUpdates.listen((update) async {
      final type = update['@type'];
      switch (type) {
        case updateNewMessageConst:
          final message = update['message'];
          if (message['chatId'] == widget.chat['id']) {
            if (!mounted) return;
            if (_containsMessageId(message['id'])) return;
            _messages.value = AlbumsGrouper.groupMediaAlbums([message, ..._messages.value]);
            setState(() {});
            _maybeStickToBottom(isOutgoing: message['isOutgoing'] == true);
            if (message['isOutgoing'] != true) {
              TDLibClient.viewMessages(
                chatId: widget.chat['id'],
                messageIds: [message['id'] as int],
              );
            }
          }
        case updateDeleteMessagesConst:
          final chatId = update['chatId'];
          final messageIds = update['messageIds'];
          
          if (chatId == widget.chat['id']) {
            if (!mounted) return;
            
            _messages.value = _messages.value.where((message) {
              return !messageIds.contains(message['id']);
            }).toList();

            setState(() {});
          }
          break;
        case updateMessageInteractionInfoConst:
          if (update['chatId'] != widget.chat['id']) return;
          if (!mounted) return;
          _applyInteractionInfo(
            update['messageId'],
            update['interactionInfo'],
          );
        case updateMessageContentConst:
          if (update['chatId'] != widget.chat['id']) return;
          if (!mounted) return;
          _patchMessage(
            update['messageId'],
            (message) => {...message, 'content': update['newContent']},
          );
        case updateMessageEditedConst:
          if (update['chatId'] != widget.chat['id']) return;
          if (!mounted) return;
          _patchMessage(
            update['messageId'],
            (message) => {...message, 'editDate': update['editDate']},
          );
      }
    });

    _loadLocalMessages();
    _loadPinnedMessages();
    _resolveChatUser();
    _listenChatActions();

    // Tell TDLib the chat is open so read receipts and channel updates flow.
    TDLibClient.openChat(chatId: widget.chat['id']);
    _markReadUpTo(widget.chat['lastMessage']?['id'] as int?);

    // Suppress notifications for the chat currently on screen.
    NotificationService.instance.activeChatId = widget.chat['id'] as int?;
  }

  /// Throttled outgoing "typing" notification, sent at most once every few
  /// seconds while the user keeps editing the composer.
  void _notifyTyping() {
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastTypingSent = now;
    TDLibClient.sendChatAction(chatId: widget.chat['id']);
  }

  /// Marks the chat read up to [messageId] (and all older messages).
  void _markReadUpTo(int? messageId) {
    if (messageId == null) return;
    if ((widget.chat['unreadCount'] as int? ?? 0) == 0) return;
    TDLibClient.viewMessages(
      chatId: widget.chat['id'],
      messageIds: [messageId],
    );
  }

  /// Listens for the other party's activity in this chat and surfaces it as
  /// [_typingAction], auto-clearing it after a short idle period.
  void _listenChatActions() {
    _chatActionSubscription = TDLibClient.chatUpdates.listen((update) {
      if (!mounted) return;
      if (update['@type'] != updateChatActionConst) return;
      if (update['chatId'] != widget.chat['id']) return;

      final actionType = update['action']?['@type'] as String?;
      if (actionType == null || actionType == 'ChatActionCancel') {
        _typingClearTimer?.cancel();
        _typingAction.value = null;
        return;
      }

      _typingAction.value = _describeAction(actionType);
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(
        const Duration(seconds: 6),
        () => _typingAction.value = null,
      );
    });
  }

  /// Maps a TDLib `ChatAction` type to a short status line.
  String _describeAction(String actionType) => switch (actionType) {
        'ChatActionRecordingVoiceNote' => 'recording voice…',
        'ChatActionUploadingVoiceNote' => 'sending voice…',
        'ChatActionRecordingVideo' ||
        'ChatActionRecordingVideoNote' =>
          'recording video…',
        'ChatActionUploadingVideo' ||
        'ChatActionUploadingVideoNote' =>
          'sending video…',
        'ChatActionUploadingPhoto' => 'sending photo…',
        'ChatActionUploadingDocument' => 'sending file…',
        _ => 'typing…',
      };

  /// The user id behind a private/secret chat, read from the chat's type.
  int? _chatUserId() {
    final type = widget.chat['type'];
    final typeName = type?['@type'];
    if (typeName == 'ChatTypePrivate' || typeName == 'ChatTypeSecret') {
      return type['userId'] as int?;
    }
    return null;
  }

  /// Places an outgoing voice call to the private chat's peer.
  Future<void> _startVoiceCall() async {
    final userId = _chatUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Calls are available in private chats only')),
        );
      }
      return;
    }
    if (!await _record.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    await callService.startCall(userId: userId, isVideo: false);
  }

  /// Resolves the chat's user (for the header) and keeps its status live by
  /// listening to user/status chat updates.
  void _resolveChatUser() {
    final userId = _chatUserId();
    if (userId == null) return;

    TDLibClient.getUser(userId: userId).then((user) {
      if (mounted) _chatUser.value = user;
    }).catchError((_) {});

    _chatSubscription = TDLibClient.chatUpdates.listen((update) {
      if (!mounted) return;
      switch (update['@type']) {
        case updateUserConst:
          if (update['user']?['id'] == userId) _chatUser.value = update['user'];
        case updateUserStatusConst:
          if (update['userId'] == userId && _chatUser.value != null) {
            _chatUser.value = {
              ..._chatUser.value!,
              'status': update['status'],
            };
          }
      }
    });
  }

  /// Loads the chat's pinned messages (newest first) for the top banner.
  Future<void> _loadPinnedMessages() async {
    final result = await TDLibClient.searchChatMessages(
      chatId: widget.chat['id'] as int,
      filter: const {"@type": "searchMessagesFilterPinned"},
    );
    if (!mounted) return;
    _pinnedMessages.value = result?.messages ?? const [];
  }

  /// A stable per-sender key used to group consecutive messages. Albums never
  /// group with anything, so each gets a unique key.
  String _senderKey(Map<String, dynamic> message) {
    if (message['isAlbum'] == true) return 'album_${message['id']}';
    final sender = message['senderId'];
    final id = sender?['userId'] ?? sender?['chatId'];
    if (id != null) return 'id_$id';
    return message['isOutgoing'] == true ? 'me' : 'other';
  }

  /// Two messages belong to the same group if from the same sender and sent
  /// within five minutes of each other.
  bool _sameGroup(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return false;
    if (a['isAlbum'] == true || b['isAlbum'] == true) return false;
    if (_senderKey(a) != _senderKey(b)) return false;
    final da = a['date'] as int? ?? 0;
    final db = b['date'] as int? ?? 0;
    return (da - db).abs() <= 300;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > _stickToBottomThreshold;
    if (show != _showScrollToBottom.value) _showScrollToBottom.value = show;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Keeps the view pinned to the newest message when the user is already near
  /// the bottom, or always for messages they just sent.
  void _maybeStickToBottom({required bool isOutgoing}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (isOutgoing || _scrollController.offset < _stickToBottomThreshold) {
        _scrollToBottom();
      }
    });
  }

  /// Whether a message with [id] is already shown, checking both standalone
  /// messages and members grouped inside album entries.
  bool _containsMessageId(int id) {
    for (final entry in _messages.value) {
      if (entry['isAlbum'] == true) {
        if ((entry['messages'] as List).any((m) => m['id'] == id)) return true;
      } else if (entry['id'] == id) {
        return true;
      }
    }
    return false;
  }

  /// Drops any incoming messages already present, so overlapping history loads
  /// or a live update racing a load can't introduce duplicates.
  List<Map<String, dynamic>> _withoutDuplicates(
    List<Map<String, dynamic>> incoming,
  ) =>
      incoming.where((m) => !_containsMessageId(m['id'])).toList();

  /// Patches the new [interactionInfo] (view/forward counts and reactions) onto
  /// the message with [messageId], whether it's standalone or grouped inside an
  /// album, then refreshes the list so reaction chips redraw live.
  void _applyInteractionInfo(int messageId, dynamic interactionInfo) {
    var changed = false;
    final updated = _messages.value.map((entry) {
      if (entry['isAlbum'] == true) {
        final members = entry['messages'] as List;
        final index = members.indexWhere((m) => m['id'] == messageId);
        if (index == -1) return entry;
        members[index] = {
          ...members[index],
          'interactionInfo': interactionInfo,
        };
        changed = true;
        return {...entry, 'messages': members};
      }
      if (entry['id'] == messageId) {
        changed = true;
        return {...entry, 'interactionInfo': interactionInfo};
      }
      return entry;
    }).toList();

    if (changed) {
      _messages.value = updated;
      setState(() {});
    }
  }

  /// Applies [transform] to the message with [messageId], whether standalone or
  /// grouped inside an album, then refreshes the list. Used for live edits.
  void _patchMessage(
    int messageId,
    Map<String, dynamic> Function(Map<String, dynamic> message) transform,
  ) {
    var changed = false;
    final updated = _messages.value.map((entry) {
      if (entry['isAlbum'] == true) {
        final members = entry['messages'] as List;
        final index = members.indexWhere((m) => m['id'] == messageId);
        if (index == -1) return entry;
        members[index] =
            transform(Map<String, dynamic>.from(members[index]));
        changed = true;
        return {...entry, 'messages': members};
      }
      if (entry['id'] == messageId) {
        changed = true;
        return transform(entry);
      }
      return entry;
    }).toList();

    if (changed) {
      _messages.value = updated;
      setState(() {});
    }
  }

  /// Adds or removes the [emoji] reaction on [message]. Mirrors Telegram's
  /// single-reaction behavior: tapping a chosen reaction clears it, while a new
  /// one first removes any currently chosen reactions. The visible state is
  /// refreshed by the resulting `UpdateMessageInteractionInfo`.
  Future<void> _toggleReaction(
    Map<String, dynamic> message,
    String emoji,
  ) async {
    final chatId = widget.chat['id'] as int;
    final messageId = message['id'] as int;
    final reactions =
        message['interactionInfo']?['reactions']?['reactions'] as List? ??
            const [];

    final chosen = reactions
        .where((r) =>
            r['isChosen'] == true && r['type']?['@type'] == 'ReactionTypeEmoji')
        .map((r) => r['type']['emoji'] as String)
        .toList();

    if (chosen.contains(emoji)) {
      await TDLibClient.removeMessageReaction(
        chatId: chatId,
        messageId: messageId,
        emoji: emoji,
      );
      return;
    }

    for (final existing in chosen) {
      await TDLibClient.removeMessageReaction(
        chatId: chatId,
        messageId: messageId,
        emoji: existing,
      );
    }
    await TDLibClient.addMessageReaction(
      chatId: chatId,
      messageId: messageId,
      emoji: emoji,
    );
  }

  /// Opens the long-press context menu and dispatches the chosen action.
  Future<void> _onMessageLongPress(Map<String, dynamic> message) async {
    HapticFeedback.selectionClick();
    final chatId = widget.chat['id'] as int;
    final messageId = message['id'] as int;

    final result = await showMessageContextMenu(
      context: context,
      availableReactions: TDLibClient.getMessageAvailableReactions(
        chatId: chatId,
        messageId: messageId,
      ),
      canDelete: message['canBeDeletedForAllUsers'] == true ||
          message['canBeDeletedOnlyForSelf'] == true,
      canEdit: message['canBeEdited'] == true,
      canPin: message['canBePinned'] == true,
      isPinned: message['isPinned'] == true,
    );

    if (result == null || !mounted) return;

    if (result.reactEmoji != null) {
      await _toggleReaction(message, result.reactEmoji!);
      return;
    }

    switch (result.action!) {
      case MessageMenuAction.reply:
        _editing.value = null;
        _replyTo.value = message;
        _messageFocusNode.requestFocus();
      case MessageMenuAction.edit:
        _startEditing(message);
      case MessageMenuAction.copy:
        _copyMessage(message);
      case MessageMenuAction.forward:
        await _forwardMessage(message);
      case MessageMenuAction.pin:
        await TDLibClient.pinChatMessage(
          chatId: widget.chat['id'],
          messageId: message['id'] as int,
        );
        await _loadPinnedMessages();
      case MessageMenuAction.unpin:
        await TDLibClient.unpinChatMessage(
          chatId: widget.chat['id'],
          messageId: message['id'] as int,
        );
        await _loadPinnedMessages();
      case MessageMenuAction.delete:
        await _deleteMessage(message);
    }
  }

  /// Enters edit mode for [message]: prefills the composer with its current
  /// text/caption and focuses the field. Clears any pending reply.
  void _startEditing(Map<String, dynamic> message) {
    final content = message['content'];
    final text = content?['text']?['text'] ?? content?['caption']?['text'] ?? '';
    _replyTo.value = null;
    _editing.value = message;
    _messageController.text = text.toString();
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    _messageFocusNode.requestFocus();
  }

  /// Copies the message's text or caption to the clipboard.
  void _copyMessage(Map<String, dynamic> message) {
    final content = message['content'];
    final text = content?['text']?['text'] ?? content?['caption']?['text'];
    if (text is String && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Picks a destination chat and forwards [message] into it.
  Future<void> _forwardMessage(Map<String, dynamic> message) async {
    final targetChatId = await showForwardChatPicker(context);
    if (targetChatId == null) return;
    await TDLibClient.forwardMessages(
      chatId: targetChatId,
      fromChatId: widget.chat['id'],
      messageIds: [message['id'] as int],
    );
  }

  /// Confirms and deletes [message] for all chat members.
  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await TDLibClient.deleteMessages(
      chatId: widget.chat['id'],
      messageIds: [message['id'] as int],
    );
  }

  void _openSearch() {
    _isSearching.value = true;
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchResults.value = [];
    _isSearching.value = false;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _searchResults.value = [];
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final result = await TDLibClient.searchChatMessages(
      chatId: widget.chat['id'] as int,
      query: query,
    );
    if (!mounted) return;
    _searchResults.value = result?.messages ?? const [];
  }

  /// Reloads the history window around [messageId] so a search hit becomes
  /// visible, then scrolls to it. Replaces the current message list rather than
  /// scrolling the lazy one, since older messages may not be loaded yet.
  Future<void> _jumpToMessage(int messageId) async {
    _closeSearch();
    _isLoading.value = true;

    final window = await TDLibClient.getChatHistory(
      chatId: widget.chat['id']!,
      fromMessageId: messageId,
      offset: -25,
      limit: 50,
      onlyLocal: false,
    );

    if (!mounted) return;

    final messages = window?.messages ?? const <Map<String, dynamic>>[];
    _messages.value = AlbumsGrouper.groupMediaAlbums([...messages]);
    _hasMore.value = true;
    _isLoading.value = false;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _messages.value.isEmpty) return;
      final index = _messages.value.indexWhere((m) => m['id'] == messageId);
      if (index < 0) return;
      final itemHeight =
          _scrollController.position.maxScrollExtent / _messages.value.length;
      _scrollController.jumpTo(
        (index * itemHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  Future<void> _loadLocalMessages() async {
    try {
      while (true) {
        if (!mounted) return;
        _isLoading.value = true;
        final fromId = _messages.value.isEmpty ? 0 : _messages.value.last['id'];

        final localMessages = await TDLibClient.getChatHistory(
          chatId: widget.chat['id']!,
          fromMessageId: fromId,
          offset: 0,
          limit: _batchSize * 2,
          onlyLocal: true,
        );

        if (!mounted) return;

        final fresh = localMessages == null
            ? const <Map<String, dynamic>>[]
            : _withoutDuplicates(localMessages.messages);

        if (fresh.isNotEmpty) {
          _messages.value = AlbumsGrouper.groupMediaAlbums([..._messages.value, ...fresh]);
          setState(() {});
        } else {
          break;
        }
      }
    } catch (e) {
      logger.e('Error loading initial messages: $e');
    }
    if (!mounted) return;
    _isLoading.value = false;
  }

  Future<void> _loadBatch() async {
    if (_isLoading.value || !_hasMore.value) return;
    _isLoading.value = true;

    final fromId = _messages.value.isEmpty ? 0 : _messages.value.last['id'];

    final messages = await TDLibClient.getChatHistory(
      chatId: widget.chat['id']!,
      fromMessageId: fromId,
      offset: 0,
      limit: _batchSize * 2,
      onlyLocal: false,
    );

    if (messages == null || messages.messages.isEmpty) {
      _hasMore.value = false;
      _isLoading.value = false;
      return;
    }

    final fresh = _withoutDuplicates(messages.messages);
    if (fresh.isEmpty) {
      _isLoading.value = false;
      return;
    }

    final pos = _scrollController.position;
    final firstVisibleIndex = (_messages.value.isNotEmpty && pos.maxScrollExtent > 0)
        ? (pos.pixels / (pos.maxScrollExtent / _messages.value.length)).round().clamp(0, _messages.value.length - 1)
        : 0;

    _messages.value = AlbumsGrouper.groupMediaAlbums([..._messages.value, ...fresh]);

    await Future.delayed(Duration.zero);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final itemHeight = _scrollController.position.maxScrollExtent / _messages.value.length;
        final targetPosition = firstVisibleIndex * itemHeight;
        _scrollController.jumpTo(targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent));
      }
      _isLoading.value = false;
    });
  }

  @override
  void dispose() {
    if (NotificationService.instance.activeChatId == widget.chat['id']) {
      NotificationService.instance.activeChatId = null;
    }
    TDLibClient.closeChat(chatId: widget.chat['id']);
    _typingClearTimer?.cancel();
    _typingAction.dispose();
    _chatActionSubscription?.cancel();
    _messagesSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _isAudioMode.dispose();
    _messageText.dispose();
    _messages.dispose();
    _isLoading.dispose();
    _hasMore.dispose();
    _showScrollToBottom.dispose();
    _replyTo.dispose();
    _editing.dispose();
    _isSearching.dispose();
    _searchResults.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _pinnedMessages.dispose();
    _chatUser.dispose();
    _chatSubscription?.cancel();
    _record.dispose();
    super.dispose();
  }

  Future<void> startAudioRecording() async {
    if (await _record.hasPermission()) {
      _isRecording.value = true;

      final dir = await getTemporaryDirectory();

      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 96000,
        ),
        path: '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.ogg',
      );
    }
  }
  Future<void> stopAudioRecording() async {
    final chatId = widget.chat['id'];
    final path = await _record.stop();

    _isRecording.value = false;

    await TDLibClient.sendAudio(chatId: chatId, path: path!);
  }

  // TODO: Implement video recording methods
  Future<void> startVideoRecording() async {}
  Future<void> stopVideoRecording() async {}

  Future<void> _sendMessage() async {
    final raw = _messageController.text.trim();
    if (raw.isEmpty) return;

    // Parse MarkdownV2 into entities server-side; on a malformed-markdown error
    // fall back to the raw text so the message is never dropped.
    final parsed = await TDLibClient.parseTextEntities(text: raw);
    if (!mounted) return;
    final text = parsed?['text'] as String? ?? raw;
    final entities = (parsed?['entities'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final editing = _editing.value;
    if (editing != null) {
      _messageController.clear();
      _editing.value = null;
      await TDLibClient.editMessageText(
        chatId: widget.chat['id'],
        messageId: editing['id'] as int,
        text: text,
        entities: entities,
      );
      return;
    }

    final replyToMessageId = _replyTo.value?['id'] as int?;
    _messageController.clear();
    _replyTo.value = null;
    await TDLibClient.sendMessage(
      chatId: widget.chat['id'],
      text: text,
      replyToMessageId: replyToMessageId,
      entities: entities,
    );
  }

  /// Wraps the current selection with [left]/[right] markers and keeps the
  /// inner text selected, so repeated formatting nests predictably.
  void _wrapSelection(String left, String right) {
    final selection = _messageController.selection;
    final text = _messageController.text;
    if (!selection.isValid || selection.isCollapsed) return;

    final selected = selection.textInside(text);
    _messageController.value = TextEditingValue(
      text: selection.textBefore(text) +
          left +
          selected +
          right +
          selection.textAfter(text),
      selection: TextSelection(
        baseOffset: selection.start + left.length,
        extentOffset: selection.start + left.length + selected.length,
      ),
    );
    _messageFocusNode.requestFocus();
  }

  Future<void> _insertLink() async {
    final selection = _messageController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    _wrapSelection('[', ']($url)');
  }

  /// Shows the attach options (photo / video / document) and sends the picked
  /// file, using any composer text as its caption.
  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Consumes the composer's text as a caption and the active reply target,
  /// clearing both so the next message starts fresh.
  ({String caption, int? replyToMessageId}) _consumeComposer() {
    final caption = _messageController.text.trim();
    final replyToMessageId = _replyTo.value?['id'] as int?;
    _messageController.clear();
    _replyTo.value = null;
    return (caption: caption, replyToMessageId: replyToMessageId);
  }

  Future<void> _pickAndSendImage({required bool isVideo}) async {
    final picker = ImagePicker();
    final file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final composer = _consumeComposer();
    final chatId = widget.chat['id'] as int;
    if (isVideo) {
      await TDLibClient.sendVideo(
        chatId: chatId,
        path: file.path,
        caption: composer.caption,
        replyToMessageId: composer.replyToMessageId,
      );
    } else {
      await TDLibClient.sendPhoto(
        chatId: chatId,
        path: file.path,
        caption: composer.caption,
        replyToMessageId: composer.replyToMessageId,
      );
    }
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;

    final composer = _consumeComposer();
    await TDLibClient.sendDocument(
      chatId: widget.chat['id'] as int,
      path: path,
      caption: composer.caption,
      replyToMessageId: composer.replyToMessageId,
    );
  }

  /// Builds the composer's text-selection menu: a single compact, horizontally
  /// scrolling bar (Telegram-style) with copy/paste plus formatting actions
  /// that wrap the selection with MarkdownV2 markers.
  ///
  /// A custom bar is used instead of [AdaptiveTextSelectionToolbar] because the
  /// platform toolbar overflows its many items into a vertical menu that can
  /// exceed the screen height and crash during layout.
  Widget _composerContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selection = _messageController.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    void act(VoidCallback apply) {
      editableTextState.hideToolbar();
      apply();
    }

    final items = <_SelectionAction>[
      if (hasSelection)
        _SelectionAction('Copy', () {
          act(() =>
              editableTextState.copySelection(SelectionChangedCause.toolbar));
        }),
      _SelectionAction('Paste', () {
        act(() =>
            editableTextState.pasteText(SelectionChangedCause.toolbar));
      }),
      if (hasSelection) ...[
        _SelectionAction('Bold', () => act(() => _wrapSelection('*', '*'))),
        _SelectionAction('Italic', () => act(() => _wrapSelection('_', '_'))),
        _SelectionAction(
            'Underline', () => act(() => _wrapSelection('__', '__'))),
        _SelectionAction('Strike', () => act(() => _wrapSelection('~', '~'))),
        _SelectionAction('Mono', () => act(() => _wrapSelection('`', '`'))),
        _SelectionAction('Link', () => act(_insertLink)),
      ],
    ];

    return _SelectionFormatBar(
      anchor: editableTextState.contextMenuAnchors.primaryAnchor,
      topInset: MediaQuery.of(context).padding.top,
      items: items,
    );
  }

  Widget _buildMessageInput() {
    final canSendBasicMessages = widget.chat['permissions']?['canSendBasicMessages'] ?? true;

    if (!canSendBasicMessages) {
      // No composer for channels/restricted chats. Still reserve the bottom
      // safe-area inset so the newest messages don't slide under the OS
      // navigation buttons.
      return SizedBox(height: MediaQuery.of(context).viewPadding.bottom);
    }

    return SafeArea(
      top: false,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: Motion.fast,
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: _buildEditPreview(),
          ),
          AnimatedSize(
            duration: Motion.fast,
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: _buildReplyPreview(),
          ),
          Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      contextMenuBuilder: _composerContextMenu,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showAttachMenu,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.attach_file, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<String>(
            valueListenable: _messageText,
            builder: (context, text, child) {
              // Non-empty text shows a send button; an empty field falls back to
              // the audio/video recorder. The two morph via an AnimatedSwitcher.
              return AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: text.trim().isNotEmpty
                    ? IconButton.filled(
                        key: const ValueKey('send'),
                        onPressed: _sendMessage,
                        tooltip: 'Send',
                        icon: const Icon(Icons.send),
                      )
                    : ValueListenableBuilder<bool>(
                        key: const ValueKey('record'),
                        valueListenable: _isAudioMode,
                        builder: (context, isAudioMode, child) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isRecording,
                            builder: (context, isRecording, child) {
                              return GestureDetector(
                                onTap: () {
                                  if (_isAudioMode.value &&
                                      _isRecording.value) {
                                    stopAudioRecording();
                                    return;
                                  } else if (!_isAudioMode.value &&
                                      _isRecording.value) {
                                    stopVideoRecording();
                                    return;
                                  }
                                  _isAudioMode.value = !isAudioMode;
                                },
                                onLongPressStart: (_) async {
                                  if (isAudioMode) {
                                    await startAudioRecording();
                                  } else {
                                    await startVideoRecording();
                                  }
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isRecording
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isAudioMode
                                          ? (isRecording
                                              ? Icons.mic
                                              : Icons.mic_none)
                                          : Icons.videocam,
                                      color: isRecording
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onError
                                          : Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              );
            },
          )
        ],
      ),
        ],
      ),
    ),
    );
  }

  /// A banner under the app bar showing the most recent pinned message; tapping
  /// it jumps to that message. Hidden when nothing is pinned.
  Widget _buildPinnedBanner() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _pinnedMessages,
      builder: (context, pinned, child) {
        if (pinned.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final message = pinned.first;
        final content = message['content'];
        final preview = content?['text']?['text'] ??
            content?['caption']?['text'] ??
            'Pinned message';

        return InkWell(
          onTap: () => _jumpToMessage(message['id'] as int),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pinned.length > 1
                            ? 'Pinned messages (${pinned.length})'
                            : 'Pinned message',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        preview.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.push_pin, size: 18, color: scheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A full-height overlay listing in-chat search hits while search is active.
  /// Tapping a hit jumps to that message in the history.
  Widget _buildSearchResults() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSearching,
      builder: (context, isSearching, child) {
        if (!isSearching) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;

        return Positioned.fill(
          child: Container(
            color: scheme.surface,
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _searchResults,
              builder: (context, results, child) {
                if (results.isEmpty) {
                  return _searchController.text.trim().isEmpty
                      ? const EmptyState(
                          icon: Icons.search,
                          title: 'Search messages',
                          subtitle: 'Type to find messages in this chat.',
                        )
                      : const EmptyState(
                          icon: Icons.search_off,
                          title: 'No messages found',
                        );
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final message = results[index];
                    final content = message['content'];
                    final preview = content?['text']?['text'] ??
                        content?['caption']?['text'] ??
                        'Message';
                    return ListTile(
                      title: Text(
                        preview.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        MessageFormatter.formatDateSeparator(message['date']),
                      ),
                      onTap: () => _jumpToMessage(message['id'] as int),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// A compact preview of the message being edited, shown above the composer;
  /// hidden when no edit is in progress. Closing it cancels the edit and clears
  /// the prefilled text.
  Widget _buildEditPreview() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _editing,
      builder: (context, editing, child) {
        if (editing == null) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final content = editing['content'];
        final preview = content?['text']?['text'] ??
            content?['caption']?['text'] ??
            'Message';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit message',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      preview.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                onPressed: () {
                  _editing.value = null;
                  _messageController.clear();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// A compact preview of the message being replied to, shown above the
  /// composer; hidden when no reply is pending.
  Widget _buildReplyPreview() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _replyTo,
      builder: (context, replyTo, child) {
        if (replyTo == null) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        final content = replyTo['content'];
        final preview = content?['text']?['text'] ??
            content?['caption']?['text'] ??
            'Message';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      preview.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: 20,
                onPressed: () => _replyTo.value = null,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isSearching,
          builder: (context, isSearching, child) {
            if (isSearching) {
              return AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeSearch,
                ),
                titleSpacing: 0,
                title: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search messages...',
                    border: InputBorder.none,
                  ),
                ),
              );
            }
            return AppBar(
              titleSpacing: 0,
              title: ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _chatUser,
                builder: (context, user, child) {
                  // Merge the resolved user into the chat so the avatar's
                  // online/bot indicator and the profile screen see it; the
                  // TDLib chat object itself carries no user.
                  final chatWithUser = user == null
                      ? widget.chat
                      : {...widget.chat, 'user': user};
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatProfilePage(chat: chatWithUser),
                      ),
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'chat_avatar_${widget.chat['id']}',
                          child: ChatAvatar(chat: chatWithUser, radius: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.chat['title'] ?? 'Chat',
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              ValueListenableBuilder<String?>(
                                valueListenable: _typingAction,
                                builder: (context, typing, _) {
                                  if (typing != null) {
                                    return Text(
                                      typing,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                    );
                                  }
                                  final mutedStyle = TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  );
                                  if (user != null) {
                                    return Text(
                                      MessageFormatter.getUserStatus(user),
                                      style: mutedStyle,
                                    );
                                  }
                                  if (widget.chat['supergroup'] != null) {
                                    return Text(
                                      "${NumberFormat('#,###', 'en_US').format(widget.chat['supergroup']['memberCount'] ?? 0)} subscribers",
                                      style: mutedStyle,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: _startVoiceCall,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          _buildPinnedBanner(),
          Expanded(
            child: Stack(
              children: [
                ValueListenableBuilder(
              valueListenable: _messages,
              builder: (context, messages, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, child) {
                    if (messages.isEmpty && !isLoading) {
                      return const EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'No messages yet',
                        subtitle: 'Send a message to start the conversation.',
                        lottieAsset: 'assets/lottie/empty.json',
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isLoading && index == messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        if (messages.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final messageIndex = index;
                        final message = messages[messageIndex];

                        final triggerIndex = 50;
                        final isNearEnd = messageIndex >= messages.length - triggerIndex;

                        if (isNearEnd && !isLoading && _hasMore.value) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _loadBatch();
                          });
                        }

                        // In a reverse list, lower indices are newer. "Older"
                        // sits above (next index), "newer" below (prev index).
                        final older = messageIndex + 1 < messages.length
                            ? messages[messageIndex + 1]
                            : null;
                        final newer = messageIndex - 1 >= 0
                            ? messages[messageIndex - 1]
                            : null;

                        final isFirstInGroup = !_sameGroup(message, older);
                        final isLastInGroup = !_sameGroup(message, newer);

                        final showDateSeparator = older == null ||
                            !MessageFormatter.isSameDay(
                              message['date'],
                              older['date'],
                            );

                        final Widget bubble = message['isAlbum'] == true
                            ? AlbumBubble(
                                albumMessages: message['messages'],
                                chat: widget.chat,
                                onLongPress: _onMessageLongPress,
                                onReactionTap: _toggleReaction,
                              )
                            : MessageBubble(
                                message: message,
                                chat: widget.chat,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                                onLongPress: _onMessageLongPress,
                                onReactionTap: _toggleReaction,
                              );

                        if (!showDateSeparator) return bubble;

                        return Column(
                          children: [
                            DateSeparator(
                              label: MessageFormatter.formatDateSeparator(
                                message['date'],
                              ),
                            ),
                            bubble,
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottom,
                    builder: (context, show, child) => AnimatedScale(
                      scale: show ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: FloatingActionButton.small(
                        onPressed: _scrollToBottom,
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                  ),
                ),
                _buildSearchResults(),
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

/// A labelled action in the composer's selection bar.
class _SelectionAction {
  final String label;
  final VoidCallback onPressed;

  const _SelectionAction(this.label, this.onPressed);
}

/// A compact selection toolbar anchored just above the text selection, with its
/// actions in a single horizontally scrolling row so it never overflows.
class _SelectionFormatBar extends StatelessWidget {
  final Offset anchor;
  final double topInset;
  final List<_SelectionAction> items;

  const _SelectionFormatBar({
    required this.anchor,
    required this.topInset,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top =
        (anchor.dy - 54).clamp(topInset + 8, MediaQuery.of(context).size.height);

    return Stack(
      children: [
        Positioned(
          left: 8,
          right: 8,
          top: top,
          child: Center(
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in items)
                      TextButton(
                        onPressed: item.onPressed,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        child: Text(item.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
