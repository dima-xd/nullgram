import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// A sticker message.
///
/// Static WEBP stickers render directly via [Image.file] once downloaded.
/// Animated stickers (TGS/WEBM) can't be rendered without a Lottie/video
/// player, so they fall back to their static thumbnail (or the sticker's emoji
/// if even that is unavailable). Full animated playback is out of scope.
class MessageSticker extends StatefulWidget {
  final Map<String, dynamic> content;

  const MessageSticker({super.key, required this.content});

  @override
  State<MessageSticker> createState() => _MessageStickerState();
}

class _MessageStickerState extends State<MessageSticker> {
  static const double _maxSize = 160;

  StreamSubscription? _fileUpdateSubscription;

  Map<String, dynamic> get _sticker =>
      widget.content['sticker'] as Map<String, dynamic>;

  bool get _isStatic =>
      _sticker['format']?['@type'] == 'StickerFormatWebp';

  int? get _fileId => _sticker['sticker']?['id'] as int?;

  int? get _thumbnailFileId => _sticker['thumbnail']?['file']?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileUpdateSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      final id = file['id'];
      if (!mounted) return;
      if (id == _fileId) {
        _sticker['sticker'] = file;
        setState(() {});
      } else if (id == _thumbnailFileId) {
        _sticker['thumbnail']['file'] = file;
        setState(() {});
      }
    });

    // Stickers are small; fetch eagerly so they appear without a tap.
    if (_isStatic && _localPath(_sticker['sticker']) == null && _fileId != null) {
      TDLibClient.downloadFile(fileId: _fileId!).catchError((_) {});
    } else if (!_isStatic &&
        _localPath(_sticker['thumbnail']?['file']) == null &&
        _thumbnailFileId != null) {
      TDLibClient.downloadFile(fileId: _thumbnailFileId!).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    super.dispose();
  }

  String? _localPath(dynamic file) {
    final local = file?['local'];
    if (local != null && local['isDownloadingCompleted'] == true) {
      return local['path'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = (_sticker['width'] ?? 160).toDouble();
    final height = (_sticker['height'] ?? 160).toDouble();
    final scale = _maxSize / (width > height ? width : height);

    final path = _isStatic
        ? _localPath(_sticker['sticker'])
        : _localPath(_sticker['thumbnail']?['file']);

    final emoji = _sticker['emoji'] as String?;

    final Widget placeholder = SizedBox(
      width: _maxSize,
      height: _maxSize,
      child: Center(
        child: Text(emoji ?? '🎨', style: const TextStyle(fontSize: 56)),
      ),
    );

    if (path == null || path.isEmpty) return placeholder;

    return SizedBox(
      width: width * scale,
      height: height * scale,
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
