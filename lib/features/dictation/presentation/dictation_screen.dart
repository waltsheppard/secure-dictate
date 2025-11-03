import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictation.dart';

class DictationScreen extends ConsumerWidget {
  const DictationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Dictation')),
      body: SafeArea(child: DictationBody()),
    );
  }
}

class DictationBody extends ConsumerStatefulWidget {
  const DictationBody({super.key});

  @override
  ConsumerState<DictationBody> createState() => _DictationBodyState();
}

class _DictationBodyState extends ConsumerState<DictationBody> {
  late final TextEditingController _tagController;
  bool _isUpdatingTag = false;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _tagController.addListener(_handleTagChanged);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DictationState>(dictationControllerProvider, (previous, next) {
      final player = ref.read(dictationPlayerControllerProvider.notifier);
      final previousPath = previous?.filePath;
      final canPlayNow = next.filePath != null && next.canPlayback;
      if (!canPlayNow &&
          previousPath != null &&
          previous?.canPlayback == true) {
        unawaited(player.stop());
      }
      final nextTag = next.record?.tag ?? '';
      if (nextTag != _tagController.text) {
        _isUpdatingTag = true;
        _tagController
          ..text = nextTag
          ..selection = TextSelection.collapsed(offset: nextTag.length);
        _isUpdatingTag = false;
      }
    });
    final dictationState = ref.watch(dictationControllerProvider);
    final dictationController = ref.read(dictationControllerProvider.notifier);
    final playerState = ref.watch(dictationPlayerControllerProvider);
    final playerController = ref.read(
      dictationPlayerControllerProvider.notifier,
    );
    final uploadsState = ref.watch(uploadsControllerProvider);

    final controlWidgets = <Widget>[
      _RecordButton(
        state: dictationState,
        onRecord: dictationController.startRecording,
        onPause: dictationController.pauseRecording,
        onResume: dictationController.resumeRecording,
      ),
      const SizedBox(height: 16),
      _SessionCard(
        state: dictationState,
        tagController: _tagController,
        tagEnabled: dictationState.record != null,
      ),
      if (dictationState.isHeld || dictationState.status == DictationSessionStatus.holding) ...[
        const SizedBox(height: 16),
        _HeldBanner(state: dictationState),
      ],
      const SizedBox(height: 16),
      _ActionButtons(
        state: dictationState,
        onSubmit: dictationController.submitCurrent,
        onHold: dictationController.holdCurrent,
        onResumeHeld: dictationController.resumeHeld,
        onDelete: dictationController.deleteCurrent,
      ),
    ];

    final playbackWidgets = <Widget>[
      _PlaybackCard(
        dictationState: dictationState,
        playerState: playerState,
        onPlay: playerController.play,
        onPause: playerController.pause,
        onSeek: playerController.seek,
        onLoad: playerController.load,
      ),
      const SizedBox(height: 16),
      _UploadsSummary(
        state: uploadsState,
        onOpen: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadsScreen()),
          );
        },
        onRetry: () => ref.read(uploadsControllerProvider.notifier).refresh(),
      ),
      if (dictationState.errorMessage != null) ...[
        const SizedBox(height: 16),
        _ErrorBanner(message: dictationState.errorMessage!),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;
        final content = isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...controlWidgets],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...playbackWidgets],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...controlWidgets,
                  const SizedBox(height: 24),
                  ...playbackWidgets,
                ],
              );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: content,
        );
      },
    );
  }

  @override
  void dispose() {
    _tagController
      ..removeListener(_handleTagChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTagChanged() {
    if (_isUpdatingTag) return;
    var value = _tagController.text.toUpperCase();
    if (value.length > 12) {
      value = value.substring(0, 12);
      _isUpdatingTag = true;
      _tagController
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
      _isUpdatingTag = false;
    } else if (value != _tagController.text) {
      _isUpdatingTag = true;
      _tagController
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
      _isUpdatingTag = false;
    }
    final dictation = ref.read(dictationControllerProvider);
    if (dictation.record != null) {
      ref.read(dictationControllerProvider.notifier).updateTag(value);
    }
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
    Future<void> Function()? action;

    switch (state.status) {
      case DictationSessionStatus.recording:
        backgroundColor = Colors.red;
        icon = Icons.pause;
        label = 'Pause';
        action = onPause;
        break;
      case DictationSessionStatus.paused:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.mic;
        label = 'Resume';
        action = onResume;
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.mic;
        label = 'Record';
        action = state.canRecord ? onRecord : null;
        break;
    }

    return ElevatedButton.icon(
      onPressed: action == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              unawaited(action!());
            },
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.state,
    required this.tagController,
    required this.tagEnabled,
  });

  final DictationState state;
  final TextEditingController tagController;
  final bool tagEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = state.record;
    final sequenceLabel =
        record != null && record.sequenceNumber > 0
            ? '#${record.sequenceNumber.toString().padLeft(6, '0')}'
            : 'Unnumbered';
    final tagValue = record?.tag ?? '';
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current dictation',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sequenceLabel,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusLabel(state.status, state.uploadStatus),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagController,
              enabled: tagEnabled,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'Dictation tag',
                hintText: tagEnabled ? 'Enter up to 12 characters' : (tagValue.isEmpty ? 'No tag' : null),
                helperText: 'Optional identifier shared with uploads',
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(
                  label: 'Duration',
                  value: _formatDuration(state.duration),
                ),
                _InfoChip(
                  label: 'Size',
                  value: _formatSize(state.fileSizeBytes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(
    DictationSessionStatus status,
    DictationUploadStatus? uploadStatus,
  ) {
    switch (status) {
      case DictationSessionStatus.recording:
        return 'Recording in progress';
      case DictationSessionStatus.paused:
        return 'Recording paused';
      case DictationSessionStatus.ready:
        if (uploadStatus == DictationUploadStatus.uploading) {
          return 'Uploading…';
        }
        if (uploadStatus == DictationUploadStatus.completed) {
          return 'Uploaded';
        }
        if (uploadStatus == DictationUploadStatus.failed) {
          return 'Upload failed';
        }
        if (uploadStatus == DictationUploadStatus.held) {
          return 'Held locally';
        }
        if (uploadStatus == DictationUploadStatus.pending) {
          return 'Ready to submit';
        }
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

class _HeldBanner extends StatelessWidget {
  const _HeldBanner({required this.state});

  final DictationState state;

  @override
  Widget build(BuildContext context) {
    final record = state.record;
    final label = record?.tag.isNotEmpty == true ? record!.tag : 'Untitled';
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.pause_circle_filled,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        title: const Text('Held dictation ready to resume'),
        subtitle: Text(
          record == null
              ? 'Tap Resume to continue recording.'
              : '#${record.sequenceNumber.toString().padLeft(6, '0')} • $label',
        ),
      ),
    );
  }
}

class _UploadsSummary extends StatelessWidget {
  const _UploadsSummary({
    required this.state,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<UploadsState> state;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (value) {
        final unsentCount = value.unsent.length;
        final title = unsentCount == 0
            ? 'All uploads sent'
            : unsentCount == 1
                ? '1 dictation awaiting upload'
                : '$unsentCount dictations awaiting upload';
        final lastSent = value.recent.isNotEmpty
            ? 'Last sent ${TimeOfDay.fromDateTime((value.recent.first.uploadedAt ?? value.recent.first.updatedAt).toLocal()).format(context)}'
            : 'No recent uploads';
        final icon = unsentCount == 0
            ? Icons.cloud_done_outlined
            : Icons.cloud_upload_outlined;
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(lastSent),
            trailing: FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('View uploads'),
            ),
          ),
        );
      },
      loading: () => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Checking uploads…'),
        ),
      ),
      error: (error, _) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          title: Text(
            'Uploads unavailable',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          subtitle: Text(
            error.toString(),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          trailing: TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          onTap: onRetry,
        ),
      ),
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.dictationState,
    required this.playerState,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onLoad,
  });

  final DictationState dictationState;
  final DictationPlayerState playerState;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function(String path) onLoad;

  @override
  Widget build(BuildContext context) {
    final canInteract =
        dictationState.canPlayback && dictationState.filePath != null;
    final position = playerState.position;
    final duration = playerState.duration ?? dictationState.duration;
    final progress =
        duration.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            );

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Playback',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Slider(
              value: progress.isNaN ? 0 : progress,
              onChanged:
                  canInteract
                      ? (value) => unawaited(
                        onSeek(
                          Duration(
                            milliseconds:
                                (duration.inMilliseconds * value).round(),
                          ),
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
                onPressed:
                    !canInteract
                        ? null
                        : () async {
                          if (playerState.isPlaying) {
                            await onPause();
                            return;
                          }
                          final currentPath = dictationState.filePath;
                          if (currentPath != null) {
                            await onLoad(currentPath);
                            await onSeek(Duration.zero);
                          }
                          await onPlay();
                        },
                icon: Icon(
                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(playerState.isPlaying ? 'Pause' : 'Play'),
              ),
            ),
            if (playerState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                playerState.errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red),
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
    final isHeld =
        state.isHeld || state.status == DictationSessionStatus.holding;
    final canToggleHold = isHeld || state.canHold;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Submit'),
            onPressed: state.canSubmit
                ? () {
                    HapticFeedback.lightImpact();
                    unawaited(onSubmit(metadata: const {}));
                  }
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(isHeld ? Icons.play_circle : Icons.pause_circle),
            label: Text(isHeld ? 'Resume Recording' : 'Hold'),
            onPressed: canToggleHold
                ? () {
                    HapticFeedback.selectionClick();
                    unawaited(isHeld ? onResumeHeld() : onHold());
                  }
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: state.canDelete ? () => _confirmDelete(context) : null,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete dictation?'),
            content: const Text(
              'This will permanently remove the current dictation from the device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      unawaited(onDelete());
    }
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
