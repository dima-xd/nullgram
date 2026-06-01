import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nullgram/pages/chat/utils/albums_grouper.dart';
import 'package:nullgram/pages/chat/utils/message_formatter.dart';
import 'package:nullgram/pages/chat/widgets/album_bubble.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/pages/chat/widgets/date_separator.dart';
import 'package:nullgram/pages/chat/widgets/message_bubble.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
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
      }
    });

    _loadLocalMessages();
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await TDLibClient.sendMessage(chatId: widget.chat['id'], text: text);
  }

  Widget _buildMessageInput() {
    final canSendBasicMessages = widget.chat['permissions']?['canSendBasicMessages'] ?? true;

    if (!canSendBasicMessages) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
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
                    onTap: () {},
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
              // Non-empty text turns the trailing button into a send button;
              // an empty field falls back to the audio/video recorder.
              if (text.trim().isNotEmpty) {
                return GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<bool>(
                valueListenable: _isAudioMode,
                builder: (context, isAudioMode, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _isRecording,
                    builder: (context, isRecording, child) {
                      return GestureDetector(
                        onTap: () {
                          if (_isAudioMode.value && _isRecording.value) {
                            stopAudioRecording();
                            return;
                          } else if (!_isAudioMode.value && _isRecording.value) {
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
                            color: isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              isAudioMode
                                  ? (isRecording ? Icons.mic : Icons.mic_none)
                                  : Icons.videocam,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          )
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        const double minSwipeVelocity = 300.0;
        if (details.primaryVelocity != null && 
            details.primaryVelocity! > minSwipeVelocity) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {},
          child: Row(
            children: [
              ChatAvatar(chat: widget.chat, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat['title'] ?? 'Chat',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.chat['user'] != null)
                      Text(
                        MessageFormatter.getUserStatus(widget.chat['user']!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    if (widget.chat['supergroup'] != null)
                      Text(
                        "${NumberFormat('#,###', 'en_US').format(widget.chat['supergroup']['memberCount'] ?? 0)} subscribers",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
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
                      return const Center(child: Text('No messages yet'));
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
                              child: Text(
                                'Loading older messages',
                                style: TextStyle(color: Colors.grey),
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
                              )
                            : MessageBubble(
                                message: message,
                                chat: widget.chat,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
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
              ],
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    ));
  }
}
