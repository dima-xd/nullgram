import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

import 'image_details.dart';

class MessagePhoto extends StatefulWidget {
  final Map<String, dynamic> content;
  final int messageId;

  const MessagePhoto({
    super.key,
    required this.content,
    required this.messageId,
  });

  @override
  State<MessagePhoto> createState() => _MessagePhotoState();
}

class _MessagePhotoState extends State<MessagePhoto> {
  final ValueNotifier<bool> _isDownloading = ValueNotifier(false);
  StreamSubscription? _fileUpdateSubscription;

  @override
  void initState() {
    super.initState();

    _fileUpdateSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] == updateFileConst) {
        final file = update['file'];
        final fileId = file['id'];
        final currentFileId = _getPhotoFileId();

        if (fileId == currentFileId) {
          if (mounted) {
            widget.content['photo']['sizes'].last['photo'] = file;
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    _isDownloading.dispose();
    super.dispose();
  }

  String? _getPhotoPath() {
    final photo = widget.content['photo'];

    final size = _getPhotoContent(photo);
    if (size != null) {
      final local = size['photo']?['local'];
      if (local != null && local['isDownloadingCompleted'] == true) {
        return local['path'];
      }
    }
    return null;
  }

  dynamic _getPhotoContent(dynamic photo) {
    final sizes = photo['sizes'] as List;
    return sizes.last;
  }

  List<int>? _getMiniThumbnailBytes() {
    final photo = widget.content['photo'];
    final data = photo['minithumbnail']?['data'];
    if (data is List) {
      return data.cast<int>();
    }
    return null;
  }

  int? _getPhotoFileId() {
    final photo = widget.content['photo'];
    final size = _getPhotoContent(photo);
    if (size != null) {
      final fileId = size['photo']['id'];
      return fileId;
    }
    return null;
  }

  Future<void> _downloadPhoto() async {
    final fileId = _getPhotoFileId();
    if (fileId == null) return;

    _isDownloading.value = true;

    try {
      await TDLibClient.downloadFile(fileId: fileId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        _isDownloading.value = false;
      }
    }
  }

  bool _isFileDownloading() {
    final photo = widget.content['photo'];
    final size = _getPhotoContent(photo);
    if (size != null) {
      final local = size['photo']?['local'];
      if (local != null && local['isDownloadingActive'] == true) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = _getPhotoPath();
    final miniThumbnail = _getMiniThumbnailBytes();
    final isDownloadingActive = _isFileDownloading();

    final photo = widget.content['photo'];
    final size = _getPhotoContent(photo);
    final width = (size?['width'] ?? 300).toDouble();
    final height = (size?['height'] ?? 200).toDouble();

    final constrainedWidth = width < 150 ? 300.0 : width;
    final constrainedHeight = height < 150 ? 300.0 : height;
    final aspectRatio = constrainedWidth / constrainedHeight;

    final heroTag = 'photo_${widget.messageId}_$photoPath';

    if (photoPath != null && photoPath.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageDetails(
                photoPath: photoPath,
                miniThumbnail: miniThumbnail,
                heroTag: heroTag,
              ),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: miniThumbnail != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RepaintBoundary(
                child: Image.memory(
                  Uint8List.fromList(miniThumbnail),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            )
                : const Icon(Icons.image, size: 48, color: Colors.grey),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isDownloading,
            builder: (context, isDownloading, child) {
              if (isDownloading || isDownloadingActive) {
                return const CircularProgressIndicator();
              }
              return IconButton(
                onPressed: _downloadPhoto,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
