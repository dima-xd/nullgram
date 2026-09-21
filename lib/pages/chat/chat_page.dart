import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/scheduled_messages_page.dart';
import 'package:nullgram/pages/chat/thread_page.dart';
import 'package:nullgram/pages/chat/utils/voice_recorder.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/chat/widgets/chat_composer.dart';
import 'package:nullgram/pages/chat/widgets/chat_menu.dart';
import 'package:nullgram/pages/chat/widgets/emoji_status.dart';
import 'package:nullgram/pages/chat/widgets/forward_chat_picker.dart';
import 'package:nullgram/pages/chat/widgets/message_context_menu.dart';
import 'package:nullgram/pages/chat/widgets/message_list_view.dart';
import 'package:nullgram/pages/chat/widgets/auto_delete_sheet.dart';
import 'package:nullgram/pages/chat/widgets/message_info_sheet.dart';
import 'package:nullgram/pages/chat/widgets/message_translation_sheet.dart';
import 'package:nullgram/pages/chat/widgets/poll_composer.dart';
import 'package:nullgram/pages/chat/widgets/send_options_sheet.dart';
import 'package:nullgram/pages/contacts/contacts_page.dart';
import 'package:nullgram/pages/home/widgets/chat_list_item.dart';
import 'package:nullgram/pages/profile/chat_profile_page.dart';
import 'package:nullgram/services/chat_store.dart';
import 'package:nullgram/services/message_history.dart';
import 'package:nullgram/services/notification_service.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/send_options.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/services/call_service.dart';
import 'package:nullgram/widgets/empty_state.dart';
import 'package:video_player/video_player.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/utils/member_count.dart';

/// A single conversation: its history, composer and per-chat actions.
class ChatPage extends StatefulWidget {
  final Map<String, dynamic> chat;

  /// A message to scroll to when the chat opens, used when arriving from
  /// search or a notification.
  final int? initialMessageId;

  const ChatPage({
    super.key,
    required this.chat,
    this.initialMessageId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// The chat's history: paging, de-duplication, album grouping and update
  /// patching all live here rather than in the page.
  late final MessageHistoryController _history = MessageHistoryController(
    source: ChatHistorySource(_chatId),
  );

  final ValueNotifier<bool> _showScrollToBottom = ValueNotifier(false);

  /// The live chat object. Starts as the map the caller handed over and is kept
  /// current from [ChatStore], so the header title, mute state and read
  /// receipts update without leaving the chat.
  late final ValueNotifier<Map<String, dynamic>> _chat =
      ValueNotifier(widget.chat);

  /// Whether the in-chat message search bar is active.
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<List<Map<String, dynamic>>> _searchResults =
      ValueNotifier([]);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// The selected message ids while selection mode is active, or null when it
  /// is off. An empty set still means "selection mode, nothing picked".
  final ValueNotifier<Set<int>?> _selection = ValueNotifier(null);

  /// Pinned messages in this chat, newest first; drives the top pin banner.
  final ValueNotifier<List<Map<String, dynamic>>> _pinnedMessages =
      ValueNotifier([]);

  /// The resolved user behind a private/secret chat, kept live via chat
  /// updates. The TDLib chat object has no embedded user, so it is fetched via
  /// [TDLibClient.getUser] rather than read from `chat['user']`.
  final ValueNotifier<Map<String, dynamic>?> _chatUser = ValueNotifier(null);

  /// The `botCommand` objects offered in this chat, empty when no bot is
  /// involved. Drives the composer's slash button.
  final ValueNotifier<List<Map<String, dynamic>>> _botCommands = ValueNotifier(
    const [],
  );

  /// Whether the peer of a private chat is blocked, for the overflow menu.
  bool _isPeerBlocked = false;

  /// A human-readable activity ("typing…") for the other party, shown in the
  /// header in place of the status, or null when nobody is active.
  final ValueNotifier<String?> _typingAction = ValueNotifier(null);

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

  /// The draft text the chat was opened with, so it is only written back when
  /// the user actually changed it.
  String _initialDraft = '';

  /// The last message read before this visit, which anchors the "unread
  /// messages" divider.
  ///
  /// Snapshotted on open: opening the chat marks everything read, so reading
  /// the live value would move the divider out from under the user.
  late final int _lastReadOnOpen =
      widget.chat['lastReadInboxMessageId'] as int? ?? 0;

  /// Distance (px) from the bottom past which the jump-to-latest button shows
  /// and incoming messages stop auto-scrolling.
  static const double _stickToBottomThreshold = 320;

  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;
  StreamSubscription<Map<String, dynamic>>? _chatSubscription;

  int get _chatId => widget.chat['id'] as int;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (_messageController.text.trim().isNotEmpty) _notifyTyping();
    });

    _scrollController.addListener(_onScroll);

    _messagesSubscription =
        TDLibClient.messsagesUpdates.listen(_onMessageUpdate);
    _chatSubscription = TDLibClient.chatUpdates.listen(_onChatUpdate);
    ChatStore.instance.addListener(_syncChatFromStore);

    _restoreDraft();
    _history.loadLocal();
    _loadPinnedMessages();
    _resolveChatUser();
    _loadBotCommands();

    // Tell TDLib the chat is open so read receipts and channel updates flow.
    TDLibClient.openChat(chatId: _chatId);
    _markReadUpTo(widget.chat['lastMessage']?['id'] as int?);

    // Suppress notifications for the chat currently on screen, and clear any
    // the user is about to read anyway.
    NotificationService.instance.activeChatId = _chatId;
    NotificationService.instance.clear(_chatId);

    final initialMessageId = widget.initialMessageId;
    if (initialMessageId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToMessage(initialMessageId),
      );
    }
  }

  @override
  void dispose() {
    _saveDraft();
    if (NotificationService.instance.activeChatId == _chatId) {
      NotificationService.instance.activeChatId = null;
    }
    TDLibClient.closeChat(chatId: _chatId);
    ChatStore.instance.removeListener(_syncChatFromStore);
    _typingClearTimer?.cancel();
    _typingAction.dispose();
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _history.dispose();
    _showScrollToBottom.dispose();
    _replyTo.dispose();
    _editing.dispose();
    _selection.dispose();
    _isSearching.dispose();
    _searchResults.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _pinnedMessages.dispose();
    _chatUser.dispose();
    _botCommands.dispose();
    _chat.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Updates
  // ---------------------------------------------------------------------------

  /// Mirrors the store's copy of this chat into [_chat].
  void _syncChatFromStore() {
    if (!mounted) return;
    final chat = ChatStore.instance.chat(_chatId);
    if (chat != null) _chat.value = chat;
  }

  Future<void> _onMessageUpdate(Map<String, dynamic> update) async {
    if (!mounted) return;

    final added = _history.applyUpdate(update);

    if (added != null) {
      _maybeStickToBottom(isOutgoing: added['isOutgoing'] == true);
      if (added['isOutgoing'] != true) {
        TDLibClient.viewMessages(
          chatId: _chatId,
          messageIds: [added['id'] as int],
        );
      }
    }

    // The pin banner reads a separate search, so it is refreshed here rather
    // than from the history list.
    if (update['@type'] == updateMessageIsPinnedConst &&
        update['chatId'] == _chatId) {
      _loadPinnedMessages();
    }
  }

  void _onChatUpdate(Map<String, dynamic> update) {
    if (!mounted) return;

    switch (update['@type']) {
      case updateChatActionConst:
        if (update['chatId'] != _chatId) return;
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

      case updateUserConst:
        if (update['user']?['id'] == _chatUserId()) {
          _chatUser.value = Map<String, dynamic>.from(update['user'] as Map);
        }

      case updateUserStatusConst:
        if (update['userId'] == _chatUserId() && _chatUser.value != null) {
          _chatUser.value = {..._chatUser.value!, 'status': update['status']};
        }
    }
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

  /// Throttled outgoing "typing" notification, sent at most once every few
  /// seconds while the user keeps editing the composer.
  void _notifyTyping() {
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastTypingSent = now;
    TDLibClient.sendChatAction(chatId: _chatId);
  }

  /// Marks the chat read up to [messageId] (and all older messages).
  void _markReadUpTo(int? messageId) {
    if (messageId == null) return;
    if ((widget.chat['unreadCount'] as int? ?? 0) == 0) return;
    TDLibClient.viewMessages(chatId: _chatId, messageIds: [messageId]);
  }

  /// The user id behind a private/secret chat, read from the chat's type.
  int? _chatUserId() {
    final type = widget.chat['type'];
    final typeName = type?['@type'];
    if (typeName == 'ChatTypePrivate' || typeName == 'ChatTypeSecret') {
      return type['userId'] as int?;
    }
    return null;
  }

  /// Resolves the chat's user for the header, and its blocked state for the
  /// overflow menu.
  void _resolveChatUser() {
    final userId = _chatUserId();
    if (userId == null) return;

    TDLibClient.getUser(userId: userId).then((user) {
      if (mounted) _chatUser.value = user;
    }).catchError((_) {});

    isUserBlocked(userId).then((blocked) {
      if (mounted) _isPeerBlocked = blocked;
    }).catchError((_) {});
  }

  /// Loads the commands the chat's bots advertise.
  ///
  /// A private chat carries them on the peer's `botInfo`; a group collects one
  /// `botCommands` entry per bot member, which are flattened into one list
  /// because the composer offers them as a single menu.
  Future<void> _loadBotCommands() async {
    final userId = _chatUserId();
    if (userId != null) {
      final botInfo = await TDLibClient.getBotInfo(userId);
      if (!mounted) return;
      _botCommands.value = _commandsFrom(botInfo?['commands']);
      return;
    }

    final type = widget.chat['type'] as Map<String, dynamic>?;
    final fullInfo = switch (type?['@type']) {
      'ChatTypeBasicGroup' => await TDLibClient.getBasicGroupFullInfo(
        basicGroupId: type!['basicGroupId'] as int,
      ),
      'ChatTypeSupergroup' => await TDLibClient.getSupergroupFullInfo(
        supergroupId: type!['supergroupId'] as int,
      ),
      _ => null,
    };
    if (!mounted || fullInfo == null) return;

    _botCommands.value = [
      for (final bot in fullInfo['botCommands'] as List? ?? const [])
        ..._commandsFrom((bot as Map)['commands']),
    ];
  }

  /// Copies a TDLib `botCommand` list into plain maps.
  static List<Map<String, dynamic>> _commandsFrom(dynamic commands) {
    if (commands is! List) return const [];
    return [
      for (final command in commands)
        if (command != null) Map<String, dynamic>.from(command as Map),
    ];
  }

  // ---------------------------------------------------------------------------
  // Drafts
  // ---------------------------------------------------------------------------

  /// Restores the chat's server-side draft into the composer.
  void _restoreDraft() {
    final draft = widget.chat['draftMessage'] as Map<String, dynamic>?;
    final text =
        draft?['inputMessageText']?['text']?['text'] as String? ?? '';
    if (text.isEmpty) return;
    _initialDraft = text;
    _messageController.text = text;
  }

  /// Writes the unsent composer text back as the chat's draft.
  ///
  /// Called on leaving the chat, so the text survives navigation and syncs to
  /// the user's other devices. A pending edit is deliberately not stored: its
  /// text belongs to an existing message, not to a new one.
  void _saveDraft() {
    if (_editing.value != null) return;
    final text = _messageController.text.trim();
    if (text == _initialDraft) return;
    TDLibClient.setChatDraftMessage(
      chatId: _chatId,
      text: text,
      replyToMessageId: _replyTo.value?['id'] as int?,
    );
  }

  // ---------------------------------------------------------------------------
  // Message list bookkeeping
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Message actions
  // ---------------------------------------------------------------------------

  /// Adds or removes [reactionType] on [message]. Mirrors Telegram's
  /// single-reaction behavior: tapping a chosen reaction clears it, while a new
  /// one first removes any currently chosen reactions. The visible state is
  /// refreshed by the resulting `UpdateMessageInteractionInfo`.
  ///
  /// Works on a reaction *type* rather than an emoji string, so custom
  /// (premium) reactions — which have an id and no text form — toggle the same
  /// way as standard ones.
  Future<void> _toggleReaction(
    Map<String, dynamic> message,
    Map<String, dynamic> reactionType,
  ) async {
    final messageId = message['id'] as int;
    final reactions =
        message['interactionInfo']?['reactions']?['reactions'] as List? ??
            const [];

    final chosen = <Map<String, dynamic>>[
      for (final reaction in reactions)
        if (reaction['isChosen'] == true)
          if (reaction['type'] case final Map<String, dynamic> type) type,
    ];
    final tappedKey = TDLibClient.reactionKey(reactionType);

    if (chosen.any((type) => TDLibClient.reactionKey(type) == tappedKey)) {
      await TDLibClient.removeMessageReaction(
        chatId: _chatId,
        messageId: messageId,
        reactionType: reactionType,
      );
      return;
    }

    for (final existing in chosen) {
      await TDLibClient.removeMessageReaction(
        chatId: _chatId,
        messageId: messageId,
        // A response type is PascalCase; requests need lowercase-first.
        reactionType: _asRequestReaction(existing),
      );
    }
    await TDLibClient.addMessageReaction(
      chatId: _chatId,
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  /// Rebuilds a reaction type read off a message into the shape a request
  /// wants, rather than sending the bridge's PascalCase `@type` back at it.
  Map<String, dynamic> _asRequestReaction(Map<String, dynamic> type) {
    final customEmojiId = type['customEmojiId'] as int?;
    if (customEmojiId != null) {
      return TDLibClient.customEmojiReaction(customEmojiId);
    }
    return TDLibClient.emojiReaction(type['emoji'] as String? ?? '');
  }

  /// Opens the long-press context menu and dispatches the chosen action.
  Future<void> _onMessageLongPress(Map<String, dynamic> message) async {
    // While a selection is active, a long press extends it instead of
    // reopening the menu.
    if (_selection.value != null) {
      _toggleSelected(message);
      return;
    }

    HapticFeedback.selectionClick();
    final messageId = message['id'] as int;

    final result = await showMessageContextMenu(
      context: context,
      availableReactions: TDLibClient.getMessageAvailableReactions(
        chatId: _chatId,
        messageId: messageId,
      ),
      canDelete: message['canBeDeletedForAllUsers'] == true ||
          message['canBeDeletedOnlyForSelf'] == true,
      canEdit: message['canBeEdited'] == true,
      canPin: message['canBePinned'] == true,
      isPinned: message['isPinned'] == true,
      // Only a chat with a public username can produce a t.me link.
      canCopyLink: _chat.value['type']?['@type'] == 'ChatTypeSupergroup',
      canTranslate: _messageText(message) != null,
      canSeeInfo: _hasInteractionInfo(message),
    );

    if (result == null || !mounted) return;

    if (result.reactEmoji != null) {
      await _toggleReaction(
        message,
        TDLibClient.emojiReaction(result.reactEmoji!),
      );
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
      case MessageMenuAction.translate:
        await showMessageTranslationSheet(
          context,
          chatId: _chatId,
          messageId: messageId,
        );
      case MessageMenuAction.info:
        await showMessageInfoSheet(
          context,
          chatId: _chatId,
          messageId: messageId,
        );
      case MessageMenuAction.forward:
        await _forwardMessages([messageId]);
      case MessageMenuAction.select:
        _selection.value = {messageId};
      case MessageMenuAction.copyLink:
        await _copyMessageLink(messageId);
      case MessageMenuAction.pin:
        await TDLibClient.pinChatMessage(
          chatId: _chatId,
          messageId: messageId,
        );
        await _loadPinnedMessages();
      case MessageMenuAction.unpin:
        await TDLibClient.unpinChatMessage(
          chatId: _chatId,
          messageId: messageId,
        );
        await _loadPinnedMessages();
      case MessageMenuAction.delete:
        await _deleteMessages([message]);
    }
  }

  /// The plain text of [message], or null when it carries none.
  ///
  /// Both a text message and a captioned photo can be translated, and they
  /// keep their text under different keys.
  static String? _messageText(Map<String, dynamic> message) {
    final content = message['content'] as Map<String, dynamic>?;
    final text =
        content?['text']?['text'] ?? content?['caption']?['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return text;
  }

  /// Whether asking Telegram who reacted to or read [message] can return
  /// anything.
  ///
  /// Reactions are listable whenever the message has any. Read receipts only
  /// exist for one's own messages in a group, so an incoming message with no
  /// reactions would open an empty sheet.
  bool _hasInteractionInfo(Map<String, dynamic> message) {
    final reactions =
        message['interactionInfo']?['reactions']?['reactions'] as List?;
    if (reactions != null && reactions.isNotEmpty) return true;

    final chatType = _chat.value['type']?['@type'] as String?;
    final isGroup =
        chatType == 'ChatTypeBasicGroup' || chatType == 'ChatTypeSupergroup';
    return isGroup && message['isOutgoing'] == true;
  }

  /// Enters edit mode for [message]: prefills the composer with its current
  /// text/caption and focuses the field. Clears any pending reply.
  void _startEditing(Map<String, dynamic> message) {
    final content = message['content'];
    final text =
        content?['text']?['text'] ?? content?['caption']?['text'] ?? '';
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
      _toast('Copied to clipboard');
    }
  }

  /// Copies a public link to the message, when the chat has one.
  Future<void> _copyMessageLink(int messageId) async {
    final link = await TDLibClient.getMessageLink(
      chatId: _chatId,
      messageId: messageId,
    );
    if (!mounted) return;
    if (link == null) {
      _toast('This chat has no public links');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _toast('Link copied');
  }

  /// Picks a destination chat and forwards the given messages into it.
  Future<void> _forwardMessages(List<int> messageIds) async {
    final targetChatId = await showForwardChatPicker(context);
    if (targetChatId == null) return;
    await TDLibClient.forwardMessages(
      chatId: targetChatId,
      fromChatId: _chatId,
      messageIds: messageIds,
    );
    if (mounted) _toast('Forwarded');
  }

  /// Confirms and deletes messages, offering the "for everyone" choice only
  /// when TDLib says every selected message allows it.
  Future<void> _deleteMessages(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;
    final canRevoke =
        messages.every((m) => m['canBeDeletedForAllUsers'] == true);
    final count = messages.length;

    final revoke = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(count == 1 ? 'Delete message?' : 'Delete $count messages?'),
          content: Text(
            canRevoke
                ? 'Choose whether to delete for everyone or only for you.'
                : 'This will only be deleted for you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.deleteForMe),
            ),
            if (canRevoke)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.l10n.forEveryone),
              ),
          ],
        );
      },
    );

    if (revoke == null) return;
    await TDLibClient.deleteMessages(
      chatId: _chatId,
      messageIds: [for (final message in messages) message['id'] as int],
      revoke: revoke,
    );
    _selection.value = null;
  }

  // ---------------------------------------------------------------------------
  // Selection mode
  // ---------------------------------------------------------------------------

  void _toggleSelected(Map<String, dynamic> message) {
    final current = _selection.value;
    if (current == null) return;
    final messageId = message['id'] as int;
    final updated = Set<int>.from(current);
    if (!updated.remove(messageId)) updated.add(messageId);
    _selection.value = updated;
  }

  /// The message objects behind the current selection, albums flattened into
  /// their members.
  List<Map<String, dynamic>> _selectedMessages() {
    final selected = _selection.value ?? const {};
    final result = <Map<String, dynamic>>[];
    for (final entry in _history.messages) {
      if (entry['isAlbum'] == true) {
        for (final member in AlbumsGrouper.membersOf(entry)) {
          if (selected.contains(member['id'])) result.add(member);
        }
      } else if (selected.contains(entry['id'])) {
        result.add(entry);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Search within the chat
  // ---------------------------------------------------------------------------

  void _openSearch() => _isSearching.value = true;

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
      chatId: _chatId,
      query: query,
    );
    if (!mounted) return;
    _searchResults.value = result?.messages ?? const [];
  }

  /// Opens the thread of [message].
  ///
  /// TDLib answers with the thread's own chat, which for a channel post is the
  /// linked discussion supergroup, so that chat is resolved before pushing.
  Future<void> _openThread(Map<String, dynamic> message) async {
    final info = await TDLibClient.getMessageThread(
      chatId: _chatId,
      messageId: message['id'] as int,
    );
    if (!mounted) return;

    if (info == null) {
      _toast(context.l10n.threadUnavailable);
      return;
    }

    final chat = await TDLibClient.getChat(chatId: info['chatId'] as int);
    if (!mounted || chat == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadPage(chat: chat, threadInfo: info),
      ),
    );
  }

  /// Reloads the history window around [messageId] so a search hit becomes
  /// visible, then scrolls to it. Replaces the current message list rather than
  /// scrolling the lazy one, since older messages may not be loaded yet.
  Future<void> _jumpToMessage(int messageId) async {
    _closeSearch();
    await _history.loadWindowAround(messageId);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || _history.messages.isEmpty) return;
      final index = _history.messages.indexWhere((m) => m['id'] == messageId);
      if (index < 0) return;
      final position = _scrollController.position;
      // The list is lazily built, so real item extents aren't known; an
      // average is close enough to bring the target on screen.
      final itemHeight = position.maxScrollExtent / _history.messages.length;
      _scrollController.jumpTo(
        (index * itemHeight).clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  /// Loads the chat's pinned messages (newest first) for the top banner.
  Future<void> _loadPinnedMessages() async {
    final result = await TDLibClient.searchChatMessages(
      chatId: _chatId,
      filter: const {"@type": "searchMessagesFilterPinned"},
    );
    if (!mounted) return;
    _pinnedMessages.value = result?.messages ?? const [];
  }

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage({
    SendOptions options = SendOptions.normal,
  }) async {
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
        chatId: _chatId,
        messageId: editing['id'] as int,
        text: text,
        entities: entities,
      );
      return;
    }

    final replyToMessageId = _replyTo.value?['id'] as int?;
    _messageController.clear();
    _replyTo.value = null;
    // The composer is empty now, so a stored draft would be stale.
    _initialDraft = '';
    await TDLibClient.setChatDraftMessage(chatId: _chatId, text: '');
    await TDLibClient.sendMessage(
      chatId: _chatId,
      text: text,
      replyToMessageId: replyToMessageId,
      entities: entities,
      options: options,
    );
    if (mounted && options.isScheduled) _toast('Message scheduled');
  }

  /// Offers silent and scheduled delivery for the message being composed.
  Future<void> _sendWithOptions() async {
    if (_messageController.text.trim().isEmpty) return;
    // Editing rewrites an existing message, which has no delivery to schedule.
    if (_editing.value != null) return;

    final options = await showSendOptionsSheet(
      context: context,
      isPrivateChat: _chatUserId() != null,
    );
    if (options == null || !mounted) return;
    await _sendMessage(options: options);
  }

  Future<void> _onVoiceRecorded(VoiceRecording? recording) async {
    if (recording == null) return;
    final replyToMessageId = _replyTo.value?['id'] as int?;
    _replyTo.value = null;
    await TDLibClient.sendVoiceNote(
      chatId: _chatId,
      path: recording.path,
      duration: recording.duration,
      waveform: recording.waveform,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> _onStickerPicked(int fileId) async {
    final replyToMessageId = _replyTo.value?['id'] as int?;
    _replyTo.value = null;
    await TDLibClient.sendSticker(
      chatId: _chatId,
      fileId: fileId,
      replyToMessageId: replyToMessageId,
    );
    await TDLibClient.addRecentSticker(fileId: fileId);
  }

  Future<void> _onGifPicked(int fileId) async {
    final replyToMessageId = _replyTo.value?['id'] as int?;
    _replyTo.value = null;
    await TDLibClient.sendAnimation(
      chatId: _chatId,
      fileId: fileId,
      replyToMessageId: replyToMessageId,
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
        title: Text(context.l10n.addLink),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://abuchi.lol'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    _wrapSelection('[', ']($url)');
  }

  /// Shows the attach options and sends the picked content, using any composer
  /// text as its caption.
  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.photos),
              subtitle: Text(context.l10n.sendAsAlbumHint),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendPhotos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.camera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(isVideo: false, fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(context.l10n.video),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_camera_front_outlined),
              title: Text(context.l10n.videoMessage),
              subtitle: Text(context.l10n.videoMessageHint),
              onTap: () {
                Navigator.pop(sheetContext);
                _recordAndSendVideoNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(context.l10n.document),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outlined),
              title: Text(context.l10n.contact),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendContact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: Text(context.l10n.poll),
              onTap: () {
                Navigator.pop(sheetContext);
                _createPoll();
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

  /// Picks any number of photos and sends them, grouping several into one
  /// album rather than a run of separate messages.
  Future<void> _pickAndSendPhotos() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;

    final composer = _consumeComposer();
    if (files.length == 1) {
      await TDLibClient.sendPhoto(
        chatId: _chatId,
        path: files.single.path,
        caption: composer.caption,
        replyToMessageId: composer.replyToMessageId,
      );
      return;
    }

    await TDLibClient.sendMediaAlbum(
      chatId: _chatId,
      items: [
        for (final file in files) (path: file.path, isVideo: false),
      ],
      caption: composer.caption,
      replyToMessageId: composer.replyToMessageId,
    );
  }

  Future<void> _pickAndSendImage({
    required bool isVideo,
    bool fromCamera = false,
  }) async {
    final picker = ImagePicker();
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final file = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);
    if (file == null) return;

    final composer = _consumeComposer();
    if (isVideo) {
      await TDLibClient.sendVideo(
        chatId: _chatId,
        path: file.path,
        caption: composer.caption,
        replyToMessageId: composer.replyToMessageId,
      );
    } else {
      await TDLibClient.sendPhoto(
        chatId: _chatId,
        path: file.path,
        caption: composer.caption,
        replyToMessageId: composer.replyToMessageId,
      );
    }
  }

  /// Records a round video message with the front camera and sends it.
  ///
  /// Telegram records these inline; the system camera is used here instead,
  /// which produces the same `inputMessageVideoNote` without shipping a
  /// preview pipeline.
  Future<void> _recordAndSendVideoNote() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxDuration: const Duration(minutes: 1),
    );
    if (file == null) return;

    final duration = await _videoDuration(file.path);
    final replyToMessageId = _replyTo.value?['id'] as int?;
    _replyTo.value = null;

    await TDLibClient.sendVideoNote(
      chatId: _chatId,
      path: file.path,
      duration: duration,
      replyToMessageId: replyToMessageId,
    );
  }

  /// Reads a local video's length in seconds.
  ///
  /// TDLib wants the duration up front and won't probe the file itself, so the
  /// video player is used purely to read the metadata. Falls back to zero,
  /// which TDLib accepts.
  Future<int> _videoDuration(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration.inSeconds;
    } catch (e) {
      logger.w('Could not read the video duration: $e');
      return 0;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;

    final composer = _consumeComposer();
    await TDLibClient.sendDocument(
      chatId: _chatId,
      path: path,
      caption: composer.caption,
      replyToMessageId: composer.replyToMessageId,
    );
  }

  /// Picks one of the user's Telegram contacts and shares them as a card.
  Future<void> _pickAndSendContact() async {
    final picked = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsPage(
          selectable: true,
          title: context.l10n.shareAContact,
        ),
      ),
    );
    final userId = picked?.firstOrNull;
    if (userId == null) return;

    final user = await TDLibClient.getUser(userId: userId);
    if (!mounted || user == null) return;

    final replyToMessageId = _replyTo.value?['id'] as int?;
    _replyTo.value = null;
    await TDLibClient.sendContact(
      chatId: _chatId,
      userId: userId,
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      phoneNumber: user['phoneNumber'] as String? ?? '',
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> _createPoll() async {
    final poll = await showPollComposer(context);
    if (poll == null) return;
    await TDLibClient.sendPoll(
      chatId: _chatId,
      question: poll.question,
      options: poll.options,
      isAnonymous: poll.isAnonymous,
      allowMultipleAnswers: poll.allowMultipleAnswers,
    );
  }

  // ---------------------------------------------------------------------------
  // Chat-level actions
  // ---------------------------------------------------------------------------

  /// Places an outgoing voice call to the private chat's peer.
  Future<void> _startVoiceCall() async {
    final userId = _chatUserId();
    if (userId == null) {
      _toast('Calls are available in private chats only');
      return;
    }
    final started =
        await callService.startCall(userId: userId, isVideo: false);
    if (!mounted || started) return;
    _toast(context.l10n.microphonePermissionRequired);
  }

  /// Places an outgoing video call to the private chat's peer.
  Future<void> _startVideoCall() async {
    final userId = _chatUserId();
    if (userId == null) {
      _toast('Calls are available in private chats only');
      return;
    }
    final started = await callService.startCall(userId: userId, isVideo: true);
    if (!mounted || started) return;
    _toast(context.l10n.cameraAccessDenied);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatProfilePage(chat: _chatWithUser()),
      ),
    );
  }

  Map<String, dynamic> _chatWithUser() {
    final user = _chatUser.value;
    return user == null ? _chat.value : {..._chat.value, 'user': user};
  }

  /// Asks for a new self-destruct timer and applies it.
  Future<void> _setAutoDeleteTime() async {
    final current =
        (_chat.value['messageAutoDeleteTime'] as num?)?.toInt() ?? 0;
    final seconds = await showAutoDeleteSheet(context, currentSeconds: current);
    if (seconds == null || seconds == current) return;

    await TDLibClient.setChatMessageAutoDeleteTime(
      chatId: _chatId,
      autoDeleteTime: seconds,
    );
  }

  Future<void> _openChatMenu() async {
    final action = await showChatMenu(
      context: context,
      chat: _chat.value,
      isBlocked: _isPeerBlocked,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case ChatMenuAction.openProfile:
        _openProfile();
      case ChatMenuAction.search:
        _openSearch();
      case ChatMenuAction.videoCall:
        await _startVideoCall();
      case ChatMenuAction.selectMessages:
        _selection.value = const {};
      case ChatMenuAction.autoDelete:
        await _setAutoDeleteTime();
      case ChatMenuAction.scheduledMessages:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScheduledMessagesPage(chat: _chat.value),
          ),
        );
      case ChatMenuAction.toggleMute:
        await TDLibClient.setChatNotificationSettings(
          chatId: _chatId,
          muteFor: isChatMuted(_chat.value) ? 0 : TDLibClient.muteForever,
        );
      case ChatMenuAction.clearHistory:
        if (await _confirm('Clear history?', 'Clear')) {
          await TDLibClient.deleteChatHistory(chatId: _chatId);
          if (mounted) _history.clear();
        }
      case ChatMenuAction.toggleBlock:
        final userId = _chatUserId();
        if (userId == null) return;
        await TDLibClient.setUserBlocked(
          userId: userId,
          blocked: !_isPeerBlocked,
        );
        if (!mounted) return;
        setState(() => _isPeerBlocked = !_isPeerBlocked);
        _toast(_isPeerBlocked ? 'User blocked' : 'User unblocked');
      case ChatMenuAction.deleteChat:
        if (await _confirm('Delete chat?', 'Delete')) {
          await TDLibClient.deleteChatHistory(
            chatId: _chatId,
            removeFromChatList: true,
          );
          if (mounted) Navigator.pop(context);
        }
      case ChatMenuAction.leaveChat:
        if (await _confirm('Leave chat?', 'Leave')) {
          await TDLibClient.leaveChat(chatId: _chatId);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  Future<bool> _confirm(String title, String action) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(context.l10n.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>?>(
      valueListenable: _selection,
      builder: (context, selection, child) {
        // Selection mode owns the back gesture: it should clear the selection
        // rather than leave the chat.
        return PopScope(
          canPop: selection == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selection.value = null;
          },
          child: Scaffold(
            appBar: _buildAppBar(selection),
            body: Column(
              children: [
                _buildPinnedBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      MessageListView(
                        history: _history,
                        chat: _chat.value,
                        scrollController: _scrollController,
                        selection: selection,
                        lastReadOnOpen: _lastReadOnOpen,
                        callbacks: MessageListCallbacks(
                          onLongPress: _onMessageLongPress,
                          onTap: _toggleSelected,
                          onReactionTap: _toggleReaction,
                          onReplyTap: _jumpToMessage,
                          onThreadTap: _openThread,
                        ),
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
                _buildComposer(selection),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(Set<int>? selection) {
    if (selection != null) return _buildSelectionAppBar(selection);

    return PreferredSize(
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
                decoration: InputDecoration(
                  hintText: context.l10n.searchMessagesHint,
                  border: InputBorder.none,
                ),
              ),
            );
          }
          return AppBar(
            titleSpacing: 0,
            title: _buildHeader(),
            // Two actions at most: every further icon eats the title, which
            // on a phone leaves names and statuses truncated mid-word. Search
            // and the video call live in the overflow menu instead.
            actions: [
              if (_chatUserId() != null)
                IconButton(
                  icon: const Icon(Icons.call),
                  tooltip: context.l10n.call,
                  onPressed: _startVoiceCall,
                ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: context.l10n.more,
                onPressed: _openChatMenu,
              ),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildSelectionAppBar(Set<int> selection) {
    final count = selection.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.cancel,
        onPressed: () => _selection.value = null,
      ),
      title: Text(count == 0 ? 'Select messages' : '$count selected'),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: context.l10n.copy,
          onPressed: count == 0
              ? null
              : () {
                  final text = _selectedMessages()
                      .map(messagePreviewText)
                      .where((line) => line.isNotEmpty)
                      .join('\n');
                  if (text.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: text));
                  _selection.value = null;
                  _toast('Copied to clipboard');
                },
        ),
        IconButton(
          icon: const Icon(Icons.forward),
          tooltip: context.l10n.forward,
          onPressed: count == 0
              ? null
              : () async {
                  final ids = selection.toList();
                  _selection.value = null;
                  await _forwardMessages(ids);
                },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: context.l10n.delete,
          onPressed: count == 0 ? null : () => _deleteMessages(_selectedMessages()),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _chat,
      builder: (context, chat, child) {
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: _chatUser,
          builder: (context, user, child) {
            // Merge the resolved user into the chat so the avatar's
            // online/bot indicator and the profile screen see it; the TDLib
            // chat object itself carries no user.
            final chatWithUser = user == null ? chat : {...chat, 'user': user};
            return InkWell(
              onTap: _openProfile,
              child: Row(
                children: [
                  Hero(
                    tag: 'chat_avatar_$_chatId',
                    child: ChatAvatar(chat: chatWithUser, radius: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (chat['type']?['@type'] == 'ChatTypeSecret')
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                chat['title'] as String? ?? 'Chat',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            EmojiStatusBadge(chat: chatWithUser),
                            if (isChatMuted(chat))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.volume_off,
                                  size: 15,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        _buildHeaderSubtitle(chat, user),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderSubtitle(
    Map<String, dynamic> chat,
    Map<String, dynamic>? user,
  ) {
    return ValueListenableBuilder<String?>(
      valueListenable: _typingAction,
      builder: (context, typing, child) {
        final scheme = Theme.of(context).colorScheme;
        if (typing != null) {
          return Text(
            typing,
            style: TextStyle(fontSize: 13, color: scheme.primary),
          );
        }
        final mutedStyle =
            TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
        if (user != null) {
          return Text(
            MessageFormatter.getUserStatus(user),
            style: mutedStyle,
          );
        }
        final supergroup = chat['supergroup'];
        if (supergroup != null) {
          return Text(
            memberCountLabel(
              context,
              supergroup['memberCount'] as int? ?? 0,
              isChannel: supergroup['isChannel'] == true,
            ),
            style: mutedStyle,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildComposer(Set<int>? selection) {
    // Selection mode replaces the composer with its action bar in the app bar,
    // so nothing is offered here.
    if (selection != null) {
      return SizedBox(height: MediaQuery.paddingOf(context).bottom);
    }

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: _chat,
      builder: (context, chat, child) {
        final canSend =
            chat['permissions']?['canSendBasicMessages'] as bool? ?? true;
        if (!canSend) {
          // No composer for channels/restricted chats. Still reserve the
          // bottom safe-area inset so the newest messages don't slide under
          // the OS navigation buttons.
          return SizedBox(height: MediaQuery.paddingOf(context).bottom);
        }
        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _botCommands,
          builder: (context, botCommands, child) => ChatComposer(
            botCommands: botCommands,
            controller: _messageController,
          focusNode: _messageFocusNode,
          replyTo: _replyTo,
          editing: _editing,
          onSend: _sendMessage,
          onSendOptions: _sendWithOptions,
          onVoice: _onVoiceRecorded,
          onSticker: _onStickerPicked,
          onGif: _onGifPicked,
          onAttach: _showAttachMenu,
            onFormat: _wrapSelection,
            onInsertLink: _insertLink,
          ),
        );
      },
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

        return InkWell(
          onTap: () => _jumpToMessage(message['id'] as int),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom:
                    BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
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
                        messagePreviewText(message),
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
                      ? EmptyState(
                          icon: Icons.search,
                          title: context.l10n.searchMessages,
                          subtitle: context.l10n.searchInChatHint,
                        )
                      : EmptyState(
                          icon: Icons.search_off,
                          title: context.l10n.noMessagesFound,
                        );
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final message = results[index];
                    return ListTile(
                      title: Text(
                        messagePreviewText(message),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        MessageFormatter.formatDateSeparator(
                          message['date'] as int,
                        ),
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
}

