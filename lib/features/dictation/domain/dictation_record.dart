import 'dart:convert';

/// Represents the current dictation session on device.
class DictationRecord {
  const DictationRecord({
    required this.id,
    required this.filePath,
    required this.status,
    required this.duration,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.updatedAt,
    required this.sequenceNumber,
    required this.tag,
    this.segments = const [],
    this.checksumSha256,
  });

  final String id;
  final String filePath;
  final DictationSessionStatus status;
  final Duration duration;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> segments;
  final String? checksumSha256;
  final int sequenceNumber;
  final String tag;

  DictationRecord copyWith({
    String? id,
    String? filePath,
    DictationSessionStatus? status,
    Duration? duration,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? segments,
    String? checksumSha256,
    int? sequenceNumber,
    String? tag,
  }) {
    return DictationRecord(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      segments: segments ?? List<String>.from(this.segments),
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      tag: tag ?? this.tag,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'status': status.name,
      'durationMicros': duration.inMicroseconds,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'segments': segments,
      'checksumSha256': checksumSha256,
      'sequenceNumber': sequenceNumber,
      'tag': tag,
    };
  }

  factory DictationRecord.fromJson(Map<String, dynamic> json) {
    return DictationRecord(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      status: DictationSessionStatus.values.byName(json['status'] as String),
      duration: Duration(microseconds: json['durationMicros'] as int? ?? 0),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((dynamic e) => e as String)
          .toList(growable: false),
      checksumSha256: json['checksumSha256'] as String?,
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      tag: json['tag'] as String? ?? '',
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

enum DictationSessionStatus {
  idle,
  recording,
  paused,
  ready,
  holding,
}
