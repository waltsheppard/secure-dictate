import 'dart:convert';

enum DictationUploadStatus {
  pending,
  held,
  uploading,
  failed,
  completed,
}

class DictationUpload {
  const DictationUpload({
    required this.id,
    required this.filePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.fileSizeBytes,
    required this.duration,
    required this.sequenceNumber,
    required this.tag,
    this.retryCount = 0,
    this.errorMessage,
    this.uploadedAt,
    this.metadata = const {},
    this.checksumSha256,
  });

  final String id;
  final String filePath;
  final DictationUploadStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? uploadedAt;
  final int retryCount;
  final String? errorMessage;
  final int fileSizeBytes;
  final Duration duration;
  final Map<String, dynamic> metadata;
  final String? checksumSha256;
  final int sequenceNumber;
  final String tag;

  DictationUpload copyWith({
    DictationUploadStatus? status,
    DateTime? updatedAt,
    DateTime? uploadedAt,
    int? retryCount,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    int? fileSizeBytes,
    Duration? duration,
    String? checksumSha256,
    int? sequenceNumber,
    String? tag,
  }) {
    return DictationUpload(
      id: id,
      filePath: filePath,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      duration: duration ?? this.duration,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'uploadedAt': uploadedAt?.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'fileSizeBytes': fileSizeBytes,
      'durationMicros': duration.inMicroseconds,
      'metadata': metadata,
      'checksumSha256': checksumSha256,
      'sequenceNumber': sequenceNumber,
      'tag': tag,
    };
  }

  factory DictationUpload.fromJson(Map<String, dynamic> json) {
    return DictationUpload(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      status: DictationUploadStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      uploadedAt: (json['uploadedAt'] as String?)?.let(DateTime.parse),
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

  @override
  String toString() => jsonEncode(toJson());
}

extension _NullableString on String? {
  T? let<T>(T Function(String value) transform) {
    final value = this;
    if (value == null) return null;
    return transform(value);
  }
}
