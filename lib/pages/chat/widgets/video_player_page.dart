import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen playback for a downloaded video or video message.
///
/// Used by both `MessageVideo` and `MessageVideoNote`, which until now only
/// drew a play button that did nothing.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.path,
    this.isRound = false,
    this.title,
  });

  /// The on-disk path of an already-downloaded video.
  final String path;

  /// Whether to clip the video to a circle, as Telegram does for video
  /// messages.
  final bool isRound;

  final String? title;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller =
      VideoPlayerController.file(File(widget.path));

  final ValueNotifier<bool> _isReady = ValueNotifier(false);
  final ValueNotifier<String?> _error = ValueNotifier(null);

  /// Whether the controls are visible; tapping the video toggles them.
  final ValueNotifier<bool> _showControls = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      // A video message is a short loop in Telegram; a regular video is not.
      await _controller.setLooping(widget.isRound);
      _isReady.value = true;
      await _controller.play();
    } catch (e) {
      if (mounted) _error.value = 'This video could not be played.';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _isReady.dispose();
    _error.dispose();
    _showControls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The page is a black surface regardless of theme, so the status bar
      // icons have to be light to stay visible.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: widget.title == null ? null : Text(widget.title!),
        ),
        extendBodyBehindAppBar: true,
        body: ValueListenableBuilder<String?>(
          valueListenable: _error,
          builder: (context, error, child) {
            if (error != null) {
              return Center(
                child: Text(error, style: const TextStyle(color: Colors.white)),
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: _isReady,
              builder: (context, isReady, child) {
                if (!isReady) {
                  return const Center(child: CircularProgressIndicator());
                }
                return GestureDetector(
                  onTap: () => _showControls.value = !_showControls.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: widget.isRound
                              ? 1
                              : _controller.value.aspectRatio,
                          child: widget.isRound
                              ? ClipOval(child: VideoPlayer(_controller))
                              : VideoPlayer(_controller),
                        ),
                      ),
                      _buildControls(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showControls,
      builder: (context, show, child) => AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !show,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, child) => IconButton.filled(
                  iconSize: 40,
                  onPressed: () => value.isPlaying
                      ? _controller.pause()
                      : _controller.play(),
                  icon: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                // Clear of the navigation bar: the page is drawn edge to edge
                // behind it.
                bottom: 32 + MediaQuery.paddingOf(context).bottom,
                child: _buildProgress(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, child) => Row(
        children: [
          Text(
            _format(value.position),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          Text(
            _format(value.duration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
