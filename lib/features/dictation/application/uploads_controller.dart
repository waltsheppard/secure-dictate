import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/dictation_upload.dart';
import '../infrastructure/dictation_local_store.dart';
import '../infrastructure/dictation_queue_worker.dart';

class UploadsState {
  const UploadsState({
    required this.unsent,
    required this.recent,
    required this.lastRefreshed,
  });

  final List<DictationUpload> unsent;
  final List<DictationUpload> recent;
  final DateTime lastRefreshed;
}

class UploadsController extends StateNotifier<AsyncValue<UploadsState>> {
  UploadsController(this._ref) : super(const AsyncLoading()) {
    refresh();
  }

  final Ref _ref;

  DictationQueueWorker get _queueWorker => _ref.read(dictationQueueWorkerProvider);
  DictationLocalStore get _store => _ref.read(dictationLocalStoreProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final unsent = await _queueWorker.loadQueue();
      final recent = await _store.loadHistory();
      state = AsyncData(
        UploadsState(
          unsent: unsent,
          recent: recent,
          lastRefreshed: DateTime.now().toUtc(),
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> retry(String dictationId) async {
    final queue = await _queueWorker.loadQueue();
    final target = queue.firstWhere(
      (upload) => upload.id == dictationId,
      orElse: () => throw StateError('Upload not found in queue: $dictationId'),
    );
    final now = DateTime.now().toUtc();
    final retryUpload = DictationUpload(
      id: target.id,
      filePath: target.filePath,
      status: DictationUploadStatus.pending,
      createdAt: target.createdAt,
      updatedAt: now,
      uploadedAt: target.uploadedAt,
      retryCount: target.retryCount + 1,
      errorMessage: null,
      fileSizeBytes: target.fileSizeBytes,
      duration: target.duration,
      metadata: target.metadata,
      checksumSha256: target.checksumSha256,
      sequenceNumber: target.sequenceNumber,
      tag: target.tag,
    );
    await _queueWorker.upsert(retryUpload);
    await _queueWorker.processQueue();
    await refresh();
  }

  Future<void> delete(String dictationId) async {
    await _queueWorker.delete(dictationId, deleteFile: false);
    await refresh();
  }
}

final uploadsControllerProvider = StateNotifierProvider<UploadsController, AsyncValue<UploadsState>>(
  (ref) => UploadsController(ref),
);
