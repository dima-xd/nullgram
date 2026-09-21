import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nullgram/services/link_resolver.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/td_bytes.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:nullgram/theme/app_theme.dart';

/// The card TDLib attaches to a text message containing a link: site name,
/// title, description and, when the preview carries one, an image.
class MessageLinkPreview extends StatelessWidget {
  const MessageLinkPreview({super.key, required this.linkPreview});

  final Map<String, dynamic> linkPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.chatColors.bubbleLink;

    final siteName = _nonEmpty(linkPreview['siteName']);
    final title = _nonEmpty(linkPreview['title']);
    final description = _nonEmpty(linkPreview['description']?['text']);
    final url = _nonEmpty(linkPreview['url']) ?? '';

    final media = _previewMedia(linkPreview['type']);
    final isLarge = linkPreview['showLargeMedia'] == true && media != null;

    final texts = <Widget>[
      if (siteName != null)
        Text(
          siteName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      if (title != null)
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      if (description != null)
        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ];

    // A preview with no text at all would be an unexplained blank strip.
    if (texts.isEmpty && media == null) return const SizedBox.shrink();

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLarge) ...[
          _PreviewImage(media: media, large: true),
          const SizedBox(height: 6),
          ...texts,
        ] else if (media != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: texts,
                ),
              ),
              const SizedBox(width: 8),
              _PreviewImage(media: media, large: false),
            ],
          )
        else
          ...texts,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: url.isEmpty ? null : () => openLink(context, url),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: body,
        ),
      ),
    );
  }

  static String? _nonEmpty(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  /// The image a `linkPreviewType*` carries, or null when it has none.
  static _PreviewMedia? _previewMedia(dynamic type) {
    if (type is! Map) return null;

    // Photo-bearing types expose `sizes`; media types hang a `thumbnail`.
    final photo = type['photo'] ?? type['cover'] ?? type['sticker'];
    if (photo is Map) {
      final sizes = photo['sizes'] as List?;
      if (sizes != null && sizes.isNotEmpty) {
        final chosen = sizes.firstWhere(
          (size) => ((size as Map)['width'] as int? ?? 0) >= 320,
          orElse: () => sizes.last,
        ) as Map;
        return _PreviewMedia(
          file: chosen['photo'] as Map<String, dynamic>?,
          minithumbnail: photo['minithumbnail']?['data'],
          aspectRatio: _ratio(chosen['width'], chosen['height']),
        );
      }
    }

    for (final key in const ['video', 'animation', 'document', 'audio']) {
      final media = type[key];
      if (media is! Map) continue;
      final thumbnail = media['thumbnail'];
      if (thumbnail is! Map) continue;
      return _PreviewMedia(
        file: thumbnail['file'] as Map<String, dynamic>?,
        minithumbnail: media['minithumbnail']?['data'],
        aspectRatio: _ratio(thumbnail['width'], thumbnail['height']),
      );
    }
    return null;
  }

  static double _ratio(dynamic width, dynamic height) {
    final w = (width as num?)?.toDouble() ?? 0;
    final h = (height as num?)?.toDouble() ?? 0;
    if (w <= 0 || h <= 0) return 16 / 9;
    return (w / h).clamp(0.5, 2.5);
  }
}

/// The picture behind a link preview: a TDLib file plus its blurred stand-in.
class _PreviewMedia {
  const _PreviewMedia({
    required this.file,
    required this.minithumbnail,
    required this.aspectRatio,
  });

  final Map<String, dynamic>? file;
  final dynamic minithumbnail;
  final double aspectRatio;
}

/// Downloads and shows a preview image, falling back to its minithumbnail.
class _PreviewImage extends StatefulWidget {
  const _PreviewImage({required this.media, required this.large});

  final _PreviewMedia? media;
  final bool large;

  @override
  State<_PreviewImage> createState() => _PreviewImageState();
}

class _PreviewImageState extends State<_PreviewImage> {
  static const double _smallSide = 56;

  // A fixed width keeps the card measurable inside the bubble's IntrinsicWidth,
  // which an AspectRatio of unbounded height cannot be.
  static const double _largeWidth = 240;

  final ValueNotifier<String?> _path = ValueNotifier(null);
  StreamSubscription<Map<String, dynamic>>? _fileSubscription;

  int? get _fileId => widget.media?.file?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _path.value = _pathOf(widget.media?.file);
    if (_path.value != null) return;

    _fileSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      if (file is! Map || file['id'] != _fileId) return;
      final path = _pathOf(Map<String, dynamic>.from(file));
      if (path != null && mounted) _path.value = path;
    });
    _fetch();
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    _path.dispose();
    super.dispose();
  }

  /// Always fetched: a preview thumbnail is tiny, and the auto-download limits
  /// are sized for full media.
  Future<void> _fetch() async {
    final fileId = _fileId;
    if (fileId == null) return;
    final file = await TDLibClient.getFile(fileId: fileId);
    final path = _pathOf(file);
    if (path != null) {
      if (mounted) _path.value = path;
      return;
    }
    await TDLibClient.downloadFile(fileId: fileId);
  }

  static String? _pathOf(Map<String, dynamic>? file) {
    final local = file?['local'];
    if (local is! Map || local['isDownloadingCompleted'] != true) return null;
    final path = local['path'];
    return path is String && path.isNotEmpty ? path : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = widget.media;
    final bytes = TdBytes.decode(media?.minithumbnail);

    return ValueListenableBuilder<String?>(
      valueListenable: _path,
      builder: (context, path, child) {
        Widget image;
        if (path != null) {
          image = Image.file(File(path), fit: BoxFit.cover);
        } else if (bytes != null) {
          image = Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
        } else {
          image = ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.link, color: scheme.onSurfaceVariant),
          );
        }

        final clipped = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.expand(child: image),
        );

        if (!widget.large) {
          return SizedBox(
            width: _smallSide,
            height: _smallSide,
            child: clipped,
          );
        }
        final ratio = media?.aspectRatio ?? 16 / 9;
        return SizedBox(
          width: _largeWidth,
          height: _largeWidth / ratio,
          child: clipped,
        );
      },
    );
  }
}
