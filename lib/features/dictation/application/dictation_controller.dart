import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../domain/dictation_record.dart';
import '../infrastructure/audio_recorder.dart';
import '../infrastructure/dictation_local_store.dart';
import '../infrastructure/dictation_queue_worker.dart';
import '../domain/dictation_upload.dart';
import 'dictation_state.dart';
import 'dictation_queue_controller.dart';
import 'held_dictations_controller.dart';
import '../domain/held_dictation.dart';

class DictationController extends StateNotifier<DictationState> {
  DictationController(this._ref) : super(DictationState.initial());

  final Ref _ref;
  Timer? _durationTimer;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _accumulatedDuration = Duration.zero;
  final Random _tagRandom = Random.secure();
  String? _finalFilePath;
  String? _activeSegmentPath;
  final List<String> _segmentPaths = [];

  DictationRecorder get _recorder => _ref.read(dictationRecorderProvider);
  DictationLocalStore get _store => _ref.read(dictationLocalStoreProvider);
  DictationQueueWorker get _queueWorker =>
      _ref.read(dictationQueueWorkerProvider);

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
    final finalFilePath = await _store.allocateFilePath(
      dictationId,
      fileName: fileBaseName,
    );
    await _deleteFileIfExists(finalFilePath);
    _finalFilePath = finalFilePath;
    _segmentPaths
      ..clear()
      ..add(_segmentPathForIndex(finalFilePath, 1));
    _activeSegmentPath = _segmentPaths.last;
    final now = DateTime.now().toUtc();
    await _recorder.startRecording(filePath: _activeSegmentPath!);
    _accumulatedDuration = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _startDurationTimer();
    state = state.copyWith(
      status: DictationSessionStatus.recording,
      dictationId: dictationId,
      filePath: finalFilePath,
      duration: Duration.zero,
      fileSizeBytes: 0,
      isHeld: false,
      hasQueuedUpload: false,
      uploadStatus: null,
      clearCurrentUpload: true,
      clearErrorMessage: true,
      record: DictationRecord(
        id: dictationId,
        filePath: finalFilePath,
        status: DictationSessionStatus.recording,
        duration: Duration.zero,
        fileSizeBytes: 0,
        createdAt: now,
        updatedAt: now,
        segments: List<String>.from(_segmentPaths),
        sequenceNumber: sequenceNumber,
        tag: tag,
      ),
    );
  }

  Future<void> pauseRecording() async {
    if (!state.canPause || state.status != DictationSessionStatus.recording) {
      return;
    }
    await _stopActiveSegment();
    await _mergeSegments();
    await _updateMetrics();
    state = state.copyWith(
      status: DictationSessionStatus.paused,
      record: state.record?.copyWith(
        status: DictationSessionStatus.paused,
        duration: _accumulatedDuration,
        fileSizeBytes: state.fileSizeBytes,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
  }

  Future<void> resumeRecording() async {
    if (!state.canResume) return;
    try {
      await _beginNewSegment();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      rethrow;
    }
    _stopwatch
      ..reset()
      ..start();
    _startDurationTimer();
    state = state.copyWith(
      status: DictationSessionStatus.recording,
      record: state.record?.copyWith(
        status: DictationSessionStatus.recording,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
  }

  Future<void> stopRecording() async {
    if (state.status != DictationSessionStatus.recording &&
        state.status != DictationSessionStatus.paused &&
        state.status != DictationSessionStatus.holding) {
      return;
    }
    if (state.status == DictationSessionStatus.recording) {
      await _stopActiveSegment();
    }
    await _mergeSegments();
    await _updateMetrics();
    final finalPath = _finalFilePath ?? state.filePath;
    final duration = _accumulatedDuration;
    final fileSize = await _safeFileSize(finalPath);
    state = state.copyWith(
      status: DictationSessionStatus.ready,
      filePath: finalPath,
      duration: duration,
      fileSizeBytes: fileSize,
      isHeld: false,
      record: state.record?.copyWith(
        status: DictationSessionStatus.ready,
        duration: duration,
        fileSizeBytes: fileSize,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
    _notifyPlaybackUpdate();
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
        throw const FileSystemException(
          'Dictation file missing before upload.',
        );
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
        isHeld: false,
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
    await _resetCurrentRecording(deleteFile: false);
  }

  Future<void> holdCurrent() async {
    if (!state.canHold) return;
    if (state.status != DictationSessionStatus.recording &&
        state.status != DictationSessionStatus.paused) {
      return;
    }
    if (state.status == DictationSessionStatus.recording) {
      await _stopActiveSegment();
    }
    await _mergeSegments();
    await _updateMetrics();
    state = state.copyWith(
      status: DictationSessionStatus.holding,
      isHeld: true,
      hasQueuedUpload: false,
      uploadStatus: null,
      clearCurrentUpload: true,
      record: state.record?.copyWith(
        status: DictationSessionStatus.holding,
        duration: _accumulatedDuration,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
    final dictationId = state.dictationId;
    final path = state.filePath;
    if (dictationId != null && path != null) {
      final fileSize = await _safeFileSize(path);
      final held = HeldDictation(
        id: dictationId,
        filePath: path,
        duration: _accumulatedDuration,
        fileSizeBytes: fileSize,
        createdAt: state.record?.createdAt ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        sequenceNumber: state.record?.sequenceNumber ?? 0,
        tag: state.record?.tag ?? '',
        segments: List<String>.from(_segmentPaths),
      );
      await _store.upsertHeld(held);
      _ref.read(heldDictationsProvider.notifier).refresh();
    }
    _notifyPlaybackUpdate();
    await _resetCurrentRecording(deleteFile: false);
  }

  Future<void> resumeHeld() async {
    if (!state.isHeld || state.status != DictationSessionStatus.holding) {
      return;
    }
    final dictationId = state.dictationId;
    if (dictationId != null) {
      await _store.removeHeld(dictationId);
      _ref.read(heldDictationsProvider.notifier).refresh();
    }
    try {
      await _beginNewSegment();
    } catch (error) {
      final path = state.filePath;
      if (dictationId != null && path != null) {
        final fileSize = await _safeFileSize(path);
        final held = HeldDictation(
          id: dictationId,
          filePath: path,
          duration: _accumulatedDuration,
          fileSizeBytes: fileSize,
          createdAt: state.record?.createdAt ?? DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          sequenceNumber: state.record?.sequenceNumber ?? 0,
          tag: state.record?.tag ?? '',
          segments: List<String>.from(_segmentPaths),
        );
        await _store.upsertHeld(held);
        _ref.read(heldDictationsProvider.notifier).refresh();
      }
      state = state.copyWith(errorMessage: error.toString());
      return;
    }
    _stopwatch
      ..reset()
      ..start();
    _startDurationTimer();
    state = state.copyWith(
      status: DictationSessionStatus.recording,
      isHeld: false,
      filePath: _finalFilePath ?? state.filePath,
      record: state.record?.copyWith(
        status: DictationSessionStatus.recording,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
  }

  Future<void> resumeHeldFromStore(String dictationId) async {
    final heldController = _ref.read(heldDictationsProvider.notifier);
    final held = await _store.removeHeld(dictationId);
    unawaited(heldController.refresh());
    if (held == null) {
      state = state.copyWith(errorMessage: 'Held dictation not found.');
      return;
    }
    final segmentList =
        held.segments.isNotEmpty ? held.segments : [held.filePath];
    for (final segmentPath in segmentList) {
      if (!await File(segmentPath).exists()) {
        state = state.copyWith(
          errorMessage: 'Held segment missing: $segmentPath',
        );
        return;
      }
    }
    _segmentPaths
      ..clear()
      ..addAll(segmentList);
    _finalFilePath = held.filePath;
    _activeSegmentPath = null;
    _accumulatedDuration = held.duration;
    _durationTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    await _mergeSegments();
    state = state.copyWith(
      status: DictationSessionStatus.holding,
      dictationId: held.id,
      filePath: held.filePath,
      duration: held.duration,
      fileSizeBytes: held.fileSizeBytes,
      isHeld: true,
      hasQueuedUpload: false,
      uploadStatus: DictationUploadStatus.held,
      record: DictationRecord(
        id: held.id,
        filePath: held.filePath,
        status: DictationSessionStatus.holding,
        duration: held.duration,
        fileSizeBytes: held.fileSizeBytes,
        createdAt: held.createdAt,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
        sequenceNumber: held.sequenceNumber,
        tag: held.tag,
      ),
      clearCurrentUpload: true,
      clearErrorMessage: true,
    );
    _notifyPlaybackUpdate();
  }

  Future<void> deleteCurrent() async {
    await stopRecording();
    final dictationId = state.dictationId;
    final path = state.filePath;
    if (dictationId != null) {
      await _queueWorker.delete(dictationId, deleteFile: path != null);
      _notifyQueueChanged();
      await _store.removeHeld(dictationId);
      _ref.read(heldDictationsProvider.notifier).refresh();
    }
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    for (final segment in List<String>.from(_segmentPaths)) {
      await _deleteFileIfExists(segment);
    }
    _segmentPaths.clear();
    _finalFilePath = null;
    _activeSegmentPath = null;
    _durationTimer?.cancel();
    state = DictationState.initial();
  }

  void _notifyPlaybackUpdate() {
    // Trigger listeners that rely on updated duration/size to refresh playback.
    state = state.copyWith(duration: state.duration);
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
    final path = _finalFilePath ?? state.filePath;
    if (path == null) return;
    final duration =
        _accumulatedDuration +
        (_stopwatch.isRunning ? _stopwatch.elapsed : Duration.zero);
    var size = await _safeFileSize(path);
    if (size == 0) {
      size = await _totalSegmentSize();
    }
    state = state.copyWith(
      duration: duration,
      fileSizeBytes: size,
      record: state.record?.copyWith(
        duration: duration,
        fileSizeBytes: size,
        updatedAt: DateTime.now().toUtc(),
        segments: List<String>.from(_segmentPaths),
      ),
    );
  }

  Future<int> _totalSegmentSize() async {
    var total = 0;
    for (final segment in _segmentPaths) {
      total += await _safeFileSize(segment);
    }
    return total;
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

  Future<void> _beginNewSegment() async {
    final finalPath = _finalFilePath ?? state.filePath;
    if (finalPath == null) {
      throw StateError('No base file path available for dictation segments.');
    }
    final nextIndex = _segmentPaths.length + 1;
    final segmentPath = _segmentPathForIndex(finalPath, nextIndex);
    await _deleteFileIfExists(segmentPath);
    _segmentPaths.add(segmentPath);
    try {
      await _recorder.startRecording(filePath: segmentPath);
      _activeSegmentPath = segmentPath;
    } catch (error) {
      _segmentPaths.remove(segmentPath);
      rethrow;
    }
  }

  Future<void> _stopActiveSegment() async {
    if (_activeSegmentPath == null) {
      return;
    }
    try {
      await _recorder.stopRecording();
    } finally {
      _durationTimer?.cancel();
      _stopwatch.stop();
      _accumulatedDuration += _stopwatch.elapsed;
      _stopwatch.reset();
      _activeSegmentPath = null;
    }
  }

  Future<void> _mergeSegments() async {
    final outputPath = _finalFilePath ?? state.filePath;
    if (outputPath == null || _segmentPaths.isEmpty) {
      return;
    }
    _WavSegment? baseSegment;
    final dataBuffers = <Uint8List>[];
    var totalDataLength = 0;
    for (final segmentPath in _segmentPaths) {
      final file = File(segmentPath);
      if (!await file.exists()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      _WavSegment segment;
      try {
        segment = _parseWavSegment(bytes);
      } on FormatException catch (error) {
        debugPrint('Skipping invalid WAV segment $segmentPath: $error');
        continue;
      }
      baseSegment ??= segment;
      totalDataLength += segment.data.length;
      dataBuffers.add(segment.data);
    }
    if (baseSegment == null || totalDataLength == 0) {
      await _deleteFileIfExists(outputPath);
      return;
    }
    final header = Uint8List.fromList(baseSegment.header);
    final headerView = ByteData.view(header.buffer);
    headerView.setUint32(4, header.length - 8 + totalDataLength, Endian.little);
    headerView.setUint32(
      baseSegment.dataSizeFieldOffset,
      totalDataLength,
      Endian.little,
    );
    final builder = BytesBuilder(copy: false);
    builder.add(header);
    for (final buffer in dataBuffers) {
      builder.add(buffer);
    }
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(builder.takeBytes(), flush: true);
  }

  String _segmentPathForIndex(String finalPath, int index) {
    final directory = p.dirname(finalPath);
    final baseName = p.basenameWithoutExtension(finalPath);
    final extension = p.extension(finalPath);
    final suffix = index.toString().padLeft(2, '0');
    return p.join(directory, '${baseName}_seg$suffix$extension');
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  _WavSegment _parseWavSegment(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const FormatException('Header too short');
    }
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;
      if (chunkDataStart + chunkSize > bytes.length) {
        throw const FormatException('Chunk extends beyond file');
      }
      if (chunkId == 'data') {
        final header = Uint8List.fromList(bytes.sublist(0, chunkDataStart));
        final chunkData = Uint8List.fromList(
          bytes.sublist(chunkDataStart, chunkDataStart + chunkSize),
        );
        final dataSizeFieldOffset = chunkDataStart - 4;
        return _WavSegment(
          header: header,
          data: chunkData,
          dataSizeFieldOffset: dataSizeFieldOffset,
        );
      }
      offset = chunkDataStart + chunkSize;
      if (chunkSize.isOdd) {
        offset += 1;
      }
    }
    throw const FormatException('Missing data chunk');
  }

  Future<void> _onQueueProcessed() async {
    await refreshQueueStatus();
    _notifyQueueChanged();
  }

  void _notifyQueueChanged() {
    final controller = _ref.read(dictationQueueProvider.notifier);
    unawaited(controller.refresh());
  }

  Future<void> _resetCurrentRecording({bool deleteFile = false}) async {
    _durationTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    _accumulatedDuration = Duration.zero;
    if (deleteFile) {
      final finalPath = _finalFilePath ?? state.filePath;
      if (finalPath != null) {
        await _deleteFileIfExists(finalPath);
      }
      for (final segment in List<String>.from(_segmentPaths)) {
        await _deleteFileIfExists(segment);
      }
    }
    _segmentPaths.clear();
    _finalFilePath = null;
    _activeSegmentPath = null;
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
    _stopwatch.stop();
    super.dispose();
  }
}

class _WavSegment {
  const _WavSegment({
    required this.header,
    required this.data,
    required this.dataSizeFieldOffset,
  });

  final Uint8List header;
  final Uint8List data;
  final int dataSizeFieldOffset;
}

final dictationControllerProvider =
    StateNotifierProvider<DictationController, DictationState>(
      (ref) => DictationController(ref),
    );
