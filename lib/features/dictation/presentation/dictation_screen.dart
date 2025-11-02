import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictation.dart';

class DictationScreen extends ConsumerWidget {
  const DictationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Dictation'),
      ),
      body: SafeArea(
        child: DictationBody(),
      ),
    );
  }
}

class DictationBody extends ConsumerStatefulWidget {
  const DictationBody({super.key});

  @override
  ConsumerState<DictationBody> createState() => _DictationBodyState();
}

class _DictationBodyState extends ConsumerState<DictationBody> {
  @override
  Widget build(BuildContext context) {
    ref.listen<DictationState>(
      dictationControllerProvider,
      (previous, next) {
        final player = ref.read(dictationPlayerControllerProvider.notifier);
        final previousPath = previous?.filePath;
        final canPlayNow = next.filePath != null && next.canPlayback;
        final couldPlayBefore =
            previousPath != null && previous?.canPlayback == true && previousPath == next.filePath;
        if (canPlayNow && !couldPlayBefore) {
          player.load(next.filePath!);
        }
        if (!canPlayNow && previousPath != null && previous?.canPlayback == true) {
          player.stop();
        }
      },
    );
    final dictationState = ref.watch(dictationControllerProvider);
    final dictationController = ref.read(dictationControllerProvider.notifier);
    final playerState = ref.watch(dictationPlayerControllerProvider);
    final playerController = ref.read(dictationPlayerControllerProvider.notifier);
    final queueState = ref.watch(dictationQueueProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordButton(
            state: dictationState,
            onRecord: dictationController.startRecording,
            onPause: dictationController.pauseRecording,
            onResume: dictationController.resumeRecording,
          ),
          const SizedBox(height: 24),
          _RecordingStatus(state: dictationState),
          const SizedBox(height: 24),
          _PlaybackCard(
            dictationState: dictationState,
            playerState: playerState,
            onPlay: playerController.play,
            onPause: playerController.pause,
            onSeek: playerController.seek,
          ),
          const SizedBox(height: 24),
          _ActionButtons(
            state: dictationState,
            onSubmit: dictationController.submitCurrent,
            onHold: dictationController.holdCurrent,
            onResumeHeld: dictationController.resumeHeld,
            onDelete: dictationController.deleteCurrent,
          ),
          const SizedBox(height: 24),
          _QueueSummary(queueState: queueState, onRefresh: () {
            ref.read(dictationQueueProvider.notifier).refresh();
          }),
          if (dictationState.errorMessage != null) ...[
            const SizedBox(height: 24),
            _ErrorBanner(message: dictationState.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.state,
    required this.onRecord,
    required this.onPause,
    required this.onResume,
  });

  final DictationState state;
  final Future<void> Function() onRecord;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final IconData icon;
    final String label;
    void Function()? onPressed;

    switch (state.status) {
      case DictationSessionStatus.recording:
        backgroundColor = Colors.red;
        icon = Icons.pause;
        label = 'Pause';
        onPressed = () => unawaited(onPause());
        break;
      case DictationSessionStatus.paused:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.mic;
        label = 'Resume';
        onPressed = () => unawaited(onResume());
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.mic;
        label = 'Record';
        onPressed = state.canRecord ? () => unawaited(onRecord()) : null;
        break;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 32),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.state});

  final DictationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = state.record;
    final sequenceLabel = record != null && record.sequenceNumber > 0
        ? '#${record.sequenceNumber.toString().padLeft(6, '0')}'
        : 'Unnumbered';
    final tagLabel = record != null && record.tag.isNotEmpty ? record.tag : 'N/A';
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$sequenceLabel • $tagLabel',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _statusLabel(state.status, state.uploadStatus),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(label: 'Duration', value: _formatDuration(state.duration)),
                _InfoChip(label: 'Size', value: _formatSize(state.fileSizeBytes)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DictationSessionStatus status, DictationUploadStatus? uploadStatus) {
    switch (status) {
      case DictationSessionStatus.recording:
        return 'Recording in progress';
      case DictationSessionStatus.paused:
        return 'Recording paused';
      case DictationSessionStatus.ready:
        if (uploadStatus == DictationUploadStatus.uploading) return 'Uploading…';
        if (uploadStatus == DictationUploadStatus.completed) return 'Uploaded';
        if (uploadStatus == DictationUploadStatus.failed) return 'Upload failed';
        if (uploadStatus == DictationUploadStatus.held) return 'Held locally';
        if (uploadStatus == DictationUploadStatus.pending) return 'Ready to submit';
        return 'Ready';
      case DictationSessionStatus.holding:
        return 'Held locally';
      case DictationSessionStatus.idle:
        return 'Idle';
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.dictationState,
    required this.playerState,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
  });

  final DictationState dictationState;
  final DictationPlayerState playerState;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function(Duration position) onSeek;

  @override
  Widget build(BuildContext context) {
    final canInteract = dictationState.canPlayback && playerState.filePath != null;
    final position = playerState.position;
    final duration = playerState.duration ?? dictationState.duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Playback',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Slider(
              value: progress.isNaN ? 0 : progress,
              onChanged: canInteract
                  ? (value) => unawaited(
                        onSeek(
                          Duration(milliseconds: (duration.inMilliseconds * value).round()),
                        ),
                      )
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position)),
                Text(_formatDuration(duration)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: FilledButton.icon(
                onPressed: !canInteract
                    ? null
                    : () => unawaited(
                          playerState.isPlaying ? onPause() : onPlay(),
                        ),
                icon: Icon(playerState.isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(playerState.isPlaying ? 'Pause' : 'Play'),
              ),
            ),
            if (playerState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                playerState.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.onSubmit,
    required this.onHold,
    required this.onResumeHeld,
    required this.onDelete,
  });

  final DictationState state;
  final Future<void> Function({Map<String, dynamic> metadata}) onSubmit;
  final Future<void> Function() onHold;
  final Future<void> Function() onResumeHeld;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final isHeld = state.isHeld || state.status == DictationSessionStatus.holding;
    final canToggleHold = isHeld || state.canHold;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Submit'),
            onPressed: state.canSubmit ? () => unawaited(onSubmit(metadata: const {})) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(isHeld ? Icons.play_circle : Icons.pause_circle),
            label: Text(isHeld ? 'Resume Recording' : 'Hold'),
            onPressed: canToggleHold
                ? () => unawaited(isHeld ? onResumeHeld() : onHold())
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: state.canDelete ? () => unawaited(onDelete()) : null,
          ),
        ),
      ],
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.queueState, required this.onRefresh});

  final AsyncValue<List<DictationUpload>> queueState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upload Queue',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh queue',
                  onPressed: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 12),
            queueState.when(
              data: (uploads) {
                if (uploads.isEmpty) {
                  return const Text('No pending dictations.');
                }
                return Column(
                  children: uploads
                      .map(
                        (upload) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_iconForStatus(upload.status)),
                          title: Text(
                            '${_sequenceLabel(upload.sequenceNumber)} • ${_tagLabel(upload.tag)}',
                          ),
                          subtitle: Text(
                            '${_statusLabel(upload.status)} • ${_formatSize(upload.fileSizeBytes)} • ${_formatDuration(upload.duration)} • ${_shortId(upload.id)}',
                          ),
                          trailing: upload.status == DictationUploadStatus.failed
                              ? Icon(Icons.error, color: Theme.of(context).colorScheme.error)
                              : null,
                        ),
                      )
                      .toList(growable: false),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Queue unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForStatus(DictationUploadStatus status) {
    switch (status) {
      case DictationUploadStatus.pending:
        return Icons.schedule;
      case DictationUploadStatus.uploading:
        return Icons.cloud_upload;
      case DictationUploadStatus.failed:
        return Icons.error;
      case DictationUploadStatus.completed:
        return Icons.check_circle;
      case DictationUploadStatus.held:
        return Icons.pause_circle;
    }
  }

  String _statusLabel(DictationUploadStatus status) {
    switch (status) {
      case DictationUploadStatus.pending:
        return 'Pending upload';
      case DictationUploadStatus.uploading:
        return 'Uploading';
      case DictationUploadStatus.held:
        return 'Held locally';
      case DictationUploadStatus.failed:
        return 'Failed';
      case DictationUploadStatus.completed:
        return 'Completed';
    }
  }

  String _sequenceLabel(int sequenceNumber) {
    if (sequenceNumber <= 0) return 'Unnumbered';
    return '#${sequenceNumber.toString().padLeft(6, '0')}';
  }

  String _tagLabel(String tag) {
    if (tag.isEmpty) return 'N/A';
    return tag;
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
