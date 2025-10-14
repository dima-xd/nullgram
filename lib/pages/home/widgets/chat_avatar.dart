import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ChatAvatar extends StatelessWidget {
  final Map<String, dynamic> chat;
  final double radius;
  final Map<String, bool> fileExistsCache;
  final Map<String, Uint8List?> miniThumbnailCache;

  const ChatAvatar({
    super.key,
    required this.chat,
    required this.radius,
    required this.fileExistsCache,
    required this.miniThumbnailCache,
  });

  @override
  Widget build(BuildContext context) {
    final photo = chat['photo'] as Map<String, dynamic>?;
    final chatId = chat['id'] as int? ?? 0;

    if (photo == null || photo['small'] == null) {
      return _buildDefaultAvatar(chatId);
    }

    final path = photo['small']?['local']?['path'] as String?;
    final minithumbnail = photo['minithumbnail'] as Map<String, dynamic>?;

    if (path == null || path.isEmpty) {
      return _buildDefaultAvatar(chatId);
    }

    if (minithumbnail != null &&
        minithumbnail['data'] != null &&
        !miniThumbnailCache.containsKey(path)) {
      final bytes = (minithumbnail['data'] as List<dynamic>).cast<int>();
      miniThumbnailCache[path] = Uint8List.fromList(bytes);
    }

    if (fileExistsCache.containsKey(path)) {
      final exists = fileExistsCache[path]!;

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
        final cachedThumb = miniThumbnailCache[path];
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

    final cachedThumb = miniThumbnailCache[path];
    if (cachedThumb != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(cachedThumb),
      );
    }

    return _buildPlaceholderAvatar();
  }

  Widget _buildDefaultAvatar(int chatId) {
    final title = chat['title'] as String? ?? '';
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
    if (fileExistsCache.containsKey(path)) return;

    final exists = await File(path).exists();
    fileExistsCache[path] = exists;
  }
}
