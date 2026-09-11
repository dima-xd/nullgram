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
typedef CreateCall =
    Future<void> Function(int userId, bool isVideo, List<String> versions);

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
  }) : _engine = engine,
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
  StreamSubscription<TgVideoTrack>? _localVideoSub;
  StreamSubscription<TgVideoTrack>? _remoteVideoSub;
  TgCallSession? _session;

  /// Guards the async gap in [_startEngine]: `_session` is only assigned
  /// after the engine starts, so the state check alone lets a second
  /// `CallStateReady` in.
  bool _startingEngine = false;

  /// Bumped by [_teardown] so a start still in flight across its await can
  /// tell that its call has already ended.
  int _generation = 0;

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
    debugPrint(
      '[call] state=${state['@type']} id=$callId outgoing=$isOutgoing'
      '${state['@type'] == 'callStateDiscarded' ? ' reason=${state['reason']?['@type']}' : ''}'
      '${state['@type'] == 'callStateError' ? ' error=${state['error']}' : ''}',
    );
    final uiState = mapTdCallState(state, isOutgoing: isOutgoing);

    final existing = _current?.callId == callId ? _current : null;
    _current =
        (existing ??
                CurrentCall(
                  callId: callId,
                  userId: call['userId'] as int,
                  isOutgoing: isOutgoing,
                  isVideo: isVideo,
                  uiState: uiState,
                ))
            .copyWith(uiState: uiState);

    if (uiState == CallUiState.active && _current!.connectedAtMs == null) {
      _current = _current!.copyWith(
        connectedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (state['@type'] == 'CallStateReady' &&
        _session == null &&
        !_startingEngine) {
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
    final generation = _generation;
    _startingEngine = true;
    final config = buildTgCallConfig(
      readyState,
      isOutgoing: isOutgoing,
      isVideo: isVideo,
    );
    debugPrint(
      '[call] ready -> starting engine: servers=${config.servers.length} '
      'keyLen=${config.encryptionKey.length} allowP2p=${config.allowP2p}',
    );
    try {
      final session = await _engine.start(config);
      if (generation != _generation) {
        await session.stop();
        return;
      }
      _session = session;
      _current = _current?.copyWith(
        emojis: emojisFromReady(readyState),
        isVideoEnabled: isVideo,
      );
      _outSub = session.outgoingSignaling.listen(
        (data) => _sendSignaling(callId, data),
      );
      _engineStateSub = session.state.listen((_) => notifyListeners());
      _localVideoSub = session.localVideo.listen((track) {
        _current = _current?.copyWith(localVideo: track);
        notifyListeners();
      });
      _remoteVideoSub = session.remoteVideo.listen((track) {
        _current = _current?.copyWith(remoteVideo: track);
        notifyListeners();
      });
    } catch (error, stackTrace) {
      debugPrint('[call] engine start failed: $error');
      debugPrint('$stackTrace');
      if (generation == _generation) {
        _current = _current?.copyWith(errorMessage: '$error');
      }
    } finally {
      _startingEngine = false;
    }
    notifyListeners();
  }

  /// Starts an outgoing call to [userId].
  ///
  /// Media permissions are settled first: TDLib would otherwise create a video
  /// call this client has no camera access to fill.
  ///
  /// Returns false when media permission was denied, true once the request
  /// has been handed to TDLib.
  Future<bool> startCall({required int userId, required bool isVideo}) async {
    final granted = await _engine.ensureMediaPermissions(video: isVideo);
    if (!granted) {
      debugPrint('[call] startCall denied: media permissions');
      return false;
    }
    debugPrint(
      '[call] startCall user=$userId video=$isVideo '
      'versions=${_engine.supportedVersions}',
    );
    await _createCall(userId, isVideo, _engine.supportedVersions);
    return true;
  }

  /// Accepts the current incoming call.
  ///
  /// Returns false when media permission was denied, true once the acceptance
  /// has been handed to TDLib.
  Future<bool> accept() async {
    final c = _current;
    if (c == null) return false;
    final granted = await _engine.ensureMediaPermissions(video: c.isVideo);
    if (!granted) {
      debugPrint('[call] accept denied: media permissions');
      return false;
    }
    await _acceptCall(c.callId, _engine.supportedVersions);
    return true;
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
    _current = _current?.copyWith(isMuted: next);
    notifyListeners();
  }

  /// Toggles local video on/off, asking for the camera the first time.
  ///
  /// [deniedMessage] is surfaced as `errorMessage` when the camera permission
  /// is refused; the caller owns the wording so it can be localised.
  Future<void> toggleVideo(String deniedMessage) async {
    final c = _current;
    if (c == null || _session == null) return;
    final next = !c.isVideoEnabled;
    if (next && !await _engine.ensureMediaPermissions(video: true)) {
      _current = _current?.copyWith(errorMessage: deniedMessage);
      notifyListeners();
      return;
    }
    await _session!.setVideoEnabled(next);
    _current = _current?.copyWith(isVideoEnabled: next);
    notifyListeners();
  }

  /// Switches between front/back cameras.
  Future<void> switchCamera() async {
    final c = _current;
    if (c == null || _session == null) return;
    await _session!.switchCamera();
    _current = _current?.copyWith(isFrontCamera: !c.isFrontCamera);
    notifyListeners();
  }

  /// Collapses the call to the in-app floating window.
  void minimize() {
    final c = _current;
    if (c == null || c.isMinimized || c.uiState.isTerminal) return;
    _current = c.copyWith(isMinimized: true);
    notifyListeners();
  }

  /// Returns from the floating window to the full call screen.
  void expand() {
    if (_current == null || !_current!.isMinimized) return;
    _current = _current!.copyWith(isMinimized: false);
    notifyListeners();
  }

  /// Routes audio to the speaker or the earpiece.
  Future<void> setSpeaker(bool on) async {
    final c = _current;
    if (c == null || _session == null) return;
    await _session!.setAudioRoute(
      on ? TgAudioRoute.speaker : TgAudioRoute.earpiece,
    );
    _current = _current?.copyWith(isSpeakerOn: on);
    notifyListeners();
  }

  /// Routes audio to [route].
  Future<void> setAudioRoute(TgAudioRoute route) async =>
      _session?.setAudioRoute(route);

  void _teardown() {
    _outSub?.cancel();
    _outSub = null;
    _engineStateSub?.cancel();
    _engineStateSub = null;
    _localVideoSub?.cancel();
    _localVideoSub = null;
    _remoteVideoSub?.cancel();
    _remoteVideoSub = null;
    _current = _current?.copyWith(
      localVideo: TgVideoTrack.empty,
      remoteVideo: TgVideoTrack.empty,
    );
    _session?.stop();
    _session = null;
    _startingEngine = false;
    _generation++;
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
      userId: userId,
      isVideo: isVideo,
      protocolVersions: versions,
    ),
    acceptCall: (callId, versions) =>
        TDLibClient.acceptCall(callId: callId, protocolVersions: versions),
    discardCall: (callId, isVideo) =>
        TDLibClient.discardCall(callId: callId, isVideo: isVideo),
  );
}
