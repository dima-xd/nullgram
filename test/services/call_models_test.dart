import 'package:flutter_test/flutter_test.dart';
import 'package:ntgcalls_flutter/tgcalls.dart';
import 'package:nullgram/services/call_models.dart';

CurrentCall _call() => const CurrentCall(
      callId: 1,
      userId: 2,
      isOutgoing: true,
      isVideo: true,
      uiState: CallUiState.active,
    );

void main() {
  group('CurrentCall', () {
    test('starts with empty tracks, front camera and not minimised', () {
      final call = _call();

      expect(call.localVideo, TgVideoTrack.empty);
      expect(call.remoteVideo, TgVideoTrack.empty);
      expect(call.isFrontCamera, isTrue);
      expect(call.isMinimized, isFalse);
    });

    test('copyWith replaces video tracks', () {
      const track = TgVideoTrack(textureId: 5, width: 640, height: 480);

      final call = _call().copyWith(remoteVideo: track);

      expect(call.remoteVideo, track);
      expect(call.localVideo, TgVideoTrack.empty);
    });

    test('copyWith keeps untouched fields', () {
      final call = _call().copyWith(isMinimized: true);

      expect(call.isMinimized, isTrue);
      expect(call.callId, 1);
      expect(call.isVideo, isTrue);
      expect(call.uiState, CallUiState.active);
    });

    test('copyWith flips the camera', () {
      final call = _call().copyWith(isFrontCamera: false);

      expect(call.isFrontCamera, isFalse);
    });
  });
}
