import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/theme/app_theme.dart';

class ChatAvatar extends StatelessWidget {
  final Map<String, dynamic> chat;
  final double radius;
  final Map<String, bool>? fileExistsCache;
  final Map<String, Uint8List?>? miniThumbnailCache;

  const ChatAvatar({
    super.key,
    required this.chat,
    this.radius = 20,
    this.fileExistsCache,
    this.miniThumbnailCache,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget = _buildAvatarWidget(context);

    Widget? statusIcon = _getStatusIcon(context);
    
    if (statusIcon != null) {
      return Stack(
        children: [
          avatarWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1,
                ),
              ),
              child: statusIcon,
            ),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarWidget(BuildContext context) {
    final photo = chat['photo'];
    final chatId = chat['id'] ?? 0;

    if (photo == null || photo['small'] == null) {
      return _buildDefaultAvatar(context, chatId);
    }

    final path = photo['small']?['local']?['path'];
    final minithumbnail = photo['minithumbnail'];

    if (path == null || path.isEmpty) {
      return _buildDefaultAvatar(context, chatId);
    }

    if (fileExistsCache != null && miniThumbnailCache != null) {
      if (minithumbnail != null &&
          minithumbnail['data'] != null &&
          !miniThumbnailCache!.containsKey(path)) {
        final bytes = (minithumbnail['data'] as List<dynamic>).cast<int>();
        miniThumbnailCache![path] = Uint8List.fromList(bytes);
      }

      if (fileExistsCache!.containsKey(path)) {
        final exists = fileExistsCache![path]!;

        if (exists) {
          final size = radius * 2;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: FileImage(File(path)),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          final cachedThumb = miniThumbnailCache![path];
          if (cachedThumb != null) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: MemoryImage(cachedThumb),
            );
          }
          return _buildPlaceholderAvatar(context);
        }
      }

      _checkFileExists(path);

      final cachedThumb = miniThumbnailCache![path];
      if (cachedThumb != null) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(cachedThumb),
        );
      }

      return _buildPlaceholderAvatar(context);
    } else {
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
  }

  Widget? _getStatusIcon(BuildContext context) {
    if (chat['user']?['type']?['@type'] == 'UserTypeBot') {
      return Icon(
        Icons.smart_toy,
        size: radius * 0.4,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    
    if (chat['user']?['status']?['@type'] == 'UserStatusOnline') {
      return Icon(
        Icons.circle,
        size: radius * 0.4,
        color: context.chatColors.onlineDot,
      );
    }
    
    return null;
  }

  Widget _buildDefaultAvatar(BuildContext context, int chatId) {
    final title = chat['title'] ?? '';
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final colors = context.chatColors.avatarColors(chatId);

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.background,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: colors.foreground,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.person, color: scheme.onSurfaceVariant, size: radius),
    );
  }

  Future<void> _checkFileExists(String path) async {
    if (fileExistsCache == null || fileExistsCache!.containsKey(path)) return;

    final exists = await File(path).exists();
    fileExistsCache![path] = exists;
  }
}
