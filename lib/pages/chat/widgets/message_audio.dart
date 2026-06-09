import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

/// An audio message bubble with inline playback.
///
/// Handles both `MessageAudio` (music/audio files) and `MessageVoiceNote`
/// (recorded voice messages); the two store their file under different keys.
///
/// TDLib stores files lazily: the audio bytes aren't on disk until requested.
/// Tapping play downloads the file (if needed) by listening to
/// [TDLibClient.filesUpdates], then streams it through [just_audio].
class MessageAudio extends StatefulWidget {
  final Map<String, dynamic> content;

  const MessageAudio({
    super.key,
    required this.content,
  });

  bool get _isVoiceNote => content['@type'] == 'MessageVoiceNote';

  @override
  State<MessageAudio> createState() => _MessageAudioState();
}

class _MessageAudioState extends State<MessageAudio> {
  AudioPlayer? _player;
  StreamSubscription? _fileUpdateSubscription;

  final ValueNotifier<bool> _isDownloading = ValueNotifier(false);

  /// Set when the user taps play before the file is available, so playback
  /// starts automatically once the download completes.
  bool _playWhenReady = false;
  bool _isPrepared = false;

  /// Decoded voice-note amplitudes (0-31), or null for non-voice audio.
  List<int>? _waveform;

  @override
  void initState() {
    super.initState();
    _fileUpdateSubscription = TDLibClient.filesUpdates.listen(_onFileUpdate);

    if (widget._isVoiceNote) {
      final raw = widget.content['voiceNote']?['waveform'];
      if (raw is String && raw.isNotEmpty) {
        _waveform = _decodeWaveform(raw);
      }
    }
  }

  /// Unpacks TDLib's voice waveform: a base64 byte stream of 5-bit samples
  /// (0-31), most-significant-bit first.
  List<int> _decodeWaveform(String base64Data) {
    final bytes = base64Decode(base64Data);
    final sampleCount = (bytes.length * 8) ~/ 5;
    final samples = <int>[];
    for (var i = 0; i < sampleCount; i++) {
      var value = 0;
      for (var bit = 0; bit < 5; bit++) {
        final globalBit = i * 5 + bit;
        final byteIndex = globalBit ~/ 8;
        final bitIndex = 7 - (globalBit % 8);
        final set = byteIndex < bytes.length &&
            (bytes[byteIndex] >> bitIndex) & 1 == 1;
        value = (value << 1) | (set ? 1 : 0);
      }
      samples.add(value);
    }
    return samples;
  }

  @override
  void dispose() {
    _fileUpdateSubscription?.cancel();
    _isDownloading.dispose();
    _player?.dispose();
    super.dispose();
  }

  /// The TDLib `file` object holding the audio bytes. `MessageVoiceNote`
  /// nests it under `voiceNote.voice`, `MessageAudio` under `audio.audio`.
  Map<String, dynamic> get _audioFile {
    final media = widget._isVoiceNote
        ? widget.content['voiceNote']
        : widget.content['audio'];
    final file = widget._isVoiceNote ? media['voice'] : media['audio'];
    return file as Map<String, dynamic>;
  }

  void _setAudioFile(Map<String, dynamic> file) {
    if (widget._isVoiceNote) {
      widget.content['voiceNote']['voice'] = file;
    } else {
      widget.content['audio']['audio'] = file;
    }
  }

  int get _fileId => _audioFile['id'] as int;

  String? get _localPath {
    final local = _audioFile['local'];
    if (local != null && local['isDownloadingCompleted'] == true) {
      return local['path'] as String?;
    }
    return null;
  }

  void _onFileUpdate(Map<String, dynamic> update) {
    if (update['@type'] != updateFileConst) return;
    final file = update['file'];
    if (file['id'] != _fileId) return;
    if (!mounted) return;

    _setAudioFile(file);
    setState(() {});

    final path = _localPath;
    if (path != null) {
      _isDownloading.value = false;
      if (_playWhenReady) {
        _playWhenReady = false;
        _prepareAndPlay(path);
      }
    }
  }

  Future<void> _onPlayTap() async {
    final player = _player;
    // Pause only while actively playing. At end-of-track just_audio keeps
    // `playing == true` with a completed state, so exclude that case and let
    // the tap fall through to a restart.
    if (player != null &&
        player.playing &&
        player.processingState != ProcessingState.completed) {
      await player.pause();
      return;
    }

    final path = _localPath;
    if (path != null) {
      await _prepareAndPlay(path);
      return;
    }

    // File not on disk yet: request a download and play when it lands.
    _playWhenReady = true;
    _isDownloading.value = true;
    try {
      await TDLibClient.downloadFile(fileId: _fileId);
    } catch (e) {
      _playWhenReady = false;
      _isDownloading.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download audio: $e')),
        );
      }
    }
  }

  Future<void> _prepareAndPlay(String path) async {
    if (_player == null) {
      _player = AudioPlayer();
      // Rebuild so the progress bar and play button bind to the new player's
      // streams instead of the null placeholder they were built with.
      if (mounted) setState(() {});
    }
    final player = _player!;
    try {
      if (!_isPrepared) {
        await player.setFilePath(path);
        _isPrepared = true;
      }
      // Restart from the beginning if the previous play reached the end.
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? performer;
    final int durationSeconds;

    if (widget._isVoiceNote) {
      final voiceNote = widget.content['voiceNote'];
      title = 'Voice message';
      performer = null;
      durationSeconds = (voiceNote['duration'] as int?) ?? 0;
    } else {
      final audio = widget.content['audio'];
      title = audio['title']?.toString().isNotEmpty == true
          ? audio['title']
          : 'Audio';
      performer = audio['performer']?.toString().isNotEmpty == true
          ? audio['performer']
          : 'Unknown';
      durationSeconds = (audio['duration'] as int?) ?? 0;
    }
    final metadataDuration = Duration(seconds: durationSeconds);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _PlayButton(
            isDownloading: _isDownloading,
            player: _player,
            onTap: _onPlayTap,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (performer != null)
                  Text(
                    performer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget._isVoiceNote && _waveform != null)
                  _WaveformProgress(
                    player: _player,
                    samples: _waveform!,
                    metadataDuration: metadataDuration,
                    formatDuration: _formatDuration,
                  )
                else
                  _ProgressBar(
                    player: _player,
                    metadataDuration: metadataDuration,
                    formatDuration: _formatDuration,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular play/pause control that reflects download and playback state.
class _PlayButton extends StatelessWidget {
  final ValueNotifier<bool> isDownloading;
  final AudioPlayer? player;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isDownloading,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.primary;

    return ValueListenableBuilder<bool>(
      valueListenable: isDownloading,
      builder: (context, downloading, child) {
        if (downloading) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          );
        }

        return StreamBuilder<PlayerState>(
          stream: player?.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final isLoading = state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering;
            final isCompleted =
                state?.processingState == ProcessingState.completed;
            // Once finished the track sits at the end; surface play (to replay)
            // rather than a stuck pause button.
            final isPlaying = (state?.playing ?? false) && !isCompleted;

            return GestureDetector(
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: scheme.onPrimary,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A seek bar with elapsed/total time, driven by the player's position stream.
class _ProgressBar extends StatelessWidget {
  final AudioPlayer? player;
  final Duration metadataDuration;
  final String Function(Duration) formatDuration;

  const _ProgressBar({
    required this.player,
    required this.metadataDuration,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = player;
    if (currentPlayer == null) {
      // Nothing has played yet: just show the known total duration.
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          formatDuration(metadataDuration),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: currentPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = currentPlayer.duration ?? metadataDuration;
        final maxMs = total.inMilliseconds.toDouble();
        final value =
            maxMs == 0 ? 0.0 : position.inMilliseconds.clamp(0, maxMs).toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                max: maxMs == 0 ? 1 : maxMs,
                onChanged: (v) =>
                    currentPlayer.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(position), style: _timeStyle(context)),
                Text(formatDuration(total), style: _timeStyle(context)),
              ],
            ),
          ],
        );
      },
    );
  }

  TextStyle? _timeStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
}

/// Voice-note progress: a tappable waveform that fills as playback advances,
/// with elapsed/total time below.
class _WaveformProgress extends StatelessWidget {
  final AudioPlayer? player;
  final List<int> samples;
  final Duration metadataDuration;
  final String Function(Duration) formatDuration;

  const _WaveformProgress({
    required this.player,
    required this.samples,
    required this.metadataDuration,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentPlayer = player;

    if (currentPlayer == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Waveform(
              samples: samples,
              progress: 0,
              playedColor: scheme.primary,
              unplayedColor: scheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                formatDuration(metadataDuration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: currentPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = currentPlayer.duration ?? metadataDuration;
        final totalMs = total.inMilliseconds;
        final progress = totalMs == 0
            ? 0.0
            : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

        void seekToFraction(double fraction) {
          if (totalMs == 0) return;
          currentPlayer.seek(
            Duration(milliseconds: (fraction.clamp(0.0, 1.0) * totalMs).round()),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        seekToFraction(d.localPosition.dx / width),
                    onHorizontalDragUpdate: (d) =>
                        seekToFraction(d.localPosition.dx / width),
                    child: _Waveform(
                      samples: samples,
                      progress: progress,
                      playedColor: scheme.primary,
                      unplayedColor: scheme.onSurface.withValues(alpha: 0.25),
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(position),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    formatDuration(total),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Waveform extends StatelessWidget {
  final List<int> samples;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  const _Waveform({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          samples: samples,
          progress: progress,
          playedColor: playedColor,
          unplayedColor: unplayedColor,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> samples;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    const barWidth = 2.5;
    const gap = 1.5;
    final step = barWidth + gap;
    final barCount = (size.width / step).floor().clamp(1, samples.length);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {
      // Map the bar onto the sample array so the full clip is represented.
      final sample = samples[(i * samples.length ~/ barCount)];
      final normalized = sample / 31.0;
      final barHeight = (normalized * size.height).clamp(3.0, size.height);
      final x = i * step;
      final y = (size.height - barHeight) / 2;

      paint.color = (i / barCount) <= progress ? playedColor : unplayedColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.25),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.samples != samples ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
}
