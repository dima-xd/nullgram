import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import 'package:share_plus/share_plus.dart';

/// A file/document message: an icon, the file name and size, and a download
/// button. Once downloaded, tapping shares/opens the file via the OS.
///
/// Mirrors the [MessagePhoto] download flow: it listens to
/// [TDLibClient.filesUpdates] and patches the local file in place on completion.
class MessageDocument extends StatefulWidget {
  final Map<String, dynamic> content;

  const MessageDocument({super.key, required this.content});

  @override
  State<MessageDocument> createState() => _MessageDocumentState();
}

class _MessageDocumentState extends State<MessageDocument> {
  StreamSubscription? _fileUpdateSubscription;

  Map<String, dynamic> get _document =>
      widget.content['document'] as Map<String, dynamic>;

  int? get _fileId => _document['document']?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fileUpdateSubscription = TDLibClient.filesUpdates.listen((update) {
      if (update['@type'] != updateFileConst) return;
      final file = update['file'];
      if (file['id'] == _fileId && mounted) {
        _document['document'] = file;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    super.dispose();
  }

  String? _localPath() {
    final local = _document['document']?['local'];
    if (local != null && local['isDownloadingCompleted'] == true) {
      return local['path'] as String?;
    }
    return null;
  }

  bool _isDownloading() =>
      _document['document']?['local']?['isDownloadingActive'] == true;

  Future<void> _onTap() async {
    final path = _localPath();
    if (path != null && path.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
      return;
    }
    final fileId = _fileId;
    if (fileId != null) {
      await TDLibClient.downloadFile(fileId: fileId);
    }
  }

  /// Formats a byte count as a short human-readable size (e.g. '1.4 MB').
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = _document['fileName'] as String? ?? 'Document';
    final size = (_document['document']?['size'] ??
        _document['document']?['expectedSize'] ??
        0) as int;
    final isDownloaded = _localPath() != null;

    return InkWell(
      onTap: _onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDownloading()
                    ? Icons.hourglass_top
                    : (isDownloaded ? Icons.insert_drive_file : Icons.download),
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (size > 0)
                    Text(
                      _formatSize(size),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
