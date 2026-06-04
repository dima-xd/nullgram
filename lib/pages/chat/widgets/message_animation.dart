import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:video_player/video_player.dart';

/// An animation (GIF) message.
///
/// Telegram animations are MP4 files. This downloads the animation and plays it
/// inline, looped and muted, the way Telegram autoplays GIFs. Until the file is
/// ready it shows the thumbnail (or minithumbnail) with a "GIF" badge.
class MessageAnimation extends StatefulWidget {
  final Map<String, dynamic> content;

  const MessageAnimation({super.key, required this.content});

  @override
  State<MessageAnimation> createState() => _MessageAnimationState();
}

class _MessageAnimationState extends State<MessageAnimation> {
  StreamSubscription? _fileUpdateSubscription;
  VideoPlayerController? _videoController;
  bool _initializingVideo = false;

  Map<String, dynamic> get _animation =>
      widget.content['animation'] as Map<String, dynamic>;

  int? get _fileId => _animation['animation']?['id'] as int?;

  int? get _thumbnailFileId => _animation['thumbnail']?['file']?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileUpdateSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      final id = file['id'];
      if (!mounted) return;
      if (id == _fileId) {
        _animation['animation'] = file;
        _maybeInitVideo();
        setState(() {});
      } else if (id == _thumbnailFileId) {
        _animation['thumbnail']['file'] = file;
        setState(() {});
      }
    });

    // Fetch the animation itself (for playback) and the thumbnail (placeholder).
    if (_animationPath() == null && _fileId != null) {
      TDLibClient.downloadFile(fileId: _fileId!).catchError((_) {});
    } else {
      _maybeInitVideo();
    }
    if (_thumbnailPath() == null && _thumbnailFileId != null) {
      TDLibClient.downloadFile(fileId: _thumbnailFileId!).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  String? _localPath(dynamic file) {
    final local = file?['local'];
    if (local != null && local['isDownloadingCompleted'] == true) {
      return local['path'] as String?;
    }
    return null;
  }

  String? _animationPath() => _localPath(_animation['animation']);

  String? _thumbnailPath() => _localPath(_animation['thumbnail']?['file']);

  List<int>? _miniThumbnailBytes() {
    final data = _animation['minithumbnail']?['data'];
    return data is List ? data.cast<int>() : null;
  }

  /// Initializes the looped, muted player once the file is on disk.
  Future<void> _maybeInitVideo() async {
    if (_videoController != null || _initializingVideo) return;
    final path = _animationPath();
    if (path == null || path.isEmpty) return;

    _initializingVideo = true;
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
    } catch (_) {
      await controller.dispose();
    } finally {
      _initializingVideo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = (_animation['width'] ?? 300).toDouble();
    final height = (_animation['height'] ?? 200).toDouble();
    final aspectRatio = width <= 0 || height <= 0 ? 1.0 : width / height;

    final controller = _videoController;
    final isPlaying = controller != null && controller.value.isInitialized;

    Widget content;
    if (isPlaying) {
      content = VideoPlayer(controller);
    } else {
      final thumbnailPath = _thumbnailPath();
      final miniThumbnail = _miniThumbnailBytes();
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        content = Image.file(File(thumbnailPath), fit: BoxFit.cover);
      } else if (miniThumbnail != null) {
        content = Image.memory(
          Uint8List.fromList(miniThumbnail),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } else {
        content = Container(
          color: Colors.grey[300],
          child: const Icon(Icons.gif_box, size: 48),
        );
      }
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.expand(child: content),
          ),
          // While loading, keep the play affordance over the still frame.
          if (!isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'GIF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
