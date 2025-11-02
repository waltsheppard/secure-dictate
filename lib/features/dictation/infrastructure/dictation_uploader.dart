import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dictation_upload.dart';

abstract class DictationUploader {
  Future<void> upload(DictationUpload upload, {Map<String, String>? metadata});
}

class AmplifyDictationUploader implements DictationUploader {
  @override
  Future<void> upload(DictationUpload upload, {Map<String, String>? metadata}) async {
    if (Amplify.Storage.plugins.isEmpty) {
      throw const StorageNotConfiguredException('Amplify Storage plugin has not been added.');
    }
    final file = File(upload.filePath);
    if (!await file.exists()) {
      throw StorageFileNotFoundException('File not found: ${upload.filePath}');
    }
    final storageKey = 'dictations/${upload.id}${_extensionFor(upload.filePath)}';
    final awsFile = AWSFile.fromPath(upload.filePath);
    await Amplify.Storage.uploadFile(
      localFile: awsFile,
      path: StoragePath.fromString(storageKey),
      options: StorageUploadFileOptions(metadata: metadata),
    );
    // Placeholder for metadata persistence. Later this should call an API or AppSync mutation.
    if (Amplify.API.plugins.isEmpty) {
      // Skip metadata upload until API configured.
      return;
    }
    final payload = <String, dynamic>{
      'dictationId': upload.id,
      'objectKey': storageKey,
      'fileSizeBytes': upload.fileSizeBytes,
      'durationSeconds': upload.duration.inSeconds,
      'checksumSha256': upload.checksumSha256,
      'metadata': upload.metadata,
      'recordedAt': upload.createdAt.toIso8601String(),
    };
    await Amplify.API.post(
      '/dictations',
      body: HttpPayload.json(payload),
    ).response;
  }

  String _extensionFor(String path) {
    final index = path.lastIndexOf('.');
    if (index == -1 || index == path.length - 1) {
      return '.wav';
    }
    return path.substring(index);
  }
}

class StorageNotConfiguredException implements Exception {
  const StorageNotConfiguredException(this.message);

  final String message;

  @override
  String toString() => 'StorageNotConfiguredException: $message';
}

class StorageFileNotFoundException implements Exception {
  const StorageFileNotFoundException(this.message);

  final String message;

  @override
  String toString() => 'StorageFileNotFoundException: $message';
}

final dictationUploaderProvider = Provider<DictationUploader>((ref) {
  return AmplifyDictationUploader();
});
