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
      : _recorder = recorder ?? record.AudioRecorder();

  final record.AudioRecorder _recorder;
  StreamController<record.Amplitude>? _amplitudeController;

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
    _bindAmplitudeStream();
  }

  void _bindAmplitudeStream() {
    _amplitudeController ??= StreamController<record.Amplitude>.broadcast();
    _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen(
      (event) {
        _amplitudeController?.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        _amplitudeController?.addError(error, stackTrace);
      },
    );
  }

  @override
  Future<void> pauseRecording() => _recorder.pause();

  @override
  Future<void> resumeRecording() => _recorder.resume();

  @override
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    await _amplitudeController?.close();
    _amplitudeController = null;
    return path;
  }

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Stream<record.Amplitude> onAmplitude() {
    _bindAmplitudeStream();
    return _amplitudeController!.stream;
  }

  @override
  Future<void> dispose() async {
    if (_amplitudeController != null) {
      await _amplitudeController!.close();
      _amplitudeController = null;
    }
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
