import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nullgram/services/avatar_cache.dart';
import 'package:nullgram/tdlib/td_bytes.dart';
import 'package:nullgram/theme/app_theme.dart';

/// A chat's round avatar: its photo when downloaded, its blurred
/// minithumbnail while the photo is still on its way, and a colored initial
/// when the chat has no photo at all.
class ChatAvatar extends StatefulWidget {
  final Map<String, dynamic> chat;
  final double radius;

  const ChatAvatar({
    super.key,
    required this.chat,
    this.radius = 20,
  });

  @override
  State<ChatAvatar> createState() => _ChatAvatarState();
}

class _ChatAvatarState extends State<ChatAvatar> {
  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar(context);
    final statusIcon = _statusIcon(context);
    if (statusIcon == null) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: widget.radius * 0.6,
            height: widget.radius * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
            child: statusIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final photo = widget.chat['photo'];
    final path = photo?['small']?['local']?['path'] as String?;

    if (path == null || path.isEmpty) return _defaultAvatar(context);

    _cacheMiniThumbnail(photo, path);

    final exists = AvatarCache.fileExists[path];
    if (exists == null) {
      // Not checked yet: show the best placeholder we have and rebuild once
      // the check lands, so the real photo appears without waiting for an
      // unrelated rebuild to happen to come along.
      _checkFileExists(path);
      return _thumbnailOrPlaceholder(context, path);
    }
    if (!exists) return _thumbnailOrPlaceholder(context, path);

    final size = widget.radius * 2;
    return Container(
      width: size,
      height: size,
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

  void _cacheMiniThumbnail(dynamic photo, String path) {
    if (AvatarCache.miniThumbnails.containsKey(path)) return;
    AvatarCache.miniThumbnails[path] =
        TdBytes.decode(photo?['minithumbnail']?['data']);
  }

  Widget _thumbnailOrPlaceholder(BuildContext context, String path) {
    final thumbnail = AvatarCache.miniThumbnails[path];
    if (thumbnail != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: MemoryImage(thumbnail),
      );
    }
    return _defaultAvatar(context);
  }

  Widget? _statusIcon(BuildContext context) {
    final user = widget.chat['user'];
    if (user?['type']?['@type'] == 'UserTypeBot') {
      return Icon(
        Icons.smart_toy,
        size: widget.radius * 0.4,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    if (user?['status']?['@type'] == 'UserStatusOnline') {
      return Icon(
        Icons.circle,
        size: widget.radius * 0.4,
        color: context.chatColors.onlineDot,
      );
    }
    return null;
  }

  Widget _defaultAvatar(BuildContext context) {
    final chatId = widget.chat['id'] as int? ?? 0;
    final title = widget.chat['title'] as String? ?? '';
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final colors = context.chatColors.avatarColors(chatId);

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: colors.background,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: colors.foreground,
          fontSize: widget.radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _checkFileExists(String path) async {
    final exists = await File(path).exists();
    AvatarCache.fileExists[path] = exists;
    if (mounted && exists) setState(() {});
  }
}
