import 'package:ntgcalls_flutter/tgcalls.dart';

/// High-level call state the UI renders, derived from TDLib + media state.
enum CallUiState {
  ringingOut,
  ringingIn,
  exchangingKeys,
  active,
  ending,
  ended,
  error;

  bool get isTerminal => this == CallUiState.ended || this == CallUiState.error;
}

/// Immutable snapshot of the one active call.
class CurrentCall {
  const CurrentCall({
    required this.callId,
    required this.userId,
    required this.isOutgoing,
    required this.isVideo,
    required this.uiState,
    this.emojis = const [],
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.isVideoEnabled = false,
    this.localVideo = TgVideoTrack.empty,
    this.remoteVideo = TgVideoTrack.empty,
    this.isFrontCamera = true,
    this.isMinimized = false,
    this.connectedAtMs,
    this.errorMessage,
  });

  final int callId;
  final int userId;
  final bool isOutgoing;
  final bool isVideo;
  final CallUiState uiState;
  final List<String> emojis;
  final bool isMuted;

  /// Whether audio is routed to the speaker; the native side turns the
  /// speakerphone on when the call starts.
  final bool isSpeakerOn;
  final bool isVideoEnabled;

  /// Our own camera feed, empty while the camera is off.
  final TgVideoTrack localVideo;

  /// The peer's camera feed, empty while they have video off.
  final TgVideoTrack remoteVideo;

  final bool isFrontCamera;

  /// Whether the call is collapsed to the in-app floating window.
  final bool isMinimized;
  final int? connectedAtMs;
  final String? errorMessage;

  CurrentCall copyWith({
    CallUiState? uiState,
    List<String>? emojis,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoEnabled,
    TgVideoTrack? localVideo,
    TgVideoTrack? remoteVideo,
    bool? isFrontCamera,
    bool? isMinimized,
    int? connectedAtMs,
    String? errorMessage,
  }) {
    return CurrentCall(
      callId: callId,
      userId: userId,
      isOutgoing: isOutgoing,
      isVideo: isVideo,
      uiState: uiState ?? this.uiState,
      emojis: emojis ?? this.emojis,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      localVideo: localVideo ?? this.localVideo,
      remoteVideo: remoteVideo ?? this.remoteVideo,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isMinimized: isMinimized ?? this.isMinimized,
      connectedAtMs: connectedAtMs ?? this.connectedAtMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
