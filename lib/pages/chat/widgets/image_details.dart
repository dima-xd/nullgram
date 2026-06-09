import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Fullscreen, Telegram-style photo viewer.
///
/// Supports pinch and double-tap zoom, swipe-down to dismiss, album swiping,
/// an immersive chrome toggle, captions, and save/share actions.
class ImageDetails extends StatefulWidget {
  final List<String> photoPaths;

  /// Captions aligned 1:1 with [photoPaths]; an entry may be null/empty.
  final List<String?> captions;
  final int initialIndex;
  final String heroTag;

  const ImageDetails({
    super.key,
    required this.photoPaths,
    this.captions = const [],
    this.initialIndex = 0,
    required this.heroTag,
  });

  @override
  State<ImageDetails> createState() => _ImageDetailsState();
}

class _ImageDetailsState extends State<ImageDetails> {
  late final PageController _pageController;
  late int _currentIndex;

  bool _chromeVisible = true;

  /// True while the current page is zoomed in; locks album/dismiss gestures.
  bool _isZoomed = false;

  /// Background opacity (1 at rest, fades toward 0 while dragging to dismiss).
  final ValueNotifier<double> _bgOpacity = ValueNotifier(1.0);

  /// Vertical translation of the current page during a dismiss drag.
  final ValueNotifier<double> _dragOffset = ValueNotifier(0.0);

  static const double _dismissThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentIndex) {
      setState(() => _currentIndex = page);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgOpacity.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _onZoomChanged(bool zoomed) {
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _onDismissDragUpdate(double dy) {
    final next = (_dragOffset.value + dy).clamp(-1000.0, 1000.0);
    _dragOffset.value = next;
    _bgOpacity.value =
        (1.0 - (next.abs() / (_dismissThreshold * 2))).clamp(0.0, 1.0);
  }

  void _onDismissDragEnd(double velocity) {
    if (_dragOffset.value.abs() > _dismissThreshold || velocity.abs() > 700) {
      Navigator.pop(context);
    } else {
      _resetDismiss();
    }
  }

  void _resetDismiss() {
    _dragOffset.value = 0.0;
    _bgOpacity.value = 1.0;
  }

  String? _currentCaption() {
    if (_currentIndex < widget.captions.length) {
      final caption = widget.captions[_currentIndex];
      if (caption != null && caption.isNotEmpty) return caption;
    }
    return null;
  }

  Future<void> _saveCurrent() async {
    final path = widget.photoPaths[_currentIndex];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Gal.putImage(path);
      messenger.showSnackBar(
        const SnackBar(content: Text('Saved to gallery')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _shareCurrent() async {
    final path = widget.photoPaths[_currentIndex];
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _bgOpacity,
            builder: (context, opacity, _) => Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _dragOffset,
            builder: (context, offset, child) => Transform.translate(
              offset: Offset(0, offset),
              child: child,
            ),
            child: PageView.builder(
              controller: _pageController,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.photoPaths.length,
              itemBuilder: (context, index) {
                return _ZoomablePhoto(
                  path: widget.photoPaths[index],
                  heroTag: index == widget.initialIndex
                      ? widget.heroTag
                      : 'photo_$index',
                  onTap: _toggleChrome,
                  onZoomChanged: _onZoomChanged,
                  onDismissDragUpdate: _onDismissDragUpdate,
                  onDismissDragEnd: _onDismissDragEnd,
                  onDismissCancel: _resetDismiss,
                );
              },
            ),
          ),
          _TopChrome(
            visible: _chromeVisible,
            index: _currentIndex,
            total: widget.photoPaths.length,
            onClose: () => Navigator.pop(context),
            onSave: _saveCurrent,
            onShare: _shareCurrent,
          ),
          _BottomCaption(
            visible: _chromeVisible,
            caption: _currentCaption(),
          ),
        ],
      ),
    );
  }
}

/// A single pinch/double-tap zoomable photo within the pager.
class _ZoomablePhoto extends StatefulWidget {
  final String path;
  final String heroTag;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDismissDragUpdate;
  final ValueChanged<double> onDismissDragEnd;
  final VoidCallback onDismissCancel;

  const _ZoomablePhoto({
    required this.path,
    required this.heroTag,
    required this.onTap,
    required this.onZoomChanged,
    required this.onDismissDragUpdate,
    required this.onDismissDragEnd,
    required this.onDismissCancel,
  });

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  /// Dismiss-drag tracking. We decide once per gesture whether a single-finger
  /// pan is a vertical dismiss or a horizontal album swipe (left to PageView).
  bool _dragActive = false;
  bool _axisLocked = false;
  bool _isVerticalDrag = false;
  Offset _dragAccum = Offset.zero;

  bool get _isZoomed => _controller.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) _controller.value = _animation!.value;
      });
    _controller.addListener(_onScaleChanged);
  }

  void _onScaleChanged() {
    widget.onZoomChanged(_isZoomed);
  }

  void _onInteractionStart(ScaleStartDetails d) {
    _dragAccum = Offset.zero;
    _axisLocked = false;
    _isVerticalDrag = false;
    _dragActive = d.pointerCount == 1 && !_isZoomed;
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    // A second finger or any zoom means this is a pinch, not a dismiss.
    if (d.pointerCount > 1 || _isZoomed) {
      if (_isVerticalDrag) widget.onDismissCancel();
      _dragActive = false;
      _axisLocked = false;
      _isVerticalDrag = false;
      return;
    }
    if (!_dragActive) return;

    _dragAccum += d.focalPointDelta;
    if (!_axisLocked) {
      if (_dragAccum.distance < 8) return;
      _axisLocked = true;
      _isVerticalDrag = _dragAccum.dy.abs() > _dragAccum.dx.abs();
    }
    if (_isVerticalDrag) widget.onDismissDragUpdate(d.focalPointDelta.dy);
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (_isVerticalDrag) {
      widget.onDismissDragEnd(d.velocity.pixelsPerSecond.dy);
    }
    _dragActive = false;
    _axisLocked = false;
    _isVerticalDrag = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward(from: 0);
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    const scale = 2.5;
    final target = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    _animateTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 4.0,
        onInteractionStart: _onInteractionStart,
        onInteractionUpdate: _onInteractionUpdate,
        onInteractionEnd: _onInteractionEnd,
        child: Center(
          child: Hero(
            tag: widget.heroTag,
            child: Image.file(
              File(widget.path),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  final bool visible;
  final int index;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const _TopChrome({
    required this.visible,
    required this.index,
    required this.total,
    required this.onClose,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
                const Spacer(),
                if (total > 1)
                  Text(
                    '${index + 1}/$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) =>
                      value == 0 ? onSave() : onShare(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 0,
                      child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Save'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCaption extends StatelessWidget {
  final bool visible;
  final String? caption;

  const _BottomCaption({required this.visible, required this.caption});

  @override
  Widget build(BuildContext context) {
    final text = caption;
    if (text == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.12],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                    child: Text(
                      text,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
