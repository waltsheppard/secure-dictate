import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/dictation_upload.dart';

class DictationLocalStore {
  DictationLocalStore();

  Directory? _dictationDir;
  File? _queueFile;
  File? _sequenceFile;
  Future<void> _initialization = Future.value();

  Future<void> ensureInitialized() async {
    await _initialization;
    _initialization = _initialize();
    await _initialization;
  }

  Future<void> _initialize() async {
    if (_queueFile != null) return;
    final supportDir = await getApplicationSupportDirectory();
    final dictationDir = Directory(p.join(supportDir.path, 'dictations'));
    if (!await dictationDir.exists()) {
      await dictationDir.create(recursive: true);
    }
    final queueFile = File(p.join(dictationDir.path, 'queue.json'));
    if (!await queueFile.exists()) {
      await queueFile.writeAsString(jsonEncode({'queue': <Map<String, dynamic>>[]}));
    }
    final sequenceFile = File(p.join(dictationDir.path, 'sequence.txt'));
    if (!await sequenceFile.exists()) {
      await sequenceFile.writeAsString('1', flush: true);
    }
    _dictationDir = dictationDir;
    _queueFile = queueFile;
    _sequenceFile = sequenceFile;
  }

  Future<File> _ensureQueueFile() async {
    await ensureInitialized();
    return _queueFile!;
  }

  Future<Directory> dictationDirectory() async {
    await ensureInitialized();
    return _dictationDir!;
  }

  Future<String> allocateFilePath(
    String dictationId, {
    String extension = '.wav',
    String? fileName,
  }) async {
    final dir = await dictationDirectory();
    final baseName = fileName ?? dictationId;
    final normalizedExtension = extension.startsWith('.') ? extension : '.$extension';
    return p.join(dir.path, '$baseName$normalizedExtension');
  }

  Future<List<DictationUpload>> loadQueue() async {
    final file = await _ensureQueueFile();
    if (!await file.exists()) {
      return const [];
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return const [];
    }
    try {
      final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
      final List<dynamic> items = json['queue'] as List<dynamic>? ?? const [];
      return items
          .map((dynamic e) => DictationUpload.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to decode queue file: $error\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveQueue(List<DictationUpload> uploads) async {
    final file = await _ensureQueueFile();
    final payload = jsonEncode({
      'queue': uploads.map((e) => e.toJson()).toList(growable: false),
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<void> upsertUpload(DictationUpload upload) async {
    final uploads = await loadQueue();
    final updated = <DictationUpload>[];
    var found = false;
    for (final entry in uploads) {
      if (entry.id == upload.id) {
        updated.add(upload);
        found = true;
      } else {
        updated.add(entry);
      }
    }
    if (!found) {
      updated.add(upload);
    }
    await saveQueue(updated);
  }

  Future<void> removeUpload(String dictationId, {bool deleteFile = false}) async {
    final uploads = await loadQueue();
    DictationUpload? removed;
    final filtered = <DictationUpload>[];
    for (final entry in uploads) {
      if (entry.id == dictationId) {
        removed = entry;
        continue;
      }
      filtered.add(entry);
    }
    await saveQueue(filtered);
    if (deleteFile) {
      final path = removed?.filePath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  Future<void> clearAll() async {
    final dir = await dictationDirectory();
    if (await dir.exists()) {
      await for (final file in dir.list(recursive: false)) {
        if (file is File) {
          await file.delete();
        }
      }
    }
    await saveQueue(const []);
    final sequenceFile = await _ensureSequenceFile();
    await sequenceFile.writeAsString('1', flush: true);
  }

  Future<File> _ensureSequenceFile() async {
    await ensureInitialized();
    return _sequenceFile!;
  }

  Future<int> nextSequenceNumber() async {
    final file = await _ensureSequenceFile();
    final contents = await file.readAsString();
    final current = int.tryParse(contents.trim()) ?? 1;
    final next = current + 1;
    await file.writeAsString('$next', flush: true);
    return current;
  }

}

final dictationLocalStoreProvider = Provider<DictationLocalStore>((ref) {
  final store = DictationLocalStore();
  ref.onDispose(() {
    // no-op for now
  });
  return store;
});
