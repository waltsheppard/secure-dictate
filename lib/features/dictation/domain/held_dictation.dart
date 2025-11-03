import 'dart:convert';

class HeldDictation {
  const HeldDictation({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.fileSizeBytes,
    required this.createdAt,
    required this.updatedAt,
    required this.sequenceNumber,
    required this.tag,
    required this.segments,
  });

  final String id;
  final String filePath;
  final Duration duration;
  final int fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sequenceNumber;
  final String tag;
  final List<String> segments;

  HeldDictation copyWith({
    Duration? duration,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sequenceNumber,
    String? tag,
    List<String>? segments,
  }) {
    return HeldDictation(
      id: id,
      filePath: filePath,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      tag: tag ?? this.tag,
      segments: segments ?? List<String>.from(this.segments),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'durationMicros': duration.inMicroseconds,
    'fileSizeBytes': fileSizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'sequenceNumber': sequenceNumber,
    'tag': tag,
    'segments': segments,
  };

  factory HeldDictation.fromJson(Map<String, dynamic> json) {
    final rawSegments = (json['segments'] as List<dynamic>? ?? const [])
        .map((dynamic e) => e as String)
        .toList(growable: false);
    final segments =
        rawSegments.isNotEmpty
            ? rawSegments
            : <String>[json['filePath'] as String];
    return HeldDictation(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(microseconds: json['durationMicros'] as int? ?? 0),
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      tag: json['tag'] as String? ?? '',
      segments: segments,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
