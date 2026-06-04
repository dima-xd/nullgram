import 'package:flutter/material.dart';

import '../../main.dart' show navigatorKey;
import '../../services/call_service.dart';
import 'call_page.dart';

/// Wraps the app so any active call surfaces a full-screen [CallPage] from
/// anywhere (incoming or outgoing) and pops it when the call ends.
class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    callService.addListener(_sync);
  }

  void _sync() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final call = callService.current;
    final shouldOpen = call != null && !call.uiState.isTerminal;
    if (shouldOpen && !_open) {
      _open = true;
      nav
          .push(MaterialPageRoute(
            builder: (_) => const CallPage(),
            fullscreenDialog: true,
          ))
          .then((_) => _open = false);
    } else if (!shouldOpen && _open) {
      _open = false;
      nav.maybePop();
    }
  }

  @override
  void dispose() {
    callService.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
