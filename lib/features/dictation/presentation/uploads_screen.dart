import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/uploads_controller.dart';
import '../domain/dictation_upload.dart';

class UploadsScreen extends ConsumerWidget {
  const UploadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadsState = ref.watch(uploadsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictation Uploads'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed:
                () => ref.read(uploadsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: uploadsState.when(
        data: (state) => _UploadsBody(state: state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) => _ErrorContent(
              message: error.toString(),
              onRetry:
                  () => ref.read(uploadsControllerProvider.notifier).refresh(),
            ),
      ),
    );
  }
}

class _UploadsBody extends ConsumerWidget {
  const _UploadsBody({required this.state});

  final UploadsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(uploadsControllerProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Unsent',
            subtitle:
                state.unsent.isEmpty
                    ? 'No dictations waiting to upload.'
                    : '${state.unsent.length} dictation${state.unsent.length == 1 ? '' : 's'} awaiting upload.',
          ),
          if (state.unsent.isEmpty)
            const _EmptyPlaceholder(
              icon: Icons.cloud_done_outlined,
              message:
                  'All caught up! New dictations will appear here when ready to send.',
            )
          else
            _UnsentList(uploads: state.unsent),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Recently sent',
            subtitle:
                state.recent.isEmpty
                    ? 'No recent uploads.'
                    : 'Showing the last ${state.recent.length} uploads.',
          ),
          if (state.recent.isEmpty)
            const _EmptyPlaceholder(
              icon: Icons.history,
              message:
                  'Uploaded dictations will appear here for quick reference.',
            )
          else
            _HistoryList(uploads: state.recent),
          const SizedBox(height: 24),
          Text(
            'Last refreshed ${TimeOfDay.fromDateTime(state.lastRefreshed.toLocal()).format(context)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UnsentList extends ConsumerWidget {
  const _UnsentList({required this.uploads});

  final List<DictationUpload> uploads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: uploads
            .map(
              (upload) => Column(
                children: [
                  ListTile(
                    leading: Icon(_iconForStatus(upload.status)),
                    title: Text(_titleFor(upload)),
                    subtitle: Text(_subtitleFor(upload)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (upload.status == DictationUploadStatus.failed)
                          IconButton(
                            tooltip: 'Retry upload',
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _retry(context, ref, upload.id),
                          ),
                        IconButton(
                          tooltip: 'Remove from queue',
                          icon: const Icon(Icons.delete_outline),
                          onPressed:
                              () => _confirmDelete(context, ref, upload.id),
                        ),
                      ],
                    ),
                  ),
                  if (upload != uploads.last) const Divider(height: 0),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  static IconData _iconForStatus(DictationUploadStatus status) {
    switch (status) {
      case DictationUploadStatus.pending:
      case DictationUploadStatus.held:
        return Icons.schedule;
      case DictationUploadStatus.uploading:
        return Icons.cloud_upload;
      case DictationUploadStatus.failed:
        return Icons.error_outline;
      case DictationUploadStatus.completed:
        return Icons.check_circle_outline;
    }
  }

  static String _titleFor(DictationUpload upload) {
    return '#${upload.sequenceNumber.toString().padLeft(6, '0')} • ${upload.tag.isEmpty ? 'Untitled' : upload.tag}';
  }

  static String _subtitleFor(DictationUpload upload) {
    final buffer = StringBuffer();
    buffer.write(_formatDuration(upload.duration));
    buffer.write(' • ');
    buffer.write(_formatSize(upload.fileSizeBytes));
    buffer.write(' • ');
    buffer.write(
      upload.status == DictationUploadStatus.failed
          ? 'Unsent (retry required)'
          : upload.status.name,
    );
    if (upload.errorMessage != null && upload.errorMessage!.isNotEmpty) {
      buffer.write('\n');
      buffer.write(upload.errorMessage);
    }
    return buffer.toString();
  }

  static void _retry(BuildContext context, WidgetRef ref, String id) {
    unawaited(ref.read(uploadsControllerProvider.notifier).retry(id));
  }

  static void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove from queue?'),
            content: const Text(
              'This will remove the dictation from the upload queue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  unawaited(
                    ref.read(uploadsControllerProvider.notifier).delete(id),
                  );
                },
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.uploads});

  final List<DictationUpload> uploads;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: uploads
            .map(
              (upload) => Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      '#${upload.sequenceNumber.toString().padLeft(6, '0')} • ${upload.tag.isEmpty ? 'Untitled' : upload.tag}',
                    ),
                    subtitle: Text(
                      '${_formatDuration(upload.duration)} • ${_formatSize(upload.fileSizeBytes)}\nUploaded ${upload.uploadedAt?.toLocal() ?? upload.updatedAt.toLocal()}',
                    ),
                  ),
                  if (upload != uploads.last) const Divider(height: 0),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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
