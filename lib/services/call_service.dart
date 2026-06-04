import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';
import 'package:ntgcalls_flutter/tgcalls_method_channel.dart';

import '../tdlib/tdlib_client.dart';
import 'call_config_builder.dart';
import 'call_models.dart';
import 'call_state_reducer.dart';

/// Sends raw signaling bytes for a call to the signaling backend (TDLib).
typedef SendSignaling = Future<void> Function(int callId, Uint8List data);

/// Places an outgoing call via the signaling backend (TDLib `createCall`).
typedef CreateCall = Future<void> Function(
    int userId, bool isVideo, List<String> versions);

/// Accepts an incoming call via the signaling backend (TDLib `acceptCall`).
typedef AcceptCall = Future<void> Function(int callId, List<String> versions);

/// Ends/declines a call via the signaling backend (TDLib `discardCall`).
typedef DiscardCall = Future<void> Function(int callId, bool isVideo);

/// Owns the single active call: bridges TDLib signaling to the media engine.
class CallService extends ChangeNotifier {
  CallService({
    required Stream<Map<String, dynamic>> callUpdates,
    required TgCallsEngine engine,
    required SendSignaling sendSignaling,
    CreateCall? createCall,
    AcceptCall? acceptCall,
    DiscardCall? discardCall,
  })  : _engine = engine,
        _sendSignaling = sendSignaling,
        _createCall = createCall ?? ((_, _, _) async {}),
        _acceptCall = acceptCall ?? ((_, _) async {}),
        _discardCall = discardCall ?? ((_, _) async {}) {
    _sub = callUpdates.listen(_onUpdate);
  }

  final TgCallsEngine _engine;
  final SendSignaling _sendSignaling;
  final CreateCall _createCall;
  final AcceptCall _acceptCall;
  final DiscardCall _discardCall;

  late final StreamSubscription<Map<String, dynamic>> _sub;
  StreamSubscription<Uint8List>? _outSub;
  StreamSubscription<TgCallState>? _engineStateSub;
  TgCallSession? _session;

  CurrentCall? _current;
  CurrentCall? get current => _current;

  List<String> get supportedVersions => _engine.supportedVersions;

  void _onUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'UpdateCall':
        _onCall(update['call'] as Map<String, dynamic>);
      case 'UpdateNewCallSignalingData':
        _session?.pushSignaling(tdBytes(update['data']));
    }
  }

  void _onCall(Map<String, dynamic> call) {
    final callId = call['id'] as int;
    final isOutgoing = call['isOutgoing'] as bool? ?? false;
    final isVideo = call['isVideo'] as bool? ?? false;
    final state = call['state'] as Map<String, dynamic>;
    debugPrint('[call] state=${state['@type']} id=$callId outgoing=$isOutgoing'
        '${state['@type'] == 'callStateDiscarded' ? ' reason=${state['reason']?['@type']}' : ''}'
        '${state['@type'] == 'callStateError' ? ' error=${state['error']}' : ''}');
    final uiState = mapTdCallState(state, isOutgoing: isOutgoing);

    _current = (_current ??
            CurrentCall(
              callId: callId,
              userId: call['userId'] as int,
              isOutgoing: isOutgoing,
              isVideo: isVideo,
              uiState: uiState,
            ))
        .copyWith(uiState: uiState);

    if (state['@type'] == 'CallStateReady' && _session == null) {
      _startEngine(callId, isOutgoing, isVideo, state);
    }
    if (uiState.isTerminal) {
      _teardown();
    }
    notifyListeners();
  }

  Future<void> _startEngine(
    int callId,
    bool isOutgoing,
    bool isVideo,
    Map<String, dynamic> readyState,
  ) async {
    final config =
        buildTgCallConfig(readyState, isOutgoing: isOutgoing, isVideo: isVideo);
    debugPrint('[call] ready -> starting engine: servers=${config.servers.length} '
        'keyLen=${config.encryptionKey.length} allowP2p=${config.allowP2p}');
    final session = await _engine.start(config);
    _session = session;
    _current = _current?.copyWith(emojis: emojisFromReady(readyState));
    _outSub =
        session.outgoingSignaling.listen((data) => _sendSignaling(callId, data));
    _engineStateSub = session.state.listen((_) => notifyListeners());
    notifyListeners();
  }

  /// Starts an outgoing call to [userId].
  Future<void> startCall({required int userId, required bool isVideo}) {
    debugPrint('[call] startCall user=$userId video=$isVideo '
        'versions=${_engine.supportedVersions}');
    return _createCall(userId, isVideo, _engine.supportedVersions);
  }

  /// Accepts the current incoming call.
  Future<void> accept() async {
    final c = _current;
    if (c != null) await _acceptCall(c.callId, _engine.supportedVersions);
  }

  /// Ends or declines the current call.
  Future<void> hangUp() async {
    final c = _current;
    if (c != null) await _discardCall(c.callId, c.isVideo);
  }

  /// Toggles the microphone mute state.
  Future<void> toggleMute() async {
    final c = _current;
    if (c == null || _session == null) return;
    final next = !c.isMuted;
    await _session!.setMuted(next);
    _current = c.copyWith(isMuted: next);
    notifyListeners();
  }

  /// Toggles local video on/off.
  Future<void> toggleVideo() async {
    final c = _current;
    if (c == null || _session == null) return;
    final next = !c.isVideoEnabled;
    await _session!.setVideoEnabled(next);
    _current = c.copyWith(isVideoEnabled: next);
    notifyListeners();
  }

  /// Switches between front/back cameras.
  Future<void> switchCamera() async => _session?.switchCamera();

  /// Routes audio to [route].
  Future<void> setAudioRoute(TgAudioRoute route) async =>
      _session?.setAudioRoute(route);

  void _teardown() {
    _outSub?.cancel();
    _outSub = null;
    _engineStateSub?.cancel();
    _engineStateSub = null;
    _session?.stop();
    _session = null;
  }

  @override
  void dispose() {
    _sub.cancel();
    _teardown();
    super.dispose();
  }
}

/// App-wide call service, created in `main` after TDLib updates are initialised.
late final CallService callService;

/// Builds the production [CallService] wired to TDLib and the channel engine.
CallService buildCallService() {
  final engine = MethodChannelTgCalls();
  engine.warmUp();
  return CallService(
    callUpdates: TDLibClient.callUpdates,
    engine: engine,
    sendSignaling: (callId, data) =>
        TDLibClient.sendCallSignalingData(callId: callId, data: data),
    createCall: (userId, isVideo, versions) => TDLibClient.createCall(
        userId: userId, isVideo: isVideo, protocolVersions: versions),
    acceptCall: (callId, versions) =>
        TDLibClient.acceptCall(callId: callId, protocolVersions: versions),
    discardCall: (callId, isVideo) =>
        TDLibClient.discardCall(callId: callId, isVideo: isVideo),
  );
}
