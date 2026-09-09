import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nullgram/pages/chat/widgets/video_player_page.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// A video message: its thumbnail with a play overlay, opening fullscreen
/// playback once the file is on disk.
///
/// Handles both `MessageVideo` and `MessageVideoNote`; the round variant is
/// clipped to a circle the way Telegram draws it. TDLib downloads lazily, so
/// the first tap starts the download and playback begins when it lands.
class MessageVideo extends StatefulWidget {
  const MessageVideo({super.key, required this.content});

  final Map<String, dynamic> content;

  bool get _isRound => content['@type'] == 'MessageVideoNote';

  @override
  State<MessageVideo> createState() => _MessageVideoState();
}

class _MessageVideoState extends State<MessageVideo> {
  /// The side of a round video message on screen.
  static const double _roundSize = 200;

  /// The height of a landscape video's thumbnail.
  static const double _thumbnailHeight = 200;

  StreamSubscription<Map<String, dynamic>>? _fileSubscription;

  /// Set when the user taps before the file is available, so playback opens
  /// automatically once the download completes.
  bool _openWhenReady = false;

  Map<String, dynamic> get _video =>
      (widget._isRound
          ? widget.content['videoNote']
          : widget.content['video']) as Map<String, dynamic>;

  /// The TDLib `file` holding the video bytes. Both `video` and `videoNote`
  /// name that field `video`.
  Map<String, dynamic>? get _videoFile =>
      _video['video'] as Map<String, dynamic>?;

  int? get _fileId => _videoFile?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileSubscription = TDLibClient.filesUpdates.listen(_onFileUpdate);
    _downloadThumbnail();
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }

  /// Thumbnails are small, so they are fetched eagerly — otherwise the bubble
  /// would show a grey placeholder until the whole video is downloaded.
  void _downloadThumbnail() {
    final thumbnailFile = _video['thumbnail']?['file'];
    final thumbnailId = thumbnailFile?['id'] as int?;
    if (thumbnailId == null || _localPath(thumbnailFile) != null) return;
    TDLibClient.downloadFile(fileId: thumbnailId).catchError((_) {});
  }

  void _onFileUpdate(Map<String, dynamic> update) {
    if (update['@type'] != updateFileConst) return;
    final file = update['file'] as Map<String, dynamic>?;
    final id = file?['id'];
    if (!mounted) return;

    if (id == _fileId) {
      _video['video'] = file;
      setState(() {});
      final path = _localPath(file);
      if (path != null && _openWhenReady) {
        _openWhenReady = false;
        _openPlayer(path);
      }
    } else if (id == _video['thumbnail']?['file']?['id']) {
      _video['thumbnail']['file'] = file;
      setState(() {});
    }
  }

  String? _localPath(dynamic file) {
    final local = file?['local'];
    if (local?['isDownloadingCompleted'] != true) return null;
    final path = local['path'] as String?;
    return (path == null || path.isEmpty) ? null : path;
  }

  bool get _isDownloading =>
      _videoFile?['local']?['isDownloadingActive'] == true;

  void _openPlayer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          path: path,
          isRound: widget._isRound,
          title: widget._isRound ? 'Video message' : null,
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    final path = _localPath(_videoFile);
    if (path != null) {
      _openPlayer(path);
      return;
    }

    final fileId = _fileId;
    if (fileId == null) return;
    _openWhenReady = true;
    setState(() {});
    await TDLibClient.downloadFile(fileId: fileId).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumbnailPath = _localPath(_video['thumbnail']?['file']);
    final duration = _video['duration'] as int? ?? 0;

    final Widget preview = thumbnailPath != null
        ? Image.file(
            File(thumbnailPath),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            width: widget._isRound ? _roundSize : double.infinity,
            height: widget._isRound ? _roundSize : _thumbnailHeight,
            errorBuilder: (context, error, stackTrace) => _placeholder(scheme),
          )
        : _placeholder(scheme);

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: widget._isRound ? _roundSize : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget._isRound
                ? ClipOval(child: preview)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: preview,
                  ),
            Container(
              decoration: BoxDecoration(
                color: scheme.scrim.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: _isDownloading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
            if (duration > 0)
              Positioned(
                left: widget._isRound ? null : 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.scrim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
        width: widget._isRound ? _roundSize : double.infinity,
        height: widget._isRound ? _roundSize : _thumbnailHeight,
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.video_library,
          size: 48,
          color: scheme.onSurfaceVariant,
        ),
      );

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
