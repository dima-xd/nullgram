import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';

import '../../services/call_models.dart';
import '../../services/call_service.dart';
import '../../tdlib/tdlib_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/call_colors.dart';
import '../../theme/motion.dart';
import '../chat/widgets/chat_avatar.dart';

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

  bool _speakerOn = false;

  /// When the call first became active, used to render the live timer.
  DateTime? _connectedAt;
  Timer? _ticker;

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

    if (call.uiState == CallUiState.active && _connectedAt == null) {
      _connectedAt = DateTime.now();
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    callService.removeListener(_onCall);
    _ticker?.cancel();
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

    return Scaffold(
      backgroundColor: calls.callSurface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: callService,
          builder: (context, _) {
            final call = callService.current;
            if (call == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _user,
                    builder: (context, snap) {
                      final user = snap.data;
                      final ringing =
                          call.uiState == CallUiState.ringingOut ||
                              call.uiState == CallUiState.ringingIn;
                      final avatar = ChatAvatar(
                        chat: _avatarChat(user, call.userId),
                        radius: 56,
                      );
                      return Column(
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
                  ),
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
                    Text(call.emojis.join(' '),
                        style: const TextStyle(fontSize: 30)),
                  ],
                  const Spacer(flex: 3),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: KeyedSubtree(
                      key: ValueKey(call.uiState == CallUiState.ringingIn),
                      child: _Controls(
                        call: call,
                        colors: calls,
                        speakerOn: _speakerOn,
                        onToggleSpeaker: _toggleSpeaker,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    callService.setAudioRoute(
      _speakerOn ? TgAudioRoute.speaker : TgAudioRoute.earpiece,
    );
  }

  String _statusLabel(CurrentCall call) => switch (call.uiState) {
        CallUiState.ringingOut => 'Calling…',
        CallUiState.ringingIn => 'Incoming call',
        CallUiState.exchangingKeys => 'Exchanging keys…',
        CallUiState.active => _elapsed(),
        CallUiState.ending => 'Ending…',
        CallUiState.ended => 'Call ended',
        CallUiState.error => call.errorMessage ?? 'Call failed',
      };

  String _elapsed() {
    if (_connectedAt == null) return 'Connected';
    final seconds = DateTime.now().difference(_connectedAt!).inSeconds;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.call,
    required this.colors,
    required this.speakerOn,
    required this.onToggleSpeaker,
  });

  final CurrentCall call;
  final CallColors colors;
  final bool speakerOn;
  final VoidCallback onToggleSpeaker;

  @override
  Widget build(BuildContext context) {
    if (call.uiState == CallUiState.ringingIn) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallAction(
            icon: Icons.call_end,
            label: 'Decline',
            background: colors.decline,
            foreground: Colors.white,
            onTap: callService.hangUp,
          ),
          _CallAction(
            icon: Icons.call,
            label: 'Accept',
            background: colors.accept,
            foreground: Colors.white,
            onTap: callService.accept,
          ),
        ],
      );
    }

    final neutralBg = colors.onCallSurface.withValues(alpha: 0.16);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallAction(
          icon: call.isMuted ? Icons.mic_off : Icons.mic,
          label: 'Mute',
          background: call.isMuted ? colors.onCallSurface : neutralBg,
          foreground: call.isMuted ? colors.callSurface : colors.onCallSurface,
          onTap: callService.toggleMute,
        ),
        _CallAction(
          icon: speakerOn ? Icons.volume_up : Icons.volume_down,
          label: 'Speaker',
          background: speakerOn ? colors.onCallSurface : neutralBg,
          foreground: speakerOn ? colors.callSurface : colors.onCallSurface,
          onTap: onToggleSpeaker,
        ),
        if (call.isVideo)
          _CallAction(
            icon: call.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Video',
            background: call.isVideoEnabled ? colors.onCallSurface : neutralBg,
            foreground:
                call.isVideoEnabled ? colors.callSurface : colors.onCallSurface,
            onTap: callService.toggleVideo,
          ),
        _CallAction(
          icon: Icons.call_end,
          label: 'End',
          background: colors.decline,
          foreground: Colors.white,
          onTap: callService.hangUp,
        ),
      ],
    );
  }
}

/// A circular call control button with a caption beneath it.
class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(icon, color: foreground, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: context.callColors.onCallSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
