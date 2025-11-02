import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' as record;

/// Abstraction over the platform audio recorder so we can swap implementations.
abstract class DictationRecorder {
  Future<void> startRecording({
    required String filePath,
    int bitRate,
    int sampleRate,
  });

  Future<void> pauseRecording();

  Future<void> resumeRecording();

  Future<String?> stopRecording();

  Future<bool> isRecording();

  Stream<record.Amplitude> onAmplitude();

  Future<void> dispose();
}

class DefaultDictationRecorder implements DictationRecorder {
  DefaultDictationRecorder([record.AudioRecorder? recorder])
      : _recorder = recorder ?? record.AudioRecorder() {
    _amplitudeStream = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .asBroadcastStream();
  }

  final record.AudioRecorder _recorder;
  late final Stream<record.Amplitude> _amplitudeStream;

  record.RecordConfig _buildConfig({
    required int bitRate,
    required int sampleRate,
  }) {
    return record.RecordConfig(
      encoder: record.AudioEncoder.wav,
      bitRate: bitRate,
      sampleRate: sampleRate,
    );
  }

  @override
  Future<void> startRecording({
    required String filePath,
    int bitRate = 160000,
    int sampleRate = 48000,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw const RecordingPermissionException('Microphone permission not granted');
    }
    final config = _buildConfig(bitRate: bitRate, sampleRate: sampleRate);
    await _recorder.start(
      config,
      path: filePath,
    );
  }

  @override
  Future<void> pauseRecording() => _recorder.pause();

  @override
  Future<void> resumeRecording() => _recorder.resume();

  @override
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Stream<record.Amplitude> onAmplitude() => _amplitudeStream;

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

class RecordingPermissionException implements Exception {
  const RecordingPermissionException(this.message);

  final String message;

  @override
  String toString() => 'RecordingPermissionException: $message';
}

final dictationRecorderProvider = Provider<DictationRecorder>((ref) {
  final recorder = DefaultDictationRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
