import 'package:flutter/material.dart';
import 'package:nullgram/l10n/l10n.dart';

import '../../../services/call_models.dart';
import '../../../services/call_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/call_colors.dart';

/// The row of call actions. Shows accept/decline while ringing in, and the
/// mute/speaker/video/flip/hang-up set otherwise.
class CallControls extends StatelessWidget {
  const CallControls({
    super.key,
    required this.call,
    required this.colors,
    required this.speakerOn,
    required this.onToggleSpeaker,
  });

  final CurrentCall call;
  final CallColors colors;
  final bool speakerOn;
  final VoidCallback onToggleSpeaker;

  /// Answers the call, reporting a denied microphone or camera.
  ///
  /// Without this the button would simply do nothing when the user has
  /// refused the permission the call needs.
  Future<void> _accept(BuildContext context) async {
    final message = call.isVideo
        ? context.l10n.cameraAccessDenied
        : context.l10n.microphonePermissionRequired;
    final accepted = await callService.accept();
    if (!context.mounted || accepted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (call.uiState == CallUiState.ringingIn) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallAction(
            icon: Icons.call_end,
            label: context.l10n.decline,
            background: colors.decline,
            foreground: Colors.white,
            onTap: callService.hangUp,
          ),
          CallAction(
            icon: Icons.call,
            label: context.l10n.accept,
            background: colors.accept,
            foreground: Colors.white,
            onTap: () => _accept(context),
          ),
        ],
      );
    }

    final neutralBg = colors.onCallSurface.withValues(alpha: 0.16);
    // Each action takes an equal share of the row: four captions do not fit
    // side by side at their natural width on a narrow screen, and a longer
    // translation would overflow even where English fits.
    final actions = <Widget>[
      CallAction(
        icon: call.isMuted ? Icons.mic_off : Icons.mic,
        label: context.l10n.mute,
        background: call.isMuted ? colors.onCallSurface : neutralBg,
        foreground: call.isMuted ? colors.callSurface : colors.onCallSurface,
        onTap: callService.toggleMute,
      ),
      if (call.isVideoEnabled)
        CallAction(
          icon: Icons.flip_camera_ios,
          label: context.l10n.flipCamera,
          background: neutralBg,
          foreground: colors.onCallSurface,
          onTap: callService.switchCamera,
        )
      else
        CallAction(
          icon: speakerOn ? Icons.volume_up : Icons.volume_down,
          label: context.l10n.speaker,
          background: speakerOn ? colors.onCallSurface : neutralBg,
          foreground: speakerOn ? colors.callSurface : colors.onCallSurface,
          onTap: onToggleSpeaker,
        ),
      CallAction(
        icon: call.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
        label: context.l10n.video,
        background: call.isVideoEnabled ? colors.onCallSurface : neutralBg,
        foreground: call.isVideoEnabled
            ? colors.callSurface
            : colors.onCallSurface,
        onTap: () => callService.toggleVideo(context.l10n.cameraAccessDenied),
      ),
      CallAction(
        icon: Icons.call_end,
        label: context.l10n.endCall,
        background: colors.decline,
        foreground: Colors.white,
        onTap: callService.hangUp,
      ),
    ];
    return Row(
      children: [for (final action in actions) Expanded(child: action)],
    );
  }
}

/// A circular call control button with a caption beneath it.
class CallAction extends StatelessWidget {
  const CallAction({
    super.key,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: context.callColors.onCallSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
