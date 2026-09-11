import 'package:flutter/material.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';

import '../../../theme/motion.dart';

/// The small own-camera window that floats over the call stage.
///
/// Dragging moves it freely and it settles into the nearest corner on release,
/// the way Telegram's does. Tapping asks the parent to swap which track owns
/// the full screen.
class LocalPreview extends StatefulWidget {
  const LocalPreview({
    super.key,
    required this.track,
    required this.onTap,
    this.margin = 16,
    this.width = 108,
  });

  final TgVideoTrack track;
  final VoidCallback onTap;
  final double margin;
  final double width;

  @override
  State<LocalPreview> createState() => _LocalPreviewState();
}

class _LocalPreviewState extends State<LocalPreview> {
  Alignment _corner = Alignment.topRight;
  Offset _drag = Offset.zero;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.width / _previewAspect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resting = _restingOffset(constraints, widget.width, height);
        final position = _dragging ? resting + _drag : resting;

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragging ? Duration.zero : Motion.medium,
              curve: Curves.easeOutCubic,
              left: position.dx,
              top: position.dy,
              width: widget.width,
              height: height,
              child: GestureDetector(
                onTap: widget.onTap,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (d) => setState(() => _drag += d.delta),
                onPanEnd: (_) => _settle(constraints, widget.width, height),
                child: _PreviewSurface(track: widget.track),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _previewAspect {
    final aspect = widget.track.aspectRatio;
    // Portrait phone cameras report a landscape sensor; keep the window
    // portrait so it doesn't swallow the screen.
    return aspect > 1 ? 3 / 4 : aspect;
  }

  Offset _restingOffset(BoxConstraints box, double width, double height) {
    final left = _corner.x < 0
        ? widget.margin
        : box.maxWidth - width - widget.margin;
    final top = _corner.y < 0
        ? widget.margin
        : box.maxHeight - height - widget.margin;
    return Offset(left, top);
  }

  void _settle(BoxConstraints box, double width, double height) {
    final current = _restingOffset(box, width, height) + _drag;
    final centre = current + Offset(width / 2, height / 2);
    setState(() {
      _corner = Alignment(
        centre.dx < box.maxWidth / 2 ? -1 : 1,
        centre.dy < box.maxHeight / 2 ? -1 : 1,
      );
      _drag = Offset.zero;
      _dragging = false;
    });
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.track});

  final TgVideoTrack track;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: track.isActive
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: track.width.toDouble(),
                  height: track.height.toDouble(),
                  child: Texture(textureId: track.textureId!),
                ),
              )
            : const ColoredBox(color: Colors.black54),
      ),
    );
  }
}
