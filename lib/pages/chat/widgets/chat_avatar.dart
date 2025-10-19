import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

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
    Widget avatarWidget = _buildAvatarWidget();
    
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

  Widget _buildAvatarWidget() {
    final photo = chat['photo'];
    final chatId = chat['id'] ?? 0;

    if (photo == null || photo['small'] == null) {
      return _buildDefaultAvatar(chatId);
    }

    final path = photo['small']?['local']?['path'];
    final minithumbnail = photo['minithumbnail'];

    if (path == null || path.isEmpty) {
      return _buildDefaultAvatar(chatId);
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
          return _buildPlaceholderAvatar();
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

      return _buildPlaceholderAvatar();
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
        color: Colors.green,
      );
    }
    
    return null;
  }

  Widget _buildDefaultAvatar(int chatId) {
    final title = chat['title'] ?? '';
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
    ];
    final color = colors[chatId.abs() % colors.length];

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

  Widget _buildPlaceholderAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, color: Colors.white54, size: radius),
    );
  }

  Future<void> _checkFileExists(String path) async {
    if (fileExistsCache == null || fileExistsCache!.containsKey(path)) return;

    final exists = await File(path).exists();
    fileExistsCache![path] = exists;
  }
}
