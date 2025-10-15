import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/message_audio.dart';
import 'package:nullgram/pages/chat/widgets/message_photo.dart';
import 'package:nullgram/pages/chat/widgets/message_text.dart';
import 'package:nullgram/pages/chat/widgets/message_video.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import '../../tdlib/models/chat.dart';

class ChatPage extends StatefulWidget {
  final Chat chat;

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
  final ValueNotifier<bool> _isRecordingAudio = ValueNotifier(true);
  final ValueNotifier<String> _messageText = ValueNotifier('');

  final ValueNotifier<List<Map<String, dynamic>>> _messages = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<bool> _hasMore = ValueNotifier(true);

  static const int _batchSize = 50;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      _messageText.value = _messageController.text;
    });

    TDLibClient.messsagesUpdates.listen((update) async {
      final type = update['@type'];
      switch (type) {
        case updateNewMessageConst:
          final message = update['message'];
          if (message['chatId'] == widget.chat.id) {
            _messages.value = _groupMediaAlbums([message, ..._messages.value]);
            setState(() {});
          }
          break;
      }
    });

    _loadLocalMessages();
  }

  Future<void> _loadLocalMessages() async {
    try {
      while (true) {
        if (!mounted) return;
        _isLoading.value = true;
        final fromId = _messages.value.isEmpty ? 0 : _messages.value.last['id'];

        final localMessages = await TDLibClient.getChatHistory(
          chatId: widget.chat.id!,
          fromMessageId: fromId,
          offset: 0,
          limit: _batchSize * 2,
          onlyLocal: true,
        );

        if (!mounted) return;

        if (localMessages != null && localMessages.messages.isNotEmpty) {
          _messages.value = _groupMediaAlbums([..._messages.value, ...localMessages.messages]);
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
      chatId: widget.chat.id!,
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

    final pos = _scrollController.position;
    final firstVisibleIndex = (_messages.value.isNotEmpty && pos.maxScrollExtent > 0)
        ? (pos.pixels / (pos.maxScrollExtent / _messages.value.length)).round().clamp(0, _messages.value.length - 1)
        : 0;

    _messages.value = _groupMediaAlbums([..._messages.value, ...messages.messages]);

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
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _isRecordingAudio.dispose();
    _messageText.dispose();
    _messages.dispose();
    _isLoading.dispose();
    _hasMore.dispose();
    super.dispose();
  }

  Widget _buildAvatar({double radius = 20}) {
    final chat = widget.chat;

    if (chat.photo?.small == null) {
      final firstLetter = chat.title!.isNotEmpty ? chat.title![0].toUpperCase() : '?';
      final colors = [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.indigo,
        Colors.purple,
      ];
      final color = colors[chat.id!.abs() % colors.length];

      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Text(
          firstLetter,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final path = chat.photo?.small.local.path;
    if (path != null && path.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: FileImage(File(path)),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: radius,
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isOutgoing = message['isOutgoing'] ?? false;
    final content = message['content'];
    final contentType = content['@type'];
    final hasCaption = content['caption']?['text'] != null &&
        content['caption']['text'].toString().isNotEmpty;

    final hasMedia = contentType == 'MessagePhoto' ||
        contentType == 'MessageVideo' ||
        contentType == 'MessageAudio';

    if (hasMedia && !hasCaption) {
      return Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildMediaContent(content, message['id']),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildTimeRow(message, isOutgoing),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: _buildMediaContent(content, message['id']),
              ),
            if (hasMedia)
              Container(
                constraints: const BoxConstraints(minWidth: double.infinity),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isOutgoing
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MessageText(content: content['caption']),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildTimeRow(message, isOutgoing),
                    ),
                  ],
                ),
              )
            else
              IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contentType == 'MessageText')
                        MessageText(content: content['text']),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildTimeRow(message, isOutgoing),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupMediaAlbums(List<Map<String, dynamic>> messages) {
    final result = <Map<String, dynamic>>[];
    final albumMap = <int, List<Map<String, dynamic>>>{};
    final albumIndices = <int, int>{};

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final mediaAlbumId = message['mediaAlbumId'] as int?;

      if (mediaAlbumId != null && mediaAlbumId != 0) {
        albumMap.putIfAbsent(mediaAlbumId, () => []).add(message);
        if (!albumIndices.containsKey(mediaAlbumId)) {
          albumIndices[mediaAlbumId] = i;
        }
      }
    }

    for (final albumMessages in albumMap.values) {
      albumMessages.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    }

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final mediaAlbumId = message['mediaAlbumId'] as int?;

      if (mediaAlbumId != null && mediaAlbumId != 0) {
        if (albumIndices[mediaAlbumId] == i) {
          final albumMessages = albumMap[mediaAlbumId]!;
          if (albumMessages.length > 1) {
            result.add({
              'isAlbum': true,
              'messages': albumMessages,
              'isOutgoing': albumMessages.first['isOutgoing'],
              'date': albumMessages.first['date'],
              'id': albumMessages.first['id'],
              'mediaAlbumId': mediaAlbumId,
            });
          } else {
            result.add(albumMessages.first);
          }
        }
      } else {
        result.add(message);
      }
    }

    return result;
  }

  Widget _buildAlbum(List<Map<String, dynamic>> albumMessages) {
    final isOutgoing = albumMessages.first['isOutgoing'] ?? false;
    final messageCount = albumMessages.length;

    final firstContent = albumMessages.first['content'];
    final hasCaption = firstContent['caption']?['text'] != null &&
        firstContent['caption']['text'].toString().isNotEmpty;

    int crossAxisCount;
    if (messageCount == 1) {
      crossAxisCount = 1;
    } else if (messageCount == 2 || messageCount == 4) {
      crossAxisCount = 2;
    } else if (messageCount == 3) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    if (hasCaption) {
      return Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: messageCount,
                    itemBuilder: (context, index) {
                      final message = albumMessages[index];
                      final content = message['content'];
                      return _buildMediaContent(content, message['id']);
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                child: Container(
                  constraints: const BoxConstraints(minWidth: double.infinity),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MessageText(content: firstContent['caption']),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildTimeRow(albumMessages.first, isOutgoing),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                itemCount: messageCount,
                itemBuilder: (context, index) {
                  final message = albumMessages[index];
                  final content = message['content'];
                  return _buildMediaContent(content, message['id']);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildTimeRow(albumMessages.first, isOutgoing),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(Map<String, dynamic> content, int messageId) {
    final contentType = content['@type'];

    switch (contentType) {
      case 'MessagePhoto':
        return MessagePhoto(content: content, messageId: messageId);
      case 'MessageVideo':
        return MessageVideo(content: content);
      case 'MessageAudio':
        return MessageAudio(content: content);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeRow(Map<String, dynamic> message, bool isOutgoing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message['date']!),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        if (isOutgoing) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageInput() {
    return Container(
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
              if (text.trim().isEmpty) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _isRecordingAudio,
                  builder: (context, isRecording, child) {
                    return InkWell(
                      onTap: () {
                        _isRecordingAudio.value = !isRecording;
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRecording ? Icons.mic : Icons.videocam,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                );
              }

              return InkWell(
                onTap: () async {
                  final messageText = text.trim();
                  if (messageText.isNotEmpty) {
                    await TDLibClient.sendMessage(
                      chatId: widget.chat.id!,
                      text: messageText,
                    );
                    _messageController.clear();
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {},
          child: Row(
            children: [
              _buildAvatar(radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat.title ?? 'Chat',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'last seen recently',
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
            child: ValueListenableBuilder(
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

                        if (message['isAlbum'] == true) {
                          return _buildAlbum(message['messages']);
                        }

                        return _buildMessage(message);
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
