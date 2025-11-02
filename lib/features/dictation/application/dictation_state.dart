import '../domain/dictation_record.dart';
import '../domain/dictation_upload.dart';

class DictationState {
  const DictationState({
    required this.status,
    required this.dictationId,
    required this.filePath,
    required this.duration,
    required this.fileSizeBytes,
    required this.isSubmitting,
    required this.isHeld,
    required this.amplitudeLevel,
    required this.errorMessage,
    required this.hasQueuedUpload,
    required this.uploadStatus,
    required this.currentUpload,
    required this.record,
  });

  final DictationSessionStatus status;
  final String? dictationId;
  final String? filePath;
  final Duration duration;
  final int fileSizeBytes;
  final bool isSubmitting;
  final bool isHeld;
  final double amplitudeLevel;
  final String? errorMessage;
  final bool hasQueuedUpload;
  final DictationUploadStatus? uploadStatus;
  final DictationUpload? currentUpload;
  final DictationRecord? record;

  factory DictationState.initial() => const DictationState(
        status: DictationSessionStatus.idle,
        dictationId: null,
        filePath: null,
        duration: Duration.zero,
        fileSizeBytes: 0,
        isSubmitting: false,
        isHeld: false,
        amplitudeLevel: 0,
        errorMessage: null,
        hasQueuedUpload: false,
        uploadStatus: null,
        currentUpload: null,
        record: null,
      );

  DictationState copyWith({
    DictationSessionStatus? status,
    String? dictationId,
    String? filePath,
    Duration? duration,
    int? fileSizeBytes,
    bool? isSubmitting,
    bool? isHeld,
    double? amplitudeLevel,
    String? errorMessage,
    bool? hasQueuedUpload,
    DictationUploadStatus? uploadStatus,
    DictationUpload? currentUpload,
    DictationRecord? record,
    bool clearErrorMessage = false,
    bool clearCurrentUpload = false,
    bool clearRecord = false,
  }) {
    return DictationState(
      status: status ?? this.status,
      dictationId: dictationId ?? this.dictationId,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isHeld: isHeld ?? this.isHeld,
      amplitudeLevel: amplitudeLevel ?? this.amplitudeLevel,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      hasQueuedUpload: hasQueuedUpload ?? this.hasQueuedUpload,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      currentUpload: clearCurrentUpload ? null : currentUpload ?? this.currentUpload,
      record: clearRecord ? null : record ?? this.record,
    );
  }

  bool get canRecord => status == DictationSessionStatus.idle || status == DictationSessionStatus.ready;
  bool get canPause => status == DictationSessionStatus.recording;
  bool get canResume => status == DictationSessionStatus.paused;
  bool get canSubmit =>
      !isSubmitting &&
      filePath != null &&
      (status == DictationSessionStatus.ready || status == DictationSessionStatus.paused);
  bool get canHold => filePath != null && !isSubmitting;
  bool get canDelete => dictationId != null;
  bool get canPlayback =>
      filePath != null &&
      (status == DictationSessionStatus.ready ||
          status == DictationSessionStatus.paused ||
          status == DictationSessionStatus.holding);
}
