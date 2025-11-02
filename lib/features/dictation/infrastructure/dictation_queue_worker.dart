import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dictation_upload.dart';
import 'dictation_local_store.dart';
import 'dictation_uploader.dart';

class DictationQueueWorker {
  DictationQueueWorker(this._ref);

  final Ref _ref;

  DictationLocalStore get _store => _ref.read(dictationLocalStoreProvider);
  DictationUploader get _uploader => _ref.read(dictationUploaderProvider);

  Future<List<DictationUpload>> loadQueue() => _store.loadQueue();

  Future<void> upsert(DictationUpload upload) => _store.upsertUpload(upload);

  Future<void> delete(String dictationId, {bool deleteFile = false}) =>
      _store.removeUpload(dictationId, deleteFile: deleteFile);

  Future<void> processQueue() async {
    final uploads = await loadQueue();
    for (final entry in uploads) {
      if (entry.status != DictationUploadStatus.pending &&
          entry.status != DictationUploadStatus.failed) {
        continue;
      }
      final pending = entry.copyWith(
        status: DictationUploadStatus.uploading,
        updatedAt: DateTime.now().toUtc(),
        retryCount: entry.status == DictationUploadStatus.failed ? entry.retryCount + 1 : entry.retryCount,
      );
      await upsert(pending);
      try {
        await _uploader.upload(pending, metadata: _stringifyMetadata(pending.metadata));
        await _store.removeUpload(pending.id, deleteFile: true);
      } on Exception catch (error, stackTrace) {
        debugPrint('Failed uploading dictation ${pending.id}: $error\n$stackTrace');
        final failed = pending.copyWith(
          status: DictationUploadStatus.failed,
          updatedAt: DateTime.now().toUtc(),
          errorMessage: error.toString(),
        );
        await upsert(failed);
      }
    }
  }

  Future<void> markHeld(String dictationId, {required bool held}) async {
    final uploads = await loadQueue();
    for (final entry in uploads) {
      if (entry.id != dictationId) continue;
      final nextStatus = held ? DictationUploadStatus.held : DictationUploadStatus.pending;
      final updated = entry.copyWith(
        status: nextStatus,
        updatedAt: DateTime.now().toUtc(),
      );
      await upsert(updated);
      return;
    }
  }

  Map<String, String>? _stringifyMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) return null;
    return metadata.map((key, value) => MapEntry(key, value.toString()));
  }
}

final dictationQueueWorkerProvider = Provider<DictationQueueWorker>((ref) {
  return DictationQueueWorker(ref);
});
