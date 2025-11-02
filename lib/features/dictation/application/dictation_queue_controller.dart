import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/dictation_upload.dart';
import '../infrastructure/dictation_queue_worker.dart';

class DictationQueueController extends StateNotifier<AsyncValue<List<DictationUpload>>> {
  DictationQueueController(this._ref) : super(const AsyncLoading()) {
    refresh();
  }

  final Ref _ref;

  DictationQueueWorker get _worker => _ref.read(dictationQueueWorkerProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final uploads = await _worker.loadQueue();
      state = AsyncData(uploads);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> delete(String dictationId, {bool deleteFile = false}) async {
    await _worker.delete(dictationId, deleteFile: deleteFile);
    await refresh();
  }

  Future<void> markHeld(String dictationId, {required bool held}) async {
    await _worker.markHeld(dictationId, held: held);
    await refresh();
  }

  Future<void> retry(String dictationId) async {
    await _worker.markHeld(dictationId, held: false);
    await _worker.processQueue();
    await refresh();
  }
}

final dictationQueueProvider = StateNotifierProvider<DictationQueueController, AsyncValue<List<DictationUpload>>>(
  (ref) => DictationQueueController(ref),
);
