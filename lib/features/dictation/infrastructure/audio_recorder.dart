import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Abstraction over the platform audio recorder so we can swap implementations
/// for testing or platform-specific backends.
abstract class AudioRecorder {
  Future<void> startRecording({
    required String filePath,
    int bitRate,
    int sampleRate,
  });

  Future<void> pauseRecording();

  Future<void> resumeRecording();

  Future<String?> stopRecording();

  Future<bool> isRecording();

  Stream<Amplitude> onAmplitude();

  Future<void> dispose();
}

class DefaultAudioRecorder implements AudioRecorder {
  DefaultAudioRecorder([Record? record]) : _record = record ?? Record();

  final Record _record;
  StreamController<Amplitude>? _amplitudeController;

  @override
  Future<void> startRecording({
    required String filePath,
    int bitRate = 160000,
    int sampleRate = 48000,
  }) async {
    if (!await _record.hasPermission()) {
      throw const RecordingPermissionException('Microphone permission not granted');
    }
    await _record.start(
      path: filePath,
      encoder: AudioEncoder.wav,
      bitRate: bitRate,
      samplingRate: sampleRate,
    );
    _bindAmplitudeStream();
  }

  void _bindAmplitudeStream() {
    _amplitudeController ??= StreamController<Amplitude>.broadcast();
    _record.onAmplitudeChanged(const Duration(milliseconds: 200)).listen(
      (event) {
        _amplitudeController?.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        _amplitudeController?.addError(error, stackTrace);
      },
    );
  }

  @override
  Future<void> pauseRecording() => _record.pause();

  @override
  Future<void> resumeRecording() => _record.resume();

  @override
  Future<String?> stopRecording() async {
    final path = await _record.stop();
    await _amplitudeController?.close();
    _amplitudeController = null;
    return path;
  }

  @override
  Future<bool> isRecording() => _record.isRecording();

  @override
  Stream<Amplitude> onAmplitude() {
    _bindAmplitudeStream();
    return _amplitudeController!.stream;
  }

  @override
  Future<void> dispose() async {
    if (_amplitudeController != null) {
      await _amplitudeController!.close();
      _amplitudeController = null;
    }
    _record.dispose();
  }
}

class RecordingPermissionException implements Exception {
  const RecordingPermissionException(this.message);

  final String message;

  @override
  String toString() => 'RecordingPermissionException: $message';
}

final audioRecorderProvider = Provider<AudioRecorder>((ref) {
  final recorder = DefaultAudioRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
