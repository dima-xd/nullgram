import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';
import 'package:nullgram/services/call_service.dart';

/// Records what the service asks of the engine and lets tests push frames.
class FakeEngine implements TgCallsEngine {
  FakeEngine({this.permissionGranted = true});

  final bool permissionGranted;
  final session = FakeSession();
  final permissionRequests = <bool>[];

  /// When set, [start] waits on it, modelling a slow native handshake.
  Completer<void>? startGate;

  @override
  List<String> get supportedVersions => const ['9.0.0'];

  @override
  Future<bool> ensureMediaPermissions({required bool video}) async {
    permissionRequests.add(video);
    return permissionGranted;
  }

  @override
  Future<TgCallSession> start(TgCallConfig config) async {
    final gate = startGate;
    if (gate != null) await gate.future;
    return session;
  }
}

class FakeSession implements TgCallSession {
  final local = StreamController<TgVideoTrack>.broadcast();
  final remote = StreamController<TgVideoTrack>.broadcast();
  final videoCalls = <bool>[];
  int switchCameraCalls = 0;
  bool stopped = false;

  @override
  Stream<TgVideoTrack> get localVideo => local.stream;
  @override
  Stream<TgVideoTrack> get remoteVideo => remote.stream;
  @override
  Stream<Uint8List> get outgoingSignaling => const Stream.empty();
  @override
  Stream<TgCallState> get state => const Stream.empty();
  @override
  Stream<double> get audioLevel => const Stream.empty();
  @override
  void pushSignaling(Uint8List data) {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setVideoEnabled(bool enabled) async => videoCalls.add(enabled);
  @override
  Future<void> switchCamera() async => switchCameraCalls++;
  @override
  Future<void> setAudioRoute(TgAudioRoute route) async {}
  @override
  Future<void> stop() async {
    stopped = true;
    await local.close();
    await remote.close();
  }
}

/// A TDLib `updateCall` payload in the shape the service consumes.
Map<String, dynamic> callUpdate({
  required String stateType,
  bool isVideo = false,
  bool isOutgoing = true,
  int id = 42,
  int userId = 7,
}) =>
    {
      '@type': 'UpdateCall',
      'call': {
        'id': id,
        'userId': userId,
        'isOutgoing': isOutgoing,
        'isVideo': isVideo,
        'state': {
          '@type': stateType,
          'servers': <dynamic>[],
          'encryptionKey': <int>[],
          'emojis': <String>[],
        },
      },
    };

void main() {
  late StreamController<Map<String, dynamic>> updates;

  setUp(() => updates = StreamController<Map<String, dynamic>>.broadcast());
  tearDown(() => updates.close());

  CallService build(FakeEngine engine, {List<int>? created}) => CallService(
        callUpdates: updates.stream,
        engine: engine,
        sendSignaling: (_, _) async {},
        createCall: (userId, _, _) async => created?.add(userId),
        acceptCall: (_, _) async {},
        discardCall: (_, _) async {},
      );

  test('a denied camera stops an outgoing video call before TDLib', () async {
    final engine = FakeEngine(permissionGranted: false);
    final created = <int>[];
    final service = build(engine, created: created);

    await service.startCall(userId: 7, isVideo: true);

    expect(engine.permissionRequests, [true]);
    expect(created, isEmpty);
    service.dispose();
  });

  test('a granted camera lets the outgoing video call through', () async {
    final engine = FakeEngine();
    final created = <int>[];
    final service = build(engine, created: created);

    await service.startCall(userId: 7, isVideo: true);

    expect(created, [7]);
    service.dispose();
  });

  test('toggleVideo without permission leaves the call on audio', () async {
    final engine = FakeEngine(permissionGranted: false);
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady'));
    await Future<void>.delayed(Duration.zero);

    await service.toggleVideo('no camera for you');

    expect(service.current?.isVideoEnabled, isFalse);
    expect(service.current?.errorMessage, 'no camera for you');
    expect(engine.session.videoCalls, isEmpty);
    service.dispose();
  });

  test('toggleVideo with permission enables the camera', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady'));
    await Future<void>.delayed(Duration.zero);

    await service.toggleVideo('denied');

    expect(service.current?.isVideoEnabled, isTrue);
    expect(engine.session.videoCalls, [true]);
    service.dispose();
  });

  test('a remote track arriving and leaving updates the call', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    engine.session.remote
        .add(const TgVideoTrack(textureId: 3, width: 640, height: 480));
    await Future<void>.delayed(Duration.zero);
    expect(service.current?.remoteVideo.isActive, isTrue);

    engine.session.remote.add(TgVideoTrack.empty);
    await Future<void>.delayed(Duration.zero);
    expect(service.current?.remoteVideo.isActive, isFalse);
    service.dispose();
  });

  test('switchCamera flips the facing flag', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    await service.switchCamera();

    expect(engine.session.switchCameraCalls, 1);
    expect(service.current?.isFrontCamera, isFalse);
    service.dispose();
  });

  test('minimize and expand toggle the flag', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStatePending'));
    await Future<void>.delayed(Duration.zero);

    service.minimize();
    expect(service.current?.isMinimized, isTrue);

    service.expand();
    expect(service.current?.isMinimized, isFalse);
    service.dispose();
  });

  test('a second call does not inherit the first call identity', () async {
    final engine = FakeEngine();
    final service = build(engine);

    updates.add(callUpdate(stateType: 'CallStatePending'));
    await Future<void>.delayed(Duration.zero);
    updates.add(callUpdate(stateType: 'CallStateDiscarded'));
    await Future<void>.delayed(Duration.zero);
    updates.add(callUpdate(stateType: 'CallStatePending', id: 99, userId: 8));
    await Future<void>.delayed(Duration.zero);

    expect(service.current?.callId, 99);
    expect(service.current?.userId, 8);
    service.dispose();
  });

  test('a minimized first call leaves the second call expanded', () async {
    final engine = FakeEngine();
    final service = build(engine);

    updates.add(callUpdate(stateType: 'CallStatePending'));
    await Future<void>.delayed(Duration.zero);
    service.minimize();
    updates.add(callUpdate(stateType: 'CallStateDiscarded'));
    await Future<void>.delayed(Duration.zero);
    updates.add(callUpdate(stateType: 'CallStatePending', id: 99, userId: 8));
    await Future<void>.delayed(Duration.zero);

    expect(service.current?.isMinimized, isFalse);
    service.dispose();
  });

  test('a video call starts with video already enabled', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    expect(service.current?.isVideoEnabled, isTrue);
    service.dispose();
  });

  test('an audio call starts with video disabled', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady'));
    await Future<void>.delayed(Duration.zero);

    expect(service.current?.isVideoEnabled, isFalse);
    service.dispose();
  });

  test('a terminal state clears the video tracks', () async {
    final engine = FakeEngine();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    engine.session.remote
        .add(const TgVideoTrack(textureId: 3, width: 640, height: 480));
    await Future<void>.delayed(Duration.zero);
    expect(service.current?.remoteVideo.isActive, isTrue);

    updates.add(callUpdate(stateType: 'CallStateDiscarded', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    expect(service.current?.remoteVideo.isActive, isFalse);
    expect(service.current?.localVideo.isActive, isFalse);
    service.dispose();
  });

  test('a discard during the engine start stops the session', () async {
    final engine = FakeEngine()..startGate = Completer<void>();
    final service = build(engine);
    updates.add(callUpdate(stateType: 'CallStateReady', isVideo: true));
    await Future<void>.delayed(Duration.zero);

    updates.add(callUpdate(stateType: 'CallStateDiscarded', isVideo: true));
    await Future<void>.delayed(Duration.zero);
    expect(engine.session.stopped, isFalse);

    engine.startGate!.complete();
    await Future<void>.delayed(Duration.zero);

    expect(engine.session.stopped, isTrue);
    service.dispose();
  });
}
