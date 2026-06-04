import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/chat_avatar.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// A small circular avatar for a message's sender, shown beside incoming
/// messages in group chats.
///
/// The TDLib message carries only a `senderId`, so the sender (a user or a
/// chat) is resolved via [TDLibClient.getUser] / [TDLibClient.getChat] and its
/// profile photo downloaded on demand, then rendered through [ChatAvatar].
class MessageSenderAvatar extends StatefulWidget {
  final Map<String, dynamic> senderId;
  final double radius;

  const MessageSenderAvatar({
    super.key,
    required this.senderId,
    this.radius = 16,
  });

  @override
  State<MessageSenderAvatar> createState() => _MessageSenderAvatarState();
}

class _MessageSenderAvatarState extends State<MessageSenderAvatar> {
  /// A chat-shaped map ({id, title, photo}) that [ChatAvatar] can render.
  Map<String, dynamic>? _avatarChat;
  StreamSubscription? _fileUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _resolveSender();
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveSender() async {
    final type = widget.senderId['@type'];
    Map<String, dynamic>? avatarChat;

    if (type == 'MessageSenderUser') {
      final userId = widget.senderId['userId'] as int?;
      if (userId == null) return;
      final user = await TDLibClient.getUser(userId: userId);
      if (user == null) return;
      final name = [user['firstName'], user['lastName']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .join(' ');
      avatarChat = {
        'id': userId,
        'title': name,
        'photo': user['profilePhoto'],
      };
    } else if (type == 'MessageSenderChat') {
      final chatId = widget.senderId['chatId'] as int?;
      if (chatId == null) return;
      final chat = await TDLibClient.getChat(chatId: chatId);
      if (chat == null) return;
      avatarChat = {
        'id': chatId,
        'title': chat['title'],
        'photo': chat['photo'],
      };
    } else {
      return;
    }

    if (!mounted) return;
    setState(() => _avatarChat = avatarChat);
    _downloadPhotoIfNeeded();
  }

  /// Requests the small profile photo when it isn't on disk yet, patching the
  /// downloaded file back in once it completes.
  void _downloadPhotoIfNeeded() {
    final small = _avatarChat?['photo']?['small'];
    if (small == null) return;

    final path = small['local']?['path'];
    if (path != null && path.toString().isNotEmpty) return;

    final fileId = small['id'] as int?;
    if (fileId == null) return;

    _fileUpdateSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      if (file['id'] == fileId && mounted) {
        final photo = Map<String, dynamic>.from(_avatarChat!['photo']);
        photo['small'] = file;
        setState(() => _avatarChat = {..._avatarChat!, 'photo': photo});
      }
    });

    TDLibClient.downloadFile(fileId: fileId).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final avatarChat = _avatarChat;
    if (avatarChat == null) {
      return SizedBox(width: widget.radius * 2, height: widget.radius * 2);
    }
    return ChatAvatar(chat: avatarChat, radius: widget.radius);
  }
}
