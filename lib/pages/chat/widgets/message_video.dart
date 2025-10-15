import 'dart:io';
import 'package:flutter/material.dart';

class MessageVideo extends StatelessWidget {
  final Map<String, dynamic> content;

  const MessageVideo({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final video = content['video'];
    final thumbnail = video['thumbnail'];

    String? thumbnailPath;
    if (thumbnail != null) {
      final local = thumbnail['file']?['local'];
      if (local != null && local['isDownloadingCompleted'] == true) {
        thumbnailPath = local['path'];
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumbnailPath != null && thumbnailPath.isNotEmpty
              ? Image.file(
            File(thumbnailPath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
          )
              : Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.video_library, size: 48),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }
}
