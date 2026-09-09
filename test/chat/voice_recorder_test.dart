import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/chat/utils/voice_recorder.dart';

/// The 5-bit unpacking used to draw a received voice note's waveform.
///
/// Kept here as an independent reimplementation so the packing that ships a
/// voice note is verified against the layout TDLib documents, not against the
/// app's own decoder.
List<int> unpack(List<int> bytes, int sampleCount) {
  final samples = <int>[];
  for (var i = 0; i < sampleCount; i++) {
    var value = 0;
    for (var bit = 0; bit < 5; bit++) {
      final globalBit = i * 5 + bit;
      final byteIndex = globalBit ~/ 8;
      final bitIndex = 7 - (globalBit % 8);
      final isSet =
          byteIndex < bytes.length && (bytes[byteIndex] >> bitIndex) & 1 == 1;
      value = (value << 1) | (isSet ? 1 : 0);
    }
    samples.add(value);
  }
  return samples;
}

void main() {
  group('VoiceRecorder.packWaveform', () {
    test('round-trips 5-bit samples', () {
      final samples = [0, 1, 15, 31, 7, 22, 3, 30, 12];

      final packed = VoiceRecorder.packWaveform(samples);

      expect(unpack(packed, samples.length), samples);
    });

    test('packs five bits per sample', () {
      // Eight samples are exactly 40 bits, so five whole bytes.
      final packed = VoiceRecorder.packWaveform(List.filled(8, 31));

      expect(packed.length, 5);
      expect(packed, everyElement(0xff));
    });

    test('pads the trailing partial byte', () {
      final packed = VoiceRecorder.packWaveform([31]);

      expect(packed.length, 1);
      expect(packed.single, 0xf8);
    });

    test('clamps out-of-range samples into the 5-bit window', () {
      final packed = VoiceRecorder.packWaveform([99, -5]);

      expect(unpack(packed, 2), [31, 0]);
    });

    test('returns nothing for no samples', () {
      expect(VoiceRecorder.packWaveform(const []), isEmpty);
    });
  });
}
