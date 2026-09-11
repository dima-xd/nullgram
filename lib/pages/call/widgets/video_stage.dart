import 'package:flutter/material.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';

import '../../../theme/motion.dart';

/// Full-bleed video for one track, cross-fading to [placeholder] when the
/// track carries no picture.
///
/// The texture is laid out at its own aspect ratio inside a [FittedBox] so it
/// fills the stage the way a camera viewfinder does, cropping rather than
/// letterboxing.
class VideoStage extends StatelessWidget {
  const VideoStage({
    super.key,
    required this.track,
    required this.placeholder,
  });

  final TgVideoTrack track;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: track.isActive
          ? _VideoSurface(key: ValueKey(track.textureId), track: track)
          : KeyedSubtree(
              key: const ValueKey('placeholder'),
              child: placeholder,
            ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({super.key, required this.track});

  final TgVideoTrack track;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: track.width.toDouble(),
          height: track.height.toDouble(),
          child: Texture(textureId: track.textureId!),
        ),
      ),
    );
  }
}

/// A top-and-bottom darkening wash so white-on-video text stays legible.
class VideoScrim extends StatelessWidget {
  const VideoScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.25, 0.6, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
