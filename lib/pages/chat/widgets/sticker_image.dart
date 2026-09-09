import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/theme/motion.dart';

/// Renders a TDLib sticker at [size], downloading it on demand.
///
/// Telegram ships three sticker formats and each needs different handling:
/// WEBP is a plain image, TGS is gzip-compressed Lottie JSON, and WEBM is a
/// video. The first two play here; a WEBM sticker falls back to its static
/// thumbnail, since decoding video frames for a chat bubble isn't worth a
/// video player per sticker.
class StickerImage extends StatefulWidget {
  const StickerImage({
    super.key,
    required this.sticker,
    required this.size,
    this.animate = true,
  });

  /// A TDLib `sticker` object.
  final Map<String, dynamic> sticker;

  /// The longest edge of the rendered sticker.
  final double size;

  /// Whether an animated sticker should loop. Pickers pass false to keep a
  /// grid of dozens of stickers cheap.
  final bool animate;

  @override
  State<StickerImage> createState() => _StickerImageState();
}

class _StickerImageState extends State<StickerImage> {
  StreamSubscription<Map<String, dynamic>>? _fileSubscription;

  /// The decompressed Lottie animation of a TGS sticker, once read from disk.
  Uint8List? _lottieBytes;
  bool _lottieFailed = false;

  Map<String, dynamic> get _sticker => widget.sticker;

  String? get _format => _sticker['format']?['@type'] as String?;

  bool get _isWebp => _format == 'StickerFormatWebp';

  bool get _isLottie => _format == 'StickerFormatTgs';

  /// Whether the sticker's own file can be rendered, as opposed to only its
  /// static thumbnail.
  bool get _rendersOwnFile => _isWebp || _isLottie;

  int? get _fileId => _sticker['sticker']?['id'] as int?;

  int? get _thumbnailFileId => _sticker['thumbnail']?['file']?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileSubscription = TDLibClient.filesUpdates.listen(_onFileUpdate);
    _requestDownload();
    _maybeLoadLottie();
  }

  @override
  void didUpdateWidget(StickerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker['sticker']?['id'] != _fileId) {
      _lottieBytes = null;
      _lottieFailed = false;
      _requestDownload();
      _maybeLoadLottie();
    }
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }

  /// Stickers are small, so they are fetched eagerly rather than on tap.
  void _requestDownload() {
    final fileId = _rendersOwnFile ? _fileId : _thumbnailFileId;
    final file = _rendersOwnFile
        ? _sticker['sticker']
        : _sticker['thumbnail']?['file'];
    if (fileId == null || _localPath(file) != null) return;
    TDLibClient.downloadFile(fileId: fileId).catchError((_) {});
  }

  void _onFileUpdate(Map<String, dynamic> update) {
    if (update['@type'] != updateFileConst) return;
    final file = update['file'] as Map<String, dynamic>?;
    final id = file?['id'];
    if (!mounted) return;

    if (id == _fileId) {
      _sticker['sticker'] = file;
      _maybeLoadLottie();
      setState(() {});
    } else if (id == _thumbnailFileId) {
      _sticker['thumbnail']['file'] = file;
      setState(() {});
    }
  }

  String? _localPath(dynamic file) {
    final local = file?['local'];
    if (local?['isDownloadingCompleted'] != true) return null;
    final path = local['path'] as String?;
    return (path == null || path.isEmpty) ? null : path;
  }

  /// Reads and gunzips a downloaded TGS file.
  ///
  /// A `.tgs` is gzip-compressed Lottie JSON, which the Lottie package can't
  /// open itself, so it is inflated here and handed over as raw bytes.
  Future<void> _maybeLoadLottie() async {
    if (!_isLottie || _lottieBytes != null || _lottieFailed) return;
    final path = _localPath(_sticker['sticker']);
    if (path == null) return;

    try {
      final compressed = await File(path).readAsBytes();
      final inflated = gzip.decode(compressed);
      if (!mounted) return;
      setState(() => _lottieBytes = Uint8List.fromList(inflated));
    } catch (_) {
      if (mounted) setState(() => _lottieFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _buildContent();
    // Ease the sticker in once its file finishes downloading and decoding,
    // instead of popping over the emoji placeholder.
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.standard,
      child: SizedBox(
        key: ValueKey(child.key ?? 'sticker'),
        width: widget.size,
        height: widget.size,
        child: Center(child: child),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLottie) {
      final bytes = _lottieBytes;
      if (bytes != null) {
        return Lottie.memory(
          bytes,
          key: const ValueKey('lottie'),
          width: widget.size,
          height: widget.size,
          repeat: widget.animate,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        );
      }
      // While the TGS is downloading, the static thumbnail is the best
      // stand-in we have.
      final thumbnail = _localPath(_sticker['thumbnail']?['file']);
      if (thumbnail != null) return _image(thumbnail);
      return _placeholder();
    }

    final path = _isWebp
        ? _localPath(_sticker['sticker'])
        : _localPath(_sticker['thumbnail']?['file']);
    return path == null ? _placeholder() : _image(path);
  }

  Widget _image(String path) => Image.file(
        File(path),
        key: ValueKey('image-$path'),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );

  Widget _placeholder() => Text(
        _sticker['emoji'] as String? ?? '🎨',
        key: const ValueKey('placeholder'),
        style: TextStyle(fontSize: widget.size * 0.5),
      );
}
