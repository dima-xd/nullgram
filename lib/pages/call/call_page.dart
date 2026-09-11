import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/call_models.dart';
import '../../services/call_service.dart';
import '../../tdlib/tdlib_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/call_colors.dart';
import '../../theme/motion.dart';
import '../chat/widgets/chat_avatar.dart';
import 'widgets/call_controls.dart';
import 'widgets/local_preview.dart';
import 'widgets/video_stage.dart';
import 'package:nullgram/l10n/l10n.dart';

/// Full-screen call UI driven by [CallService]. Shows the caller avatar, a live
/// duration once connected, and adaptive controls for ringing vs. active calls.
class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  /// Resolved once so it doesn't re-fetch on every [CallService] notification.
  Future<Map<String, dynamic>?>? _user;
  int? _resolvedFor;

  /// While true the remote track occupies the small window instead.
  bool _swapped = false;

  /// Controls auto-hide during a video call; always visible otherwise.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// Redraws once a second so the live duration keeps ticking.
  Timer? _ticker;

  /// The last error surfaced, so a repeated notification isn't re-shown.
  String? _shownError;

  @override
  void initState() {
    super.initState();
    callService.addListener(_onCall);
    _onCall();
  }

  void _onCall() {
    final call = callService.current;
    if (call == null) return;

    if (_resolvedFor != call.userId) {
      _resolvedFor = call.userId;
      _user = TDLibClient.getUser(userId: call.userId);
    }

    if (call.uiState == CallUiState.active) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
    if (_videoMode(call)) {
      if (_hideTimer == null) _revealControls();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
    }

    final error = call.errorMessage;
    if (error != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        }
      });
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    callService.removeListener(_onCall);
    _ticker?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _avatarChat(Map<String, dynamic>? user, int userId) => {
        'id': userId,
        'title': _name(user),
        'photo': user?['profilePhoto'],
        'user': user,
      };

  String _name(Map<String, dynamic>? user) {
    final first = user?['firstName'] as String? ?? '';
    final last = user?['lastName'] as String? ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Unknown' : name;
  }

  @override
  Widget build(BuildContext context) {
    final calls = context.callColors;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) callService.minimize();
      },
      child: Scaffold(
        backgroundColor: calls.callSurface,
        body: AnimatedBuilder(
          animation: callService,
          builder: (context, _) {
            final call = callService.current;
            if (call == null) return const SizedBox.shrink();

            if (!_videoMode(call)) {
              return _audioLayout(call, calls, textTheme);
            }
            return _videoLayout(call, calls, textTheme);
          },
        ),
      ),
    );
  }

  /// The original avatar-and-controls layout, used for audio calls.
  Widget _audioLayout(
    CurrentCall call,
    CallColors calls,
    TextTheme textTheme,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            _identity(call, calls, textTheme),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                _statusLabel(call),
                key: ValueKey(call.uiState),
                style: textTheme.titleMedium?.copyWith(
                  color: calls.onCallSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (call.emojis.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(call.emojis.join(' '), style: const TextStyle(fontSize: 30)),
            ],
            const Spacer(flex: 3),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: KeyedSubtree(
                key: ValueKey(call.uiState == CallUiState.ringingIn),
                child: CallControls(
                  call: call,
                  colors: calls,
                  speakerOn: call.isSpeakerOn,
                  onToggleSpeaker: () =>
                      callService.setSpeaker(!call.isSpeakerOn),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Full-screen video with the other track in a floating window.
  Widget _videoLayout(
    CurrentCall call,
    CallColors calls,
    TextTheme textTheme,
  ) {
    final swapped = _swapped &&
        (call.localVideo.isActive || !call.remoteVideo.isActive);
    final stageTrack = swapped ? call.localVideo : call.remoteVideo;
    final windowTrack = swapped ? call.remoteVideo : call.localVideo;

    return GestureDetector(
      onTap: _revealControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoStage(
            track: stageTrack,
            placeholder: Center(
              child: _identity(call, calls, textTheme),
            ),
          ),
          const VideoScrim(),
          if (windowTrack.isActive)
            Positioned.fill(
              child: SafeArea(
                child: LocalPreview(
                  track: windowTrack,
                  onTap: () => setState(() => _swapped = !_swapped),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: Motion.medium,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.expand_more),
                      color: calls.onCallSurface,
                      tooltip: context.l10n.minimize,
                      onPressed: callService.minimize,
                    ),
                    Expanded(
                      child: Text(
                        _statusLabel(call),
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium
                            ?.copyWith(color: calls.onCallSurface),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: AnimatedSlide(
                offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
                duration: Motion.medium,
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: CallControls(
                    call: call,
                    colors: calls,
                    speakerOn: call.isSpeakerOn,
                    onToggleSpeaker: () =>
                        callService.setSpeaker(!call.isSpeakerOn),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar plus name, shared by both layouts.
  Widget _identity(
    CurrentCall call,
    CallColors calls,
    TextTheme textTheme,
  ) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _user,
      builder: (context, snap) {
        final user = snap.data;
        final ringing = call.uiState == CallUiState.ringingOut ||
            call.uiState == CallUiState.ringingIn;
        final avatar = ChatAvatar(
          chat: _avatarChat(user, call.userId),
          radius: 56,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ringing
                ? avatar
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1.0,
                      end: 1.06,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOut,
                    )
                : avatar,
            const SizedBox(height: 20),
            Text(
              _name(user),
              style: textTheme.headlineSmall
                  ?.copyWith(color: calls.onCallSurface),
            ),
          ],
        );
      },
    );
  }

  void _revealControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  /// Video calls hide their chrome; audio calls always show it.
  bool _videoMode(CurrentCall call) =>
      call.remoteVideo.isActive || call.localVideo.isActive;

  String _statusLabel(CurrentCall call) => switch (call.uiState) {
        CallUiState.ringingOut => 'Calling…',
        CallUiState.ringingIn =>
          call.isVideo ? context.l10n.videoCall : 'Incoming call',
        CallUiState.exchangingKeys => 'Exchanging keys…',
        CallUiState.active => _elapsed(call),
        CallUiState.ending => 'Ending…',
        CallUiState.ended => 'Call ended',
        CallUiState.error => call.errorMessage ?? 'Call failed',
      };

  String _elapsed(CurrentCall call) {
    final startedAt = call.connectedAtMs;
    if (startedAt == null) return 'Connected';
    final seconds = (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
