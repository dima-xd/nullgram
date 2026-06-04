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
    this.isVideoEnabled = false,
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
  final bool isVideoEnabled;
  final int? connectedAtMs;
  final String? errorMessage;

  CurrentCall copyWith({
    CallUiState? uiState,
    List<String>? emojis,
    bool? isMuted,
    bool? isVideoEnabled,
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
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      connectedAtMs: connectedAtMs ?? this.connectedAtMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
