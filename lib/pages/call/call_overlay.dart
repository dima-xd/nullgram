import 'package:flutter/material.dart';

import '../../main.dart' show navigatorKey;
import '../../services/call_models.dart';
import '../../services/call_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import 'call_page.dart';

/// Wraps the app so any active call surfaces a full-screen [CallPage] from
/// anywhere (incoming or outgoing) and pops it when the call ends.
///
/// A minimised call keeps running behind a small draggable window layered over
/// the app; tapping it restores the full screen.
class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  bool _open = false;

  /// The call route we pushed, so it can be closed without going through the
  /// page's own back handling.
  Route<void>? _route;

  @override
  void initState() {
    super.initState();
    callService.addListener(_sync);
  }

  void _sync() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final call = callService.current;
    final shouldOpen =
        call != null && !call.uiState.isTerminal && !call.isMinimized;
    if (shouldOpen && !_open) {
      _open = true;
      final route = MaterialPageRoute<void>(
        builder: (_) => const CallPage(),
        fullscreenDialog: true,
      );
      _route = route;
      nav.push(route).then((_) {
        _open = false;
        if (identical(_route, route)) _route = null;
      });
    } else if (!shouldOpen && _open) {
      _open = false;
      _dismiss(nav);
    }
    if (mounted) setState(() {});
  }

  /// Closes the call screen we pushed, specifically.
  ///
  /// [NavigatorState.maybePop] would consult [CallPage]'s `PopScope`, which
  /// answers a back gesture by minimising - so a call the peer hung up would
  /// never leave the screen. Popping only when our route is on top keeps the
  /// usual dismissal animation; anything else is removed outright.
  void _dismiss(NavigatorState nav) {
    final route = _route;
    _route = null;
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      nav.pop();
    } else {
      nav.removeRoute(route);
    }
  }

  @override
  void dispose() {
    callService.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = callService.current;
    final minimised =
        call != null && !call.uiState.isTerminal && call.isMinimized;

    return Stack(
      children: [
        widget.child,
        if (minimised) _MinimisedCall(call: call),
      ],
    );
  }
}

/// The floating window a minimised call collapses into.
class _MinimisedCall extends StatefulWidget {
  const _MinimisedCall({required this.call});

  final CurrentCall call;

  @override
  State<_MinimisedCall> createState() => _MinimisedCallState();
}

class _MinimisedCallState extends State<_MinimisedCall> {
  static const _width = 108.0;
  static const _height = 144.0;

  Offset _offset = const Offset(16, 96);

  @override
  Widget build(BuildContext context) {
    final colors = context.callColors;
    final track = widget.call.remoteVideo;

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onTap: callService.expand,
        onPanUpdate: (d) => setState(() {
          final screen = MediaQuery.sizeOf(context);
          final next = _offset + d.delta;
          _offset = Offset(
            next.dx.clamp(0.0, screen.width - _width),
            next.dy.clamp(0.0, screen.height - _height),
          );
        }),
        child: Material(
          elevation: 8,
          color: colors.callSurface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: AnimatedContainer(
            duration: Motion.medium,
            width: _width,
            height: _height,
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
                : Center(
                    child: Icon(
                      widget.call.isVideo ? Icons.videocam : Icons.call,
                      color: colors.onCallSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
