import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/dictation_upload.dart';
import '../domain/held_dictation.dart';

class DictationLocalStore {
  DictationLocalStore();

  Directory? _dictationDir;
  File? _queueFile;
  File? _sequenceFile;
  File? _heldFile;
  File? _historyFile;
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
      await queueFile.writeAsString(jsonEncode({'queue': <Map<String, dynamic>>[]}), flush: true);
    }
    final sequenceFile = File(p.join(dictationDir.path, 'sequence.txt'));
    if (!await sequenceFile.exists()) {
      await sequenceFile.writeAsString('1', flush: true);
    }
    final heldFile = File(p.join(dictationDir.path, 'held.json'));
    if (!await heldFile.exists()) {
      await heldFile.writeAsString(jsonEncode({'held': <Map<String, dynamic>>[]}), flush: true);
    }
    final historyFile = File(p.join(dictationDir.path, 'history.json'));
    if (!await historyFile.exists()) {
      await historyFile.writeAsString(jsonEncode({'history': <Map<String, dynamic>>[]}), flush: true);
    }
    _dictationDir = dictationDir;
    _queueFile = queueFile;
    _sequenceFile = sequenceFile;
    _heldFile = heldFile;
    _historyFile = historyFile;
  }

  Future<File> _ensureQueueFile() async {
    await ensureInitialized();
    return _queueFile!;
  }

  Future<File> _ensureSequenceFile() async {
    await ensureInitialized();
    return _sequenceFile!;
  }

  Future<File> _ensureHeldFile() async {
    await ensureInitialized();
    return _heldFile!;
  }

  Future<File> _ensureHistoryFile() async {
    await ensureInitialized();
    return _historyFile!;
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
    await saveHeld(const []);
    final sequenceFile = await _ensureSequenceFile();
    await sequenceFile.writeAsString('1', flush: true);
  }

  Future<int> nextSequenceNumber() async {
    final file = await _ensureSequenceFile();
    final contents = await file.readAsString();
    final current = int.tryParse(contents.trim()) ?? 1;
    final next = current + 1;
    await file.writeAsString('$next', flush: true);
    return current;
  }

  Future<List<HeldDictation>> loadHeld() async {
    final file = await _ensureHeldFile();
    if (!await file.exists()) {
      return const [];
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return const [];
    }
    final baseDir = (await dictationDirectory()).path;
    try {
      final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
      final List<dynamic> items = json['held'] as List<dynamic>? ?? const [];
      return items
          .map((dynamic e) => _heldFromJson((e as Map).cast<String, dynamic>(), baseDir))
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to decode held file: $error\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveHeld(List<HeldDictation> sessions) async {
    final file = await _ensureHeldFile();
    final baseDir = (await dictationDirectory()).path;
    final payload = jsonEncode({
      'held': sessions.map((e) => _heldToJson(e, baseDir)).toList(growable: false),
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<List<DictationUpload>> loadHistory() async {
    final file = await _ensureHistoryFile();
    if (!await file.exists()) {
      return const [];
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return const [];
    }
    final baseDir = (await dictationDirectory()).path;
    try {
      final Map<String, dynamic> json = jsonDecode(content) as Map<String, dynamic>;
      final List<dynamic> items = json['history'] as List<dynamic>? ?? const [];
      return items
          .map((dynamic e) => _uploadFromJson((e as Map).cast<String, dynamic>(), baseDir))
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to decode history file: $error\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveHistory(List<DictationUpload> uploads) async {
    final file = await _ensureHistoryFile();
    final baseDir = (await dictationDirectory()).path;
    final payload = jsonEncode({
      'history': uploads.map((e) => _uploadToJson(e, baseDir)).toList(growable: false),
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<void> appendHistory(DictationUpload upload, {int limit = 20}) async {
    final history = await loadHistory();
    final updated = <DictationUpload>[upload, ...history];
    if (updated.length > limit) {
      updated.removeRange(limit, updated.length);
    }
    await saveHistory(updated);
  }

  Future<void> upsertHeld(HeldDictation session) async {
    final held = await loadHeld();
    final updated = <HeldDictation>[];
    var found = false;
    for (final entry in held) {
      if (entry.id == session.id) {
        updated.add(session);
        found = true;
      } else {
        updated.add(entry);
      }
    }
    if (!found) {
      updated.add(session);
    }
    await saveHeld(updated);
  }

  Future<HeldDictation?> removeHeld(String dictationId) async {
    final held = await loadHeld();
    HeldDictation? removed;
    final remaining = <HeldDictation>[];
    for (final entry in held) {
      if (entry.id == dictationId) {
        removed = entry;
        continue;
      }
      remaining.add(entry);
    }
    await saveHeld(remaining);
    return removed;
  }

  Map<String, dynamic> _heldToJson(HeldDictation session, String baseDir) {
    return {
      'id': session.id,
      'filePath': _relativePath(session.filePath, baseDir),
      'durationMicros': session.duration.inMicroseconds,
      'fileSizeBytes': session.fileSizeBytes,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
      'sequenceNumber': session.sequenceNumber,
      'tag': session.tag,
      'segments': session.segments
          .map((path) => _relativePath(path, baseDir))
          .toList(growable: false),
    };
  }

  HeldDictation _heldFromJson(Map<String, dynamic> json, String baseDir) {
    final filePath = _absolutePath(json['filePath'] as String, baseDir);
    final rawSegments = (json['segments'] as List<dynamic>? ?? const [])
        .map((dynamic e) => _absolutePath(e as String, baseDir))
        .toList(growable: false);
    final segments = rawSegments.isNotEmpty ? rawSegments : <String>[filePath];
    return HeldDictation(
      id: json['id'] as String,
      filePath: filePath,
      duration: Duration(microseconds: json['durationMicros'] as int? ?? 0),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      tag: json['tag'] as String? ?? '',
      segments: segments,
    );
  }

  Map<String, dynamic> _uploadToJson(DictationUpload upload, String baseDir) {
    return {
      'id': upload.id,
      'filePath': _relativePath(upload.filePath, baseDir),
      'status': upload.status.name,
      'createdAt': upload.createdAt.toIso8601String(),
      'updatedAt': upload.updatedAt.toIso8601String(),
      'uploadedAt': upload.uploadedAt?.toIso8601String(),
      'retryCount': upload.retryCount,
      'errorMessage': upload.errorMessage,
      'fileSizeBytes': upload.fileSizeBytes,
      'durationMicros': upload.duration.inMicroseconds,
      'metadata': upload.metadata,
      'checksumSha256': upload.checksumSha256,
      'sequenceNumber': upload.sequenceNumber,
      'tag': upload.tag,
    };
  }

  DictationUpload _uploadFromJson(Map<String, dynamic> json, String baseDir) {
    final uploadedAtValue = json['uploadedAt'] as String?;
    return DictationUpload(
      id: json['id'] as String,
      filePath: _absolutePath(json['filePath'] as String, baseDir),
      status: DictationUploadStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      uploadedAt: uploadedAtValue != null ? DateTime.parse(uploadedAtValue) : null,
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      duration: Duration(microseconds: json['durationMicros'] as int? ?? 0),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      checksumSha256: json['checksumSha256'] as String?,
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      tag: json['tag'] as String? ?? '',
    );
  }

  String _relativePath(String path, String baseDir) {
    if (path.isEmpty) {
      return path;
    }
    if (!p.isWithin(baseDir, path)) {
      return path;
    }
    return p.relative(path, from: baseDir);
  }

  String _absolutePath(String path, String baseDir) {
    if (path.isEmpty) {
      return path;
    }
    if (p.isAbsolute(path)) {
      return path;
    }
    return p.normalize(p.join(baseDir, path));
  }
}

final dictationLocalStoreProvider = Provider<DictationLocalStore>((ref) {
  final store = DictationLocalStore();
  ref.onDispose(() {
    // no-op for now
  });
  return store;
});
