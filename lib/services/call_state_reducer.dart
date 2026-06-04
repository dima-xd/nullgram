import 'call_models.dart';

/// Maps a TDLib `CallState` map to the UI-facing [CallUiState].
CallUiState mapTdCallState(
  Map<String, dynamic> state, {
  required bool isOutgoing,
}) {
  switch (state['@type'] as String) {
    case 'CallStatePending':
      return isOutgoing ? CallUiState.ringingOut : CallUiState.ringingIn;
    case 'CallStateExchangingKeys':
      return CallUiState.exchangingKeys;
    case 'CallStateReady':
      return CallUiState.active;
    case 'CallStateHangingUp':
      return CallUiState.ending;
    case 'CallStateDiscarded':
      return CallUiState.ended;
    case 'CallStateError':
      return CallUiState.error;
    default:
      return CallUiState.exchangingKeys;
  }
}

/// Extracts the 4-emoji fingerprint from a `callStateReady` map.
List<String> emojisFromReady(Map<String, dynamic> readyState) {
  final raw = readyState['emojis'] as List?;
  return raw?.map((e) => e as String).toList() ?? const [];
}
