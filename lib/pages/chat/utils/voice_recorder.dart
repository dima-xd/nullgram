import 'dart:async';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The result of a finished voice recording.
typedef VoiceRecording = ({String path, int duration, List<int> waveform});

/// Records a Telegram-compatible voice note.
///
/// Telegram expects Opus in an OGG container plus a 5-bit waveform, which it
/// draws in the bubble. Nothing reports that waveform after the fact, so the
/// microphone's amplitude is sampled while recording and packed on stop.
class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  /// How often the amplitude is sampled. Telegram's own waveforms are around
  /// this resolution, and it keeps the sample list small for a long note.
  static const Duration _samplePeriod = Duration(milliseconds: 100);

  /// The loudest and quietest levels mapped onto the 0-31 waveform range.
  /// Anything below the floor is silence; anything above the ceiling clips.
  static const double _floorDb = -50;
  static const double _ceilingDb = -5;

  final AudioRecorder _recorder;
  final List<int> _samples = [];

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  DateTime? _startedAt;
  String? _path;

  /// Whether a recording is in progress.
  bool get isRecording => _startedAt != null;

  /// How long the current recording has been running.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Whether the microphone permission has been granted.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts recording. Returns false when the microphone is unavailable.
  Future<bool> start() async {
    if (isRecording) return true;
    if (!await _recorder.hasPermission()) return false;

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 32000,
        numChannels: 1,
        sampleRate: 48000,
      ),
      path: path,
    );

    _path = path;
    _samples.clear();
    _startedAt = DateTime.now();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(_samplePeriod)
        .listen((amplitude) => _samples.add(_toSample(amplitude.current)));

    return true;
  }

  /// Stops recording and returns the finished note, or null when the recording
  /// produced no file or was too short to be worth sending.
  Future<VoiceRecording?> stop() async {
    if (!isRecording) return null;

    final elapsed = this.elapsed;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _startedAt = null;

    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;

    // A tap that never became a hold produces a fraction of a second of audio;
    // sending it is never what the user meant.
    if (elapsed < const Duration(milliseconds: 700)) return null;

    return (
      path: path,
      duration: math.max(1, elapsed.inSeconds),
      waveform: packWaveform(_samples),
    );
  }

  /// Aborts the recording and discards its file.
  Future<void> cancel() async {
    if (!isRecording) return;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _startedAt = null;
    _path = null;
    await _recorder.cancel();
  }

  /// A live stream of the current amplitude as a 0-1 level, for the recording
  /// indicator.
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(_samplePeriod)
      .map((amplitude) => _toSample(amplitude.current) / 31);

  void dispose() {
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
  }

  /// Maps a dBFS reading onto the waveform's 0-31 scale.
  static int _toSample(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    final normalized = (db - _floorDb) / (_ceilingDb - _floorDb);
    return (normalized.clamp(0.0, 1.0) * 31).round();
  }

  /// Packs 5-bit [samples] most-significant-bit first, the layout TDLib uses
  /// for `voiceNote.waveform`.
  static List<int> packWaveform(List<int> samples) {
    if (samples.isEmpty) return const [];

    final bytes = List<int>.filled((samples.length * 5 + 7) ~/ 8, 0);
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i].clamp(0, 31);
      for (var bit = 0; bit < 5; bit++) {
        // Read the sample's bits high-to-low and append them to the stream.
        final isSet = (value >> (4 - bit)) & 1 == 1;
        if (!isSet) continue;
        final globalBit = i * 5 + bit;
        bytes[globalBit ~/ 8] |= 1 << (7 - (globalBit % 8));
      }
    }
    return bytes;
  }
}
