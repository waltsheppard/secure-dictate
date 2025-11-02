import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' as record show Amplitude;
import 'package:uuid/uuid.dart';

import '../domain/dictation_record.dart';
import '../infrastructure/audio_recorder.dart';
import '../infrastructure/dictation_local_store.dart';
import '../infrastructure/dictation_queue_worker.dart';
import '../domain/dictation_upload.dart';
import 'dictation_state.dart';
import 'dictation_queue_controller.dart';

class DictationController extends StateNotifier<DictationState> {
  DictationController(this._ref) : super(DictationState.initial());

  final Ref _ref;
  StreamSubscription<record.Amplitude>? _amplitudeSubscription;
  Timer? _durationTimer;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _accumulatedDuration = Duration.zero;
  final Random _tagRandom = Random.secure();

  DictationRecorder get _recorder => _ref.read(dictationRecorderProvider);
  DictationLocalStore get _store => _ref.read(dictationLocalStoreProvider);
  DictationQueueWorker get _queueWorker => _ref.read(dictationQueueWorkerProvider);

  Future<void> startRecording() async {
    if (!state.canRecord) {
      return;
    }
    await _resetCurrentRecording(deleteFile: true);
    final dictationId = const Uuid().v4();
    final sequenceNumber = await _store.nextSequenceNumber();
    final tag = _generateTag();
    final fileBaseName =
        '${sequenceNumber.toString().padLeft(6, '0')}_${tag}_$dictationId';
    final filePath = await _store.allocateFilePath(
      dictationId,
      fileName: fileBaseName,
    );
    final now = DateTime.now().toUtc();
    await _recorder.startRecording(filePath: filePath);
    _accumulatedDuration = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _startDurationTimer();
    _listenToAmplitude();
    state = state.copyWith(
      status: DictationSessionStatus.recording,
      dictationId: dictationId,
      filePath: filePath,
      duration: Duration.zero,
      fileSizeBytes: 0,
      isHeld: false,
      hasQueuedUpload: false,
      uploadStatus: null,
      clearCurrentUpload: true,
      clearErrorMessage: true,
      record: DictationRecord(
        id: dictationId,
        filePath: filePath,
        status: DictationSessionStatus.recording,
        duration: Duration.zero,
        fileSizeBytes: 0,
        createdAt: now,
        updatedAt: now,
        segments: [filePath],
        sequenceNumber: sequenceNumber,
        tag: tag,
      ),
    );
  }

  Future<void> pauseRecording() async {
    if (!state.canPause) return;
    await _recorder.pauseRecording();
    _stopwatch.stop();
    _accumulatedDuration += _stopwatch.elapsed;
    _stopwatch.reset();
    state = state.copyWith(
      status: DictationSessionStatus.paused,
      record: state.record?.copyWith(
        status: DictationSessionStatus.paused,
        duration: _accumulatedDuration,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> resumeRecording() async {
    if (!state.canResume) return;
    await _recorder.resumeRecording();
    _stopwatch
      ..reset()
      ..start();
    state = state.copyWith(
      status: DictationSessionStatus.recording,
      record: state.record?.copyWith(
        status: DictationSessionStatus.recording,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> stopRecording() async {
    if (state.status != DictationSessionStatus.recording &&
        state.status != DictationSessionStatus.paused) {
      return;
    }
    final path = await _recorder.stopRecording() ?? state.filePath;
    _stopwatch.stop();
    _accumulatedDuration += _stopwatch.elapsed;
    _stopwatch.reset();
    _durationTimer?.cancel();
    await _updateMetrics();
    final duration = _accumulatedDuration;
    final fileSize = await _safeFileSize(path);
    state = state.copyWith(
      status: DictationSessionStatus.ready,
      filePath: path,
      duration: duration,
      fileSizeBytes: fileSize,
      record: state.record?.copyWith(
        status: DictationSessionStatus.ready,
        duration: duration,
        fileSizeBytes: fileSize,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _cancelAmplitude();
  }

  Future<void> submitCurrent({Map<String, dynamic> metadata = const {}}) async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await stopRecording();
      final path = state.filePath;
      final dictationId = state.dictationId;
      if (path == null || dictationId == null) {
        throw StateError('No dictation to submit.');
      }
      final file = File(path);
      if (!await file.exists()) {
        throw const FileSystemException('Dictation file missing before upload.');
      }
      final fileSize = await file.length();
      final checksum = await _computeSha256(path);
      final upload = DictationUpload(
        id: dictationId,
        filePath: path,
        status: DictationUploadStatus.pending,
        createdAt: state.record?.createdAt ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        fileSizeBytes: fileSize,
        duration: state.duration,
        metadata: metadata,
        checksumSha256: checksum,
        sequenceNumber: state.record?.sequenceNumber ?? 0,
        tag: state.record?.tag ?? '',
      );
      await _queueWorker.upsert(upload);
      state = state.copyWith(
        isSubmitting: false,
        hasQueuedUpload: true,
        uploadStatus: upload.status,
        currentUpload: upload,
        record: state.record?.copyWith(
          status: DictationSessionStatus.ready,
          updatedAt: DateTime.now().toUtc(),
          checksumSha256: checksum,
        ),
      );
      _notifyQueueChanged();
      // Start processing queue in background (errors handled internally).
      unawaited(_queueWorker.processQueue().then((_) => _onQueueProcessed()));
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> holdCurrent() async {
    if (!state.canHold) return;
    await stopRecording();
    final path = state.filePath;
    final dictationId = state.dictationId;
    if (path == null || dictationId == null) return;
    final file = File(path);
    if (!await file.exists()) {
      state = state.copyWith(errorMessage: 'Cannot hold: dictation file missing.');
      return;
    }
    final size = await file.length();
    final checksum = await _computeSha256(path);
    final upload = DictationUpload(
      id: dictationId,
      filePath: path,
      status: DictationUploadStatus.held,
      createdAt: state.record?.createdAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      fileSizeBytes: size,
      duration: state.duration,
      metadata: state.currentUpload?.metadata ?? const {},
      checksumSha256: checksum,
      sequenceNumber: state.record?.sequenceNumber ?? 0,
      tag: state.record?.tag ?? '',
    );
    await _queueWorker.upsert(upload);
    _notifyQueueChanged();
    state = state.copyWith(
      isHeld: true,
      hasQueuedUpload: true,
      uploadStatus: DictationUploadStatus.held,
      currentUpload: upload,
      record: state.record?.copyWith(
        status: DictationSessionStatus.holding,
        updatedAt: DateTime.now().toUtc(),
        checksumSha256: checksum,
      ),
    );
  }

  Future<void> resumeHeld() async {
    final upload = state.currentUpload;
    if (upload == null || upload.status != DictationUploadStatus.held) return;
    await _queueWorker.markHeld(upload.id, held: false);
    _notifyQueueChanged();
    final updated = upload.copyWith(
      status: DictationUploadStatus.pending,
      updatedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      isHeld: false,
      uploadStatus: DictationUploadStatus.pending,
      currentUpload: updated,
      record: state.record?.copyWith(
        status: DictationSessionStatus.ready,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(_queueWorker.processQueue().then((_) => _onQueueProcessed()));
  }

  Future<void> deleteCurrent() async {
    await stopRecording();
    final dictationId = state.dictationId;
    final path = state.filePath;
    if (dictationId != null) {
      await _queueWorker.delete(dictationId, deleteFile: path != null);
      _notifyQueueChanged();
    }
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _cancelAmplitude();
    _durationTimer?.cancel();
    state = DictationState.initial();
  }

  Future<void> refreshQueueStatus() async {
    final dictationId = state.dictationId;
    if (dictationId == null) return;
    final uploads = await _queueWorker.loadQueue();
    for (final entry in uploads) {
      if (entry.id != dictationId) continue;
      state = state.copyWith(
        hasQueuedUpload: true,
        uploadStatus: entry.status,
        currentUpload: entry,
        isHeld: entry.status == DictationUploadStatus.held,
      );
      return;
    }
    state = state.copyWith(
      hasQueuedUpload: false,
      uploadStatus: null,
      isHeld: false,
      clearCurrentUpload: true,
    );
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_updateMetrics());
    });
  }

  Future<void> _updateMetrics() async {
    final path = state.filePath;
    if (path == null) return;
    final duration = _accumulatedDuration + (_stopwatch.isRunning ? _stopwatch.elapsed : Duration.zero);
    final size = await _safeFileSize(path);
    state = state.copyWith(
      duration: duration,
      fileSizeBytes: size,
      record: state.record?.copyWith(
        duration: duration,
        fileSizeBytes: size,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<int> _safeFileSize(String? path) async {
    if (path == null) return 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (error) {
      debugPrint('Failed reading file size for $path: $error');
    }
    return 0;
  }

  Future<String> _computeSha256(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found for checksum', path);
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _generateTag() {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 12; i++) {
      final index = _tagRandom.nextInt(charset.length);
      buffer.write(charset[index]);
    }
    return buffer.toString();
  }

  Future<void> _onQueueProcessed() async {
    await refreshQueueStatus();
    _notifyQueueChanged();
  }

  void _notifyQueueChanged() {
    final controller = _ref.read(dictationQueueProvider.notifier);
    unawaited(controller.refresh());
  }

  void _listenToAmplitude() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder.onAmplitude().listen(
      (event) {
        final normalized = event.max == 0 ? 0.0 : (event.current / event.max).clamp(0.0, 1.0);
        state = state.copyWith(amplitudeLevel: normalized);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Amplitude stream error: $error\n$stackTrace');
      },
    );
  }

  Future<void> _cancelAmplitude() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    state = state.copyWith(amplitudeLevel: 0);
  }

  Future<void> _resetCurrentRecording({bool deleteFile = false}) async {
    await _cancelAmplitude();
    _durationTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _accumulatedDuration = Duration.zero;
    if (deleteFile) {
      final path = state.filePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    state = state.copyWith(
      status: DictationSessionStatus.idle,
      dictationId: null,
      filePath: null,
      duration: Duration.zero,
      fileSizeBytes: 0,
      isHeld: false,
      hasQueuedUpload: false,
      uploadStatus: null,
      clearCurrentUpload: true,
      clearRecord: true,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

final dictationControllerProvider =
    StateNotifierProvider<DictationController, DictationState>((ref) => DictationController(ref));
